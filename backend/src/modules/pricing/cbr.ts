import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/** Today's official USD→₽ fixing from the Bank of Russia. */
export interface CbrUsdRub {
  /** ₽ per 1 USD (already divided by the currency `Nominal`). */
  value: number;
  /** CBR fixing datetime (their `Date` field), ISO-8601 — used as the rate's `asOf`. */
  asOf: string;
}

/** Shape of the fields we read from `daily_json.js` (the file carries many more). */
interface CbrDaily {
  Date?: string;
  Valute?: Record<string, { Value?: number; Nominal?: number }>;
}

/**
 * Bank of Russia FX adapter (§11.4: «курс ₽ — CBR/рыночный»).
 *
 * Source is the official daily fixing published as JSON at `cbr-xml-daily.ru/daily_json.js`
 * (a stable mirror of the CBR XML feed) — no API key, no scraping. We read `Valute.USD` and return
 * the per-unit rate (`Value / Nominal`; `Nominal` is 1 for USD but we divide defensively so the
 * adapter is correct for any currency). The CBR rate changes once per business day, so callers
 * refresh it only every few hours; on any HTTP/parse failure we return `undefined` and the caller
 * serves the last cached rate (see ``FxService``).
 */
@Injectable()
export class CbrClient {
  private readonly logger = new Logger('CBR');

  constructor(private readonly config: ConfigService) {}

  private get url(): string {
    return (
      this.config.get<string>('pricing.cbrUrl') ?? 'https://www.cbr-xml-daily.ru/daily_json.js'
    );
  }

  /** Fetch today's USD→₽ fixing, or `undefined` if CBR is unreachable / the payload is malformed. */
  async fetchUsdRub(attempt = 0): Promise<CbrUsdRub | undefined> {
    const maxAttempts = 3;
    try {
      const res = await fetch(this.url, {
        headers: { accept: 'application/json' },
        signal: AbortSignal.timeout(8_000),
      });
      if (!res.ok) {
        this.logger.warn(`CBR ${res.status} for ${this.url}`);
        return this.maybeRetry(attempt, maxAttempts);
      }
      const data = (await res.json()) as CbrDaily;
      const usd = data?.Valute?.USD;
      const value = usd?.Value;
      const nominal = usd?.Nominal ?? 1;
      // `daily_json.js` is untyped third-party JSON, so guard BOTH operands' finiteness and then the
      // result: a NaN/Infinity `Nominal` (or `Value`) must never yield a NaN/0 rate that downstream
      // would happily cache + multiply every price by. Validate the computed per-unit rate itself.
      const usable =
        typeof value === 'number' &&
        Number.isFinite(value) &&
        value > 0 &&
        typeof nominal === 'number' &&
        Number.isFinite(nominal) &&
        nominal > 0;
      const perUnit = usable ? Math.round((value / nominal) * 1e4) / 1e4 : NaN; // 4 dp; ₽ rounded later
      if (!Number.isFinite(perUnit) || perUnit <= 0) {
        this.logger.warn('CBR payload missing a valid Valute.USD rate — ignoring');
        return undefined;
      }
      return { value: perUnit, asOf: data.Date ?? new Date().toISOString() };
    } catch (err) {
      this.logger.warn(`CBR request failed: ${(err as Error).message}`);
      return this.maybeRetry(attempt, maxAttempts);
    }
  }

  /** Exponential backoff (0.5s, 1s) on transient failures, then give up so the caller can fall back. */
  private async maybeRetry(attempt: number, maxAttempts: number): Promise<CbrUsdRub | undefined> {
    if (attempt + 1 >= maxAttempts) return undefined;
    await new Promise((r) => setTimeout(r, 500 * 2 ** attempt));
    return this.fetchUsdRub(attempt + 1);
  }
}
