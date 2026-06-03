import { Injectable, Logger, OnApplicationBootstrap, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Subject } from 'rxjs';
import { AssetMeta, knownSymbols, normalizeAssets, assetMeta } from './assets';
import { CoinGeckoClient } from './coingecko';
import { FxService } from './fx';
import { PriceCache } from './cache';
import { UpstreamStream, UpstreamTick } from './upstream';
import { FxRate, PriceCandle, PriceTick } from './types';

/**
 * Pricing service (§11.4) — the server-side price authority.
 *
 * - Holds ONE upstream exchange connection (``UpstreamStream``) and converts every USD tick to the
 *   unified ₽ equivalent (``FxService``), caches it (``PriceCache``), and re-emits on ``ticks$``.
 * - Periodically refreshes a CoinGecko snapshot to keep 24h % fresh and to cover assets without a
 *   WS feed (e.g. USDT) — also the fallback when the upstream WS is down.
 * - Serves REST snapshots (`getPrices`) and historical candles (`getCandles`), both in ₽.
 *
 * Clients never reach Binance/CoinGecko directly — they read from here (REST) and the gateway (WS).
 */
@Injectable()
export class PricingService implements OnApplicationBootstrap, OnModuleDestroy {
  private readonly logger = new Logger('PricingService');

  /** Hot stream of ₽ ticks for the WS gateway to fan out. */
  readonly ticks$ = new Subject<PriceTick>();

  private upstream?: UpstreamStream;
  private snapshotTimer?: ReturnType<typeof setInterval>;
  /** Last known 24h % per asset — fills CoinCap ticks (which carry price only). */
  private readonly lastChangePct = new Map<string, number>();

  constructor(
    private readonly config: ConfigService,
    private readonly coingecko: CoinGeckoClient,
    private readonly fx: FxService,
    private readonly cache: PriceCache,
  ) {}

  // MARK: Lifecycle

  async onApplicationBootstrap(): Promise<void> {
    const metas = this.trackedMetas();
    // Warm the USD→₽ rate (CBR fix / cache) BEFORE the first conversion so the first snapshot is
    // already priced at the real rate, not the 92 fallback (§11.4).
    await this.fx.ensureReady();
    // Seed an initial snapshot so the first REST/WS read has data even before any WS tick lands.
    await this.refreshSnapshot(metas).catch((e) =>
      this.logger.warn(`Initial snapshot failed: ${(e as Error).message}`),
    );

    this.upstream = new UpstreamStream(metas, (t) => this.onUpstreamTick(t));
    this.upstream.start();

    // Periodic snapshot: keeps 24h % current + backfills/repairs when the WS is down (§11.4).
    const intervalMs = (this.config.get<number>('pricing.snapshotIntervalSec') ?? 45) * 1000;
    this.snapshotTimer = setInterval(() => {
      void this.refreshSnapshot(this.trackedMetas());
    }, intervalMs);

    this.logger.log(
      `Pricing online · tracked=${metas.map((m) => m.symbol).join(',')} · cache=${this.cache.backing} · fx=₽${this.fx.usdRub}/$ (${this.fx.state.source})`,
    );
  }

  onModuleDestroy(): void {
    if (this.snapshotTimer) clearInterval(this.snapshotTimer);
    this.upstream?.stop();
    this.ticks$.complete();
  }

  // MARK: Public API (controller + gateway)

  /** REST snapshot in ₽ for the requested assets; fills any cache miss from CoinGecko on demand. */
  async getPrices(requested: string[]): Promise<PriceTick[]> {
    const metas = requested.length ? normalizeAssets(requested) : this.trackedMetas();
    const cached = await this.cache.getMany(metas.map((m) => m.symbol));

    const missing = metas.filter((m) => !cached.has(m.symbol));
    if (missing.length) {
      await this.refreshSnapshot(missing);
      const filled = await this.cache.getMany(missing.map((m) => m.symbol));
      filled.forEach((tick, sym) => cached.set(sym, tick));
    }

    // Stable order matching the request; drop anything still unknown.
    return metas.map((m) => cached.get(m.symbol)).filter((t): t is PriceTick => t != null);
  }

  /** Current USD→₽ rate + provenance (CBR fix / cached / fallback) for `GET /prices/fx` (§11.4). */
  getFxRate(): FxRate {
    return this.fx.state;
  }

  /** Historical ₽ candles for one asset. `range` is a friendly token → CoinGecko `days`. */
  async getCandles(asset: string, range: string): Promise<PriceCandle[]> {
    const meta = assetMeta(asset);
    if (!meta) return [];
    const days = rangeToDays(range);
    const usd = await this.coingecko.ohlc(meta, days);
    return usd.map((c) => ({
      t: new Date(c.tMs).toISOString(),
      o: this.fx.toRub(c.o),
      h: this.fx.toRub(c.h),
      l: this.fx.toRub(c.l),
      c: this.fx.toRub(c.c),
    }));
  }

  // MARK: Internals

  private trackedMetas(): AssetMeta[] {
    const configured = this.config.get<string[]>('pricing.trackedAssets');
    const symbols = configured?.length ? configured : knownSymbols();
    const metas = normalizeAssets(symbols);
    return metas.length ? metas : normalizeAssets(knownSymbols());
  }

  /** Pull a USD snapshot from CoinGecko, convert to ₽, cache + emit. */
  private async refreshSnapshot(metas: AssetMeta[]): Promise<void> {
    const snaps = await this.coingecko.snapshot(metas);
    const ts = new Date().toISOString();

    // CoinGecko reached: cache real prices.
    for (const s of snaps) {
      if (s.changePct24h != null) this.lastChangePct.set(s.symbol, s.changePct24h);
      await this.publish({
        asset: s.symbol,
        price: this.fx.toRub(s.usd),
        changePct24h: s.changePct24h,
        ts,
      });
    }

    // For any tracked asset CoinGecko didn't return AND we have nothing cached, seed from registry
    // so the demo is never empty (e.g. all upstreams unreachable on a locked-down network).
    const got = new Set(snaps.map((s) => s.symbol));
    for (const meta of metas) {
      if (got.has(meta.symbol)) continue;
      if (await this.cache.get(meta.symbol)) continue;
      await this.publish({
        asset: meta.symbol,
        price: this.fx.toRub(meta.seedUsd),
        changePct24h: this.lastChangePct.get(meta.symbol) ?? 0,
        ts,
      });
    }
  }

  /** Convert a live upstream USD tick → ₽, cache + emit. */
  private onUpstreamTick(t: UpstreamTick): void {
    const changePct24h = t.changePct24h ?? this.lastChangePct.get(t.symbol) ?? null;
    if (t.changePct24h != null) this.lastChangePct.set(t.symbol, t.changePct24h);
    void this.publish({
      asset: t.symbol,
      price: this.fx.toRub(t.usd),
      changePct24h,
      ts: new Date().toISOString(),
    });
  }

  private async publish(tick: PriceTick): Promise<void> {
    // Stamp the USD→₽ rate used for the ₽ conversion onto every tick (REST snapshot + WS stream), so
    // a client can surface «курс ЦБ ~XX ₽/$» without a second call (§11.4).
    const stamped: PriceTick = { ...tick, usdRub: this.fx.usdRub };
    await this.cache.set(stamped);
    this.ticks$.next(stamped);
  }
}

/** Map a client range token to CoinGecko `days`. */
function rangeToDays(range: string): number {
  switch (range.trim().toLowerCase()) {
    case '1d':
    case '1':
      return 1;
    case '7d':
    case '1w':
    case '7':
      return 7;
    case '30d':
    case '1m':
    case '30':
      return 30;
    case '90d':
    case '3m':
    case '90':
      return 90;
    case '365d':
    case '1y':
    case '365':
      return 365;
    case 'max':
      return 365;
    default:
      return 7;
  }
}
