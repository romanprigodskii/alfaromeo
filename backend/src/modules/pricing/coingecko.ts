import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AssetMeta } from './assets';

/** A USD snapshot for one asset from CoinGecko `simple/price`. */
export interface UsdSnapshot {
  symbol: string;
  usd: number;
  changePct24h: number | null;
}

/** One raw OHLC candle in USD (CoinGecko `/ohlc`: `[ts_ms, o, h, l, c]`). */
export interface UsdCandle {
  tMs: number;
  o: number;
  h: number;
  l: number;
  c: number;
}

/**
 * CoinGecko REST adapter (§11.4) — snapshots (`simple/price`) and historical candles (`/ohlc`).
 * Free demo tier needs no key; an optional demo key (`x-cg-demo-api-key`) raises the rate limit.
 * On HTTP 429 we retry with exponential backoff; the caller serves cached values meanwhile.
 */
@Injectable()
export class CoinGeckoClient {
  private readonly logger = new Logger('CoinGecko');
  private readonly base = 'https://api.coingecko.com/api/v3';

  constructor(private readonly config: ConfigService) {}

  private get headers(): Record<string, string> {
    const key = this.config.get<string>('pricing.coingeckoApiKey');
    const h: Record<string, string> = { accept: 'application/json' };
    if (key) h['x-cg-demo-api-key'] = key;
    return h;
  }

  /** USD snapshot for a set of assets, including 24h % change. */
  async snapshot(metas: AssetMeta[]): Promise<UsdSnapshot[]> {
    if (metas.length === 0) return [];
    const ids = metas.map((m) => m.coingeckoId).join(',');
    const url = `${this.base}/simple/price?ids=${encodeURIComponent(ids)}&vs_currencies=usd&include_24hr_change=true`;
    const data = await this.getJson<Record<string, { usd?: number; usd_24h_change?: number }>>(url);
    const out: UsdSnapshot[] = [];
    for (const meta of metas) {
      const row = data?.[meta.coingeckoId];
      if (row?.usd != null) {
        out.push({ symbol: meta.symbol, usd: row.usd, changePct24h: row.usd_24h_change ?? null });
      }
    }
    return out;
  }

  /** Historical USD OHLC for one asset. `days` maps a client range to CoinGecko's `days` param. */
  async ohlc(meta: AssetMeta, days: number): Promise<UsdCandle[]> {
    const url = `${this.base}/coins/${encodeURIComponent(meta.coingeckoId)}/ohlc?vs_currency=usd&days=${days}`;
    const rows = await this.getJson<number[][]>(url);
    if (!Array.isArray(rows)) return [];
    return rows
      .filter((r) => Array.isArray(r) && r.length >= 5)
      .map((r) => ({ tMs: r[0], o: r[1], h: r[2], l: r[3], c: r[4] }));
  }

  /** GET JSON with exponential backoff on 429 / transient errors (§11.4). */
  private async getJson<T>(url: string, attempt = 0): Promise<T | undefined> {
    const maxAttempts = 4;
    try {
      const res = await fetch(url, { headers: this.headers });
      if (res.status === 429) {
        if (attempt + 1 >= maxAttempts) {
          this.logger.warn(`429 from CoinGecko after ${maxAttempts} attempts — giving up, will use cache`);
          return undefined;
        }
        const delay = 500 * 2 ** attempt; // 0.5s, 1s, 2s
        this.logger.warn(`429 from CoinGecko — backing off ${delay}ms`);
        await sleep(delay);
        return this.getJson<T>(url, attempt + 1);
      }
      if (!res.ok) {
        this.logger.warn(`CoinGecko ${res.status} for ${url}`);
        return undefined;
      }
      return (await res.json()) as T;
    } catch (err) {
      if (attempt + 1 < maxAttempts) {
        await sleep(400 * 2 ** attempt);
        return this.getJson<T>(url, attempt + 1);
      }
      this.logger.warn(`CoinGecko request failed: ${(err as Error).message}`);
      return undefined;
    }
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}
