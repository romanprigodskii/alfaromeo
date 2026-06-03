/**
 * Asset registry (§11.4) — maps our canonical symbol to each upstream's identifier so one place
 * owns the cross-provider naming. `seed` is a last-resort USD price used only if every upstream is
 * unreachable, so the demo never shows an empty list.
 */
export interface AssetMeta {
  symbol: string; // canonical, e.g. "BTC"
  coingeckoId: string; // CoinGecko id, e.g. "bitcoin"
  binanceSymbol: string; // Binance spot symbol (USDT pair), e.g. "BTCUSDT"
  coincapId: string; // CoinCap id, e.g. "bitcoin"
  seedUsd: number; // fallback USD price
}

const REGISTRY: Record<string, AssetMeta> = {
  BTC: { symbol: 'BTC', coingeckoId: 'bitcoin', binanceSymbol: 'BTCUSDT', coincapId: 'bitcoin', seedUsd: 103_000 },
  ETH: { symbol: 'ETH', coingeckoId: 'ethereum', binanceSymbol: 'ETHUSDT', coincapId: 'ethereum', seedUsd: 3_450 },
  USDT: { symbol: 'USDT', coingeckoId: 'tether', binanceSymbol: '', coincapId: 'tether', seedUsd: 1 },
  SOL: { symbol: 'SOL', coingeckoId: 'solana', binanceSymbol: 'SOLUSDT', coincapId: 'solana', seedUsd: 155 },
  TON: { symbol: 'TON', coingeckoId: 'the-open-network', binanceSymbol: 'TONUSDT', coincapId: 'toncoin', seedUsd: 6.6 },
};

/** Normalize a client-supplied symbol (case-insensitive) to its registry entry, if known. */
export function assetMeta(symbol: string): AssetMeta | undefined {
  return REGISTRY[symbol.trim().toUpperCase()];
}

/** All known canonical symbols. */
export function knownSymbols(): string[] {
  return Object.keys(REGISTRY);
}

/** Filter + normalize a requested list to the symbols we actually support. */
export function normalizeAssets(requested: string[]): AssetMeta[] {
  const seen = new Set<string>();
  const out: AssetMeta[] = [];
  for (const raw of requested) {
    const meta = assetMeta(raw);
    if (meta && !seen.has(meta.symbol)) {
      seen.add(meta.symbol);
      out.push(meta);
    }
  }
  return out;
}

/** Reverse lookups for upstream → canonical symbol. */
export function symbolForBinance(binanceSymbol: string): string | undefined {
  const up = binanceSymbol.toUpperCase();
  return Object.values(REGISTRY).find((m) => m.binanceSymbol === up)?.symbol;
}

export function symbolForCoincap(coincapId: string): string | undefined {
  const id = coincapId.toLowerCase();
  return Object.values(REGISTRY).find((m) => m.coincapId === id)?.symbol;
}
