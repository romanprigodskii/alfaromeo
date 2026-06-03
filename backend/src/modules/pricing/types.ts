/** Pricing DTOs (§11.4). `price` is the unified ₽ equivalent, computed server-side (§11.1). */

/** A price point for an asset — mirrors the iOS `PriceTick` contract. */
export interface PriceTick {
  asset: string; // BTC, ETH, USDT, …
  price: number; // ₽ (unified equivalent, server-computed)
  changePct24h?: number | null;
  ts: string; // ISO-8601
  usdRub?: number | null; // USD→₽ rate used for this tick (so clients can show «курс ЦБ ~XX ₽/$»)
}

/** Where the live USD→₽ rate came from this cycle. */
export type FxSource = 'cbr' | 'cache' | 'fallback';

/** The unified USD→₽ rate served alongside prices (§11.4). */
export interface FxRate {
  usdRub: number; // ₽ per 1 USD
  source: FxSource; // 'cbr' = today's CBR fix · 'cache' = last cached · 'fallback' = emergency constant
  asOf: string; // ISO-8601 — CBR fixing datetime (or when we cached / fell back)
  stale: boolean; // true if not freshly fetched from CBR this cycle
}

/** One OHLC candle, in ₽. */
export interface PriceCandle {
  t: string; // ISO-8601 bucket start
  o: number;
  h: number;
  l: number;
  c: number;
}

/** Which upstream produced a tick (for logs / source rotation). */
export type TickSource = 'binance' | 'coincap' | 'coingecko';
