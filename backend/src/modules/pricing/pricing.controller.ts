import { Controller, Get, Param, Query } from '@nestjs/common';
import { PricingService } from './pricing.service';
import { FxRate, PriceCandle, PriceTick } from './types';

/**
 * Public price endpoints (§11.4). No auth — prices are public data — but still served through our
 * own backend/gateway so the ₽ equivalent is computed consistently server-side and upstreams are
 * cached, not hammered per-client (§11.1).
 */
@Controller('prices')
export class PricingController {
  constructor(private readonly pricing: PricingService) {}

  /** `GET /prices?assets=BTC,ETH,USDT` → array of ₽ ``PriceTick`` (with 24h %). */
  @Get()
  async prices(@Query('assets') assets?: string): Promise<PriceTick[]> {
    const list = (assets ?? '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    return this.pricing.getPrices(list);
  }

  /**
   * `GET /prices/fx` → the USD→₽ rate behind every ₽ price: `{ usdRub, source, asOf, stale }`.
   * Lets the UI show «курс ЦБ ~XX ₽/$» (and flag a stale rate if CBR is temporarily down). §11.4.
   */
  @Get('fx')
  fx(): FxRate {
    return this.pricing.getFxRate();
  }

  /** `GET /prices/:asset/candles?range=7d` → historical ₽ OHLC candles (CoinGecko `/ohlc`). */
  @Get(':asset/candles')
  async candles(
    @Param('asset') asset: string,
    @Query('range') range?: string,
  ): Promise<PriceCandle[]> {
    return this.pricing.getCandles(asset, range ?? '7d');
  }
}
