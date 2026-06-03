import { Module } from '@nestjs/common';
import { PricingController } from './pricing.controller';
import { PricingService } from './pricing.service';
import { PricingGateway } from './pricing.gateway';
import { CoinGeckoClient } from './coingecko';
import { CbrClient } from './cbr';
import { FxService } from './fx';
import { PriceCache } from './cache';

/**
 * Pricing (§11.2, §11.4) — live price aggregation (CoinGecko REST + Binance/CoinCap WS upstream),
 * Redis cache, historical candles, and the `/ws/prices` fan-out gateway. The first module to serve
 * real external data; the unified ₽ equivalent is computed here, server-side (§11.1, §11.4).
 */
@Module({
  controllers: [PricingController],
  providers: [PricingService, PricingGateway, CoinGeckoClient, CbrClient, FxService, PriceCache],
  exports: [PricingService],
})
export class PricingModule {}
