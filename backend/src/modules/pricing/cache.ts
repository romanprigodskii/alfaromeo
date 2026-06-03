import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';
import { FxRate, PriceTick } from './types';

/**
 * Last-price cache (§11.4: «кэш в Redis вместо того, чтобы каждый клиент молотил биржу»).
 *
 * Redis is the shared store when reachable; if it is not (offline demo), we transparently fall back
 * to an in-process Map so the backend still boots and serves cached snapshots — the scaffold must
 * stay green without infra (matches the existing «No DB connection at boot» convention).
 */
@Injectable()
export class PriceCache implements OnModuleDestroy {
  private readonly logger = new Logger('PriceCache');
  private readonly memory = new Map<string, PriceTick>();
  private redis?: Redis;
  private redisReady = false;

  constructor(private readonly config: ConfigService) {
    const url = this.config.get<string>('redis.url');
    if (!url) return;
    // lazyConnect + capped retries: never crash the app if Redis is absent — just use memory.
    this.redis = new Redis(url, {
      lazyConnect: true,
      maxRetriesPerRequest: 1,
      retryStrategy: (times) => (times > 3 ? null : Math.min(times * 200, 600)),
    });
    this.redis.on('ready', () => {
      this.redisReady = true;
      this.logger.log('Redis connected — using it as the shared price cache');
    });
    this.redis.on('error', (err) => {
      if (this.redisReady) this.logger.warn(`Redis error, falling back to memory: ${err.message}`);
      this.redisReady = false;
    });
    this.redis.connect().catch(() => {
      this.logger.warn('Redis unavailable — using in-memory price cache (fine for demo)');
    });
  }

  private key(asset: string): string {
    return `price:${asset.toUpperCase()}`;
  }

  /** Upsert the latest tick for an asset. */
  async set(tick: PriceTick): Promise<void> {
    this.memory.set(tick.asset.toUpperCase(), tick);
    if (this.redis && this.redisReady) {
      // TTL 120s: a stale tick is still useful as a snapshot but should not live forever.
      await this.redis.set(this.key(tick.asset), JSON.stringify(tick), 'EX', 120).catch(() => undefined);
    }
  }

  /** Latest cached tick for an asset, if any. */
  async get(asset: string): Promise<PriceTick | undefined> {
    if (this.redis && this.redisReady) {
      const raw = await this.redis.get(this.key(asset)).catch(() => null);
      if (raw) {
        try {
          return JSON.parse(raw) as PriceTick;
        } catch {
          /* fall through to memory */
        }
      }
    }
    return this.memory.get(asset.toUpperCase());
  }

  async getMany(assets: string[]): Promise<Map<string, PriceTick>> {
    const out = new Map<string, PriceTick>();
    await Promise.all(
      assets.map(async (a) => {
        const tick = await this.get(a);
        if (tick) out.set(a.toUpperCase(), tick);
      }),
    );
    return out;
  }

  get backing(): 'redis' | 'memory' {
    return this.redis && this.redisReady ? 'redis' : 'memory';
  }

  // MARK: FX rate (§11.4) — the USD→₽ rate, cached separately from prices with a LONG TTL so the
  // last good CBR fix survives a CBR outage (hours/days) and a backend restart, not just 120s.

  private static readonly FX_KEY = 'fx:usdrub';
  private fxMemory?: FxRate;

  /** Persist the latest USD→₽ rate. TTL defaults to 30 days so a stale-but-real rate beats the 92 constant. */
  async setFx(rate: FxRate): Promise<void> {
    this.fxMemory = rate;
    if (this.redis && this.redisReady) {
      const ttl = this.config.get<number>('pricing.fxCacheTtlSec') ?? 2_592_000; // 30 days
      await this.redis
        .set(PriceCache.FX_KEY, JSON.stringify(rate), 'EX', ttl)
        .catch(() => undefined);
    }
  }

  /** Last cached USD→₽ rate, if any (Redis first, then in-process memory). */
  async getFx(): Promise<FxRate | undefined> {
    if (this.redis && this.redisReady) {
      const raw = await this.redis.get(PriceCache.FX_KEY).catch(() => null);
      if (raw) {
        try {
          const valid = PriceCache.validFx(JSON.parse(raw));
          if (valid) return valid;
          this.logger.warn('Cached FX rate failed validation — ignoring, falling through');
        } catch {
          /* malformed JSON — fall through to memory */
        }
      }
    }
    return PriceCache.validFx(this.fxMemory);
  }

  /**
   * A cached rate is only usable if its `usdRub` is a finite positive number. This mirrors the guard
   * the CBR client applies to a fresh value, so the read path is just as defended as the fetch path:
   * stale/garbage cache content (an older build, a manual SET, partial corruption) can never poison
   * the hot conversion path — it falls through to CBR / the emergency constant instead.
   */
  private static validFx(rate: unknown): FxRate | undefined {
    const r = rate as Partial<FxRate> | undefined;
    if (r && typeof r.usdRub === 'number' && Number.isFinite(r.usdRub) && r.usdRub > 0) {
      return r as FxRate;
    }
    return undefined;
  }

  async onModuleDestroy(): Promise<void> {
    if (this.redis) await this.redis.quit().catch(() => undefined);
  }
}
