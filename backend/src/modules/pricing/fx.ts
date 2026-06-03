import { Injectable, Logger, OnApplicationBootstrap, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CbrClient } from './cbr';
import { PriceCache } from './cache';
import { FxRate } from './types';

/**
 * USD → ₽ conversion (§11.4). Crypto is quoted in USD upstream; the unified ₽ equivalent is computed
 * here, server-side, so every client and every surface agrees on one number.
 *
 * The rate is the **official Bank of Russia fixing** (``CbrClient``), refreshed on boot and every
 * `pricing.fxRefreshHours` thereafter (the CBR rate moves once per business day, so a few hours is
 * plenty) and cached in Redis (``PriceCache``). Fallback chain when CBR is unreachable:
 *
 *   CBR fix → last cached rate (Redis/memory, survives outages) → the legacy 92 constant (emergency).
 *
 * `toRub`/`usdRub` are synchronous and hot (called per tick), so they read an in-memory snapshot of
 * the current rate; the async ``refresh`` updates that snapshot in the background.
 */
@Injectable()
export class FxService implements OnApplicationBootstrap, OnModuleDestroy {
  private readonly logger = new Logger('FxService');

  /** Current rate snapshot — always populated (starts at the emergency constant, then warms up). */
  private current: FxRate;
  private refreshTimer?: ReturnType<typeof setTimeout>;
  private stopped = false;
  /** Memoized one-time warm-up so the first price conversion already uses a real rate. */
  private initPromise?: Promise<void>;

  constructor(
    private readonly config: ConfigService,
    private readonly cbr: CbrClient,
    private readonly cache: PriceCache,
  ) {
    this.current = {
      usdRub: this.fallbackRate,
      source: 'fallback',
      asOf: new Date().toISOString(),
      stale: true,
    };
  }

  // MARK: Lifecycle

  async onApplicationBootstrap(): Promise<void> {
    await this.ensureReady();
    this.scheduleNext();
    this.logger.log(
      `FX online · ₽${this.current.usdRub}/$ (${this.current.source}) · refresh every ${this.refreshHours}h (sooner while degraded)`,
    );
  }

  onModuleDestroy(): void {
    this.stopped = true;
    if (this.refreshTimer) clearTimeout(this.refreshTimer);
  }

  /** Refresh cadence in hours; a missing/≤0 value falls back to 6 so a misconfig can't busy-loop. */
  private get refreshHours(): number {
    const h = this.config.get<number>('pricing.fxRefreshHours');
    return h && h > 0 ? h : 6;
  }

  /**
   * Schedule the next refresh. One CBR fix per `fxRefreshHours` is plenty, but while we're degraded
   * (CBR failed this cycle → `stale`) we retry within a minute so the real (or last-cached) rate is
   * recovered quickly — this also covers a cold-start race where Redis became ready only after
   * ``init`` ran, so the cached rate is picked up promptly instead of after the full interval.
   */
  private scheduleNext(): void {
    if (this.stopped) return;
    const normalMs = this.refreshHours * 60 * 60 * 1000;
    const delay = this.current.stale ? Math.min(60_000, normalMs) : normalMs;
    this.refreshTimer = setTimeout(() => void this.tick(), delay);
  }

  private async tick(): Promise<void> {
    await this.refresh();
    this.scheduleNext();
  }

  /**
   * Warm the rate exactly once (idempotent across concurrent callers): load the last cached value so
   * conversions work even before CBR answers, then fetch today's fix. ``PricingService`` awaits this
   * before its first snapshot so the very first `/prices` response already uses the real rate.
   */
  ensureReady(): Promise<void> {
    if (!this.initPromise) this.initPromise = this.init();
    return this.initPromise;
  }

  private async init(): Promise<void> {
    const cached = await this.cache.getFx();
    if (cached) this.current = { ...cached, source: 'cache', stale: true };
    await this.refresh();
  }

  // MARK: Public API

  /** Current USD→₽ rate. */
  get usdRub(): number {
    return this.current.usdRub;
  }

  /** Full rate state (value + provenance) for the `/prices/fx` endpoint and per-tick stamping. */
  get state(): FxRate {
    return { ...this.current };
  }

  /** Convert a USD amount to ₽, rounded to kopecks. */
  toRub(usd: number): number {
    return Math.round(usd * this.current.usdRub * 100) / 100;
  }

  // MARK: Internals

  /** The emergency constant from config — only used when neither CBR nor the cache has a rate. */
  private get fallbackRate(): number {
    return this.config.get<number>('pricing.fxUsdRub') ?? 92;
  }

  /** Pull today's CBR fix; on failure keep the best rate we already have (cache/memory, else 92). */
  async refresh(): Promise<void> {
    const fix = await this.cbr.fetchUsdRub();
    if (fix) {
      this.current = { usdRub: fix.value, source: 'cbr', asOf: fix.asOf, stale: false };
      await this.cache.setFx(this.current);
      this.logger.log(`USD→₽ from CBR: ₽${fix.value}/$ (asOf ${fix.asOf})`);
      return;
    }

    // CBR unavailable — degrade gracefully.
    if (this.current.source !== 'fallback') {
      // We already hold a real (CBR or cached) value — keep it, just flag it stale.
      this.current = { ...this.current, stale: true };
      this.logger.warn(
        `CBR unavailable — keeping last ${this.current.source} rate ₽${this.current.usdRub}/$ (stale)`,
      );
      return;
    }

    // Cold start with CBR down: try the cache before the constant. (init() already loaded the cache
    // in the normal flow; this branch recovers the case where the cache became reachable only AFTER
    // init() — e.g. Redis 'ready' arrived late — and is reached promptly via the sooner retry above.)
    const cached = await this.cache.getFx();
    if (cached) {
      this.current = { ...cached, source: 'cache', stale: true };
      this.logger.warn(`CBR unavailable — using cached rate ₽${cached.usdRub}/$ (stale)`);
      return;
    }

    // Nothing anywhere — emergency constant. TODO(§11.4): alert on a sustained CBR outage.
    this.current = {
      usdRub: this.fallbackRate,
      source: 'fallback',
      asOf: new Date().toISOString(),
      stale: true,
    };
    this.logger.warn(
      `CBR + cache both unavailable — using emergency fallback ₽${this.fallbackRate}/$. TODO(§11.4): investigate CBR outage.`,
    );
  }
}
