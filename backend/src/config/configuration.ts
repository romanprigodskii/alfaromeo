/**
 * Parse a numeric env var, falling back to `def` for a missing, empty, OR non-numeric value.
 * (`process.env.X ?? def` only catches *missing* — `FX_USD_RUB=abc` or a stray space would otherwise
 * become NaN and silently poison every conversion / the emergency fallback rate.)
 */
function num(raw: string | undefined, def: number): number {
  if (raw == null || raw.trim() === '') return def;
  const n = Number(raw);
  return Number.isFinite(n) ? n : def;
}

/** Typed environment configuration (loaded by `@nestjs/config`). Safe defaults for local dev. */
export default () => ({
  // Default 4000 (not 3000) to dodge the common :3000 collision; override with PORT (§14).
  port: num(process.env.PORT, 4000),
  database: {
    url: process.env.DATABASE_URL ?? 'postgres://alfa:alfa@localhost:5432/alfa_romeo',
  },
  redis: {
    url: process.env.REDIS_URL ?? 'redis://localhost:6379',
  },
  // Closed demo economy (§11.3) — conditional ₽ balances + P2P transfers between registered users.
  // NOT real money / SBP. The starting balance is credited once per phone on register-demo.
  wallet: {
    startBalanceRub: num(process.env.DEMO_START_BALANCE_RUB, 50000),
  },
  // AI-orchestration (§11.7) — Anthropic API on the backend only; the key never leaves the server,
  // is never logged, and is never returned to the client (which only ever talks to /ai/*).
  ai: {
    apiKey: process.env.ANTHROPIC_API_KEY ?? '',
    // Model "под задачу": fast for support/FAQ, stronger for coach/agent. Both overridable.
    model: process.env.AI_MODEL ?? 'claude-sonnet-4-5',
    modelStrong: process.env.AI_MODEL_STRONG ?? process.env.AI_MODEL ?? 'claude-sonnet-4-5',
    maxTokens: num(process.env.AI_MAX_TOKENS, 1024),
    // Guardrail: an agent action over this ₽ amount is surfaced as a draft but blocked from execution.
    agentMaxAmountRub: num(process.env.AI_AGENT_MAX_AMOUNT_RUB, 100000),
    // HMAC secret signing action drafts so confirm-action only runs drafts the AI genuinely issued.
    // Empty → a random per-process secret (drafts won't verify across a restart; logged at boot).
    draftSecret: process.env.AI_DRAFT_SECRET ?? '',
    // How long a signed draft stays valid before confirm-action rejects it (seconds).
    draftTtlSec: num(process.env.AI_DRAFT_TTL_SEC, 600),
  },
  // Pricing (§11.4) — live crypto prices via our backend; ₽ equivalent computed server-side.
  pricing: {
    // CoinGecko free demo needs no key; an optional demo key raises the rate limit.
    coingeckoApiKey: process.env.COINGECKO_API_KEY ?? '',
    // USD→₽ — official Bank of Russia daily fixing (no key, no scraping).
    cbrUrl: process.env.CBR_URL ?? 'https://www.cbr-xml-daily.ru/daily_json.js',
    // How often to re-fetch the CBR fix. CBR changes once per business day → a few hours is plenty.
    fxRefreshHours: num(process.env.FX_REFRESH_HOURS, 6),
    // How long the last CBR rate stays cached (so it survives a CBR outage + restart). Default 30d.
    fxCacheTtlSec: num(process.env.FX_CACHE_TTL_SEC, 2592000),
    // Emergency fallback USD→₽ rate, used ONLY if CBR and the cache are both unavailable.
    fxUsdRub: num(process.env.FX_USD_RUB, 92),
    // Assets the upstream stream tracks by default (comma-separated symbols).
    trackedAssets: (process.env.PRICING_ASSETS ?? 'BTC,ETH,USDT,SOL,TON')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
    // How often to refresh the CoinGecko snapshot (24h % + fallback when WS is down).
    snapshotIntervalSec: num(process.env.PRICING_SNAPSHOT_SEC, 45),
  },
});
