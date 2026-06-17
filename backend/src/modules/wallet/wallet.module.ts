import { Module } from '@nestjs/common';
import { PgService } from './pg.service';
import { WalletService } from './wallet.service';
import { WalletController } from './wallet.controller';

/**
 * Wallet (§11.3) — the closed demo economy: real Postgres-backed ₽ balances and atomic P2P transfers
 * between registered users on conditional money (NOT real funds / SBP). Self-contained: owns its own
 * Postgres pool (`PgService`) so it doesn't touch the Pricing/AI modules.
 */
@Module({
  providers: [PgService, WalletService],
  controllers: [WalletController],
  exports: [WalletService, PgService],
})
export class WalletModule {}
