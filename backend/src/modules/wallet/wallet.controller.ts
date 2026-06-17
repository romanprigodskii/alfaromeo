import { BadRequestException, Body, Controller, Get, Post, Query } from '@nestjs/common';
import { WalletService } from './wallet.service';

/** Body of `POST /auth/register-demo`. */
interface RegisterDemoBody {
  phone?: string;
  displayName?: string;
  name?: string; // tolerated alias for displayName
}

/** Body of `POST /transfer`. */
interface TransferBody {
  fromPhone?: string;
  toPhone?: string;
  amount?: number | string;
}

/** Body of `POST /crypto-transfer`. */
interface CryptoTransferBody {
  fromPhone?: string;
  toPhone?: string;
  asset?: string;
  amount?: number | string;
}

/**
 * Closed demo economy (§11.3) — balances + P2P transfers on conditional money between registered
 * users. NOT real funds, NOT SBP. Served at the gateway root (no auth beyond the phone, by design,
 * for the demo). Routes:
 *   POST /auth/register-demo   — register by phone + one-time starting balance (idempotent)
 *   GET  /balance?phone=...    — current balance
 *   GET  /users                — list registered users (pick a real recipient)
 *   POST /transfer             — atomic ₽ move between two users
 */
@Controller()
export class WalletController {
  constructor(private readonly wallet: WalletService) {}

  @Post('auth/register-demo')
  async register(@Body() body: RegisterDemoBody) {
    if (!body?.phone) {
      throw new BadRequestException({ error: 'phone_required', message: 'Укажите phone.' });
    }
    const { user, created } = await this.wallet.register(body.phone, body.displayName ?? body.name);
    return { ...user, created };
  }

  @Get('balance')
  async balance(@Query('phone') phone?: string) {
    if (!phone) {
      throw new BadRequestException({ error: 'phone_required', message: 'Укажите ?phone=...' });
    }
    return this.wallet.balanceOf(phone);
  }

  @Get('users')
  async users() {
    return { users: await this.wallet.listUsers() };
  }

  @Post('transfer')
  async transfer(@Body() body: TransferBody) {
    if (!body?.fromPhone || !body?.toPhone) {
      throw new BadRequestException({
        error: 'phones_required',
        message: 'Укажите fromPhone и toPhone.',
      });
    }
    return this.wallet.transfer(body.fromPhone, body.toPhone, body.amount);
  }

  @Post('crypto-transfer')
  async cryptoTransfer(@Body() body: CryptoTransferBody) {
    if (!body?.fromPhone || !body?.toPhone) {
      throw new BadRequestException({ error: 'phones_required', message: 'Укажите fromPhone и toPhone.' });
    }
    if (!body?.asset) {
      throw new BadRequestException({ error: 'asset_required', message: 'Укажите asset (BTC/ETH/USDT/TON).' });
    }
    return this.wallet.cryptoTransfer(body.fromPhone, body.toPhone, body.asset, body.amount);
  }
}
