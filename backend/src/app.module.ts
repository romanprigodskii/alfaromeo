import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import configuration from './config/configuration';
import { HealthModule } from './health/health.module';

// Feature module stubs — one per service in §11.2. No business logic yet (Phase 0).
import { AuthModule } from './modules/auth/auth.module';
import { IdentityModule } from './modules/identity/identity.module';
import { SubscriptionsModule } from './modules/subscriptions/subscriptions.module';
import { AccountsModule } from './modules/accounts/accounts.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { CardsModule } from './modules/cards/cards.module';
import { CreditModule } from './modules/credit/credit.module';
import { DepositsModule } from './modules/deposits/deposits.module';
import { CryptoModule } from './modules/crypto/crypto.module';
import { PricingModule } from './modules/pricing/pricing.module';
import { MobileModule } from './modules/mobile/mobile.module';
import { BusinessModule } from './modules/business/business.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';
import { AiModule } from './modules/ai/ai.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { SupportModule } from './modules/support/support.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, load: [configuration] }),
    HealthModule,
    // §11.2 services
    AuthModule,
    IdentityModule,
    SubscriptionsModule,
    AccountsModule,
    PaymentsModule,
    CardsModule,
    CreditModule,
    DepositsModule,
    CryptoModule,
    PricingModule,
    MobileModule,
    BusinessModule,
    AnalyticsModule,
    AiModule,
    NotificationsModule,
    SupportModule,
  ],
})
export class AppModule {}
