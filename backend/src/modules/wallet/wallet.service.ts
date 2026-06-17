import {
  BadRequestException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleInit,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PgService } from './pg.service';

/** Supported demo crypto assets → the `demo_users` column that holds each (allowlist; never interpolated raw). */
const ASSET_COLUMN: Record<string, 'btc' | 'eth' | 'usdt' | 'ton'> = {
  BTC: 'btc',
  ETH: 'eth',
  USDT: 'usdt',
  TON: 'ton',
};

/** Pre-seeded demo identities: ₽ + fake crypto holdings, loaded once at boot (idempotent). */
const SEED: Array<{ phone: string; name: string; rub: number; btc?: number; eth?: number; usdt?: number; ton?: number }> = [
  { phone: '+79129257878', name: 'Виктор Алмазов', rub: 10_000_000, usdt: 200_000 },
  { phone: '+79009009090', name: 'Лена Морозова', rub: 10_000, btc: 0.1, eth: 0.1 },
  { phone: '+79009000000', name: 'Тимур Рашидов', rub: 100_000, ton: 100, eth: 0.1 },
  { phone: '+79089009090', name: 'Аня Соловьёва', rub: 50_000, usdt: 100, btc: 0.1 },
];

/** A registered demo user: a single ₽ balance + fake crypto holdings (closed demo economy, §11.3). */
export interface DemoUser {
  id: string;
  phone: string;
  displayName: string;
  balance: number;
  btc: number;
  eth: number;
  usdt: number;
  ton: number;
  createdAt: string;
}

/** Result of a completed ₽ P2P transfer — returns both sides' updated balances. */
export interface TransferResult {
  transferId: string;
  amount: number;
  createdAt: string;
  from: DemoUser;
  to: DemoUser;
}

/** Result of a completed crypto transfer — the asset + both sides' updated holdings. */
export interface CryptoTransferResult {
  transferId: string;
  asset: string;
  amount: number;
  createdAt: string;
  from: DemoUser;
  to: DemoUser;
}

/**
 * Balances + P2P transfers for the closed demo economy (§11.3).
 *
 * This is conditional/demo money between registered users — NOT real funds, NOT SBP. Money is held
 * as a single ₽ balance per user; all arithmetic runs in SQL over `NUMERIC(14,2)` (exact, no float
 * drift) and the actual move happens inside one DB transaction (see `transfer`).
 */
@Injectable()
export class WalletService implements OnModuleInit {
  private readonly logger = new Logger('WalletService');

  constructor(
    private readonly pg: PgService,
    private readonly config: ConfigService,
  ) {}

  /** Pre-load the demo identities' balances at boot (best-effort — never crashes boot if DB is down). */
  async onModuleInit(): Promise<void> {
    try {
      if (await this.pg.ensureReady()) await this.seedDemoBalances();
    } catch (err) {
      this.logger.warn(`demo seed skipped: ${(err as Error).message}`);
    }
  }

  /** One-time ₽ amount credited on first register-demo (env `DEMO_START_BALANCE_RUB`, default 50000). */
  private get startBalance(): number {
    return this.config.get<number>('wallet.startBalanceRub') ?? 50000;
  }

  private async ensureDb(): Promise<void> {
    if (!(await this.pg.ensureReady())) {
      throw new ServiceUnavailableException({
        error: 'db_unavailable',
        message: 'База данных недоступна. Запустите Postgres: docker compose up -d.',
      });
    }
  }

  /**
   * Canonicalise a phone so the same human maps to one row regardless of formatting
   * («+7 999 123-45-67», «89991234567», «9991234567» → «+79991234567»). This is what makes
   * register-demo idempotent and transfer-by-phone reliable.
   */
  normalizePhone(raw: string): string {
    // Reject non-strings up front: an untyped JSON body can deliver an array/object/number here
    // (e.g. {"phone":["…"]} or repeated ?phone=a&phone=b), and `.replace` on those would throw a
    // raw TypeError → 500. Turn it into the same clean 400 the rest of this function returns.
    if (typeof raw !== 'string') {
      throw new BadRequestException({
        error: 'invalid_phone',
        message: 'Некорректный номер телефона.',
      });
    }
    let digits = raw.replace(/[^\d]/g, '');
    // RU conveniences: leading 8 → 7; bare 10-digit national number → prefix 7.
    if (digits.length === 11 && digits.startsWith('8')) digits = '7' + digits.slice(1);
    if (digits.length === 10) digits = '7' + digits;
    if (digits.length < 11 || digits.length > 15) {
      throw new BadRequestException({
        error: 'invalid_phone',
        message: `Некорректный номер телефона: «${raw ?? ''}».`,
      });
    }
    return '+' + digits;
  }

  /** Validate a ₽ amount: positive, finite, at most kopeck (2-decimal) precision. */
  private parseAmount(raw: unknown): number {
    const n = typeof raw === 'string' ? Number(raw) : (raw as number);
    if (typeof n !== 'number' || !Number.isFinite(n) || n <= 0) {
      throw new BadRequestException({
        error: 'invalid_amount',
        message: 'Сумма перевода должна быть положительным числом.',
      });
    }
    const rounded = Math.round(n * 100) / 100;
    if (rounded !== n) {
      throw new BadRequestException({
        error: 'invalid_amount',
        message: 'Сумма не может быть точнее копейки (2 знака после запятой).',
      });
    }
    return rounded;
  }

  private rowToUser(r: any): DemoUser {
    return {
      id: r.id,
      phone: r.phone,
      displayName: r.display_name,
      balance: Number(r.balance), // NUMERIC arrives as a string from pg → number for the JSON body.
      btc: Number(r.btc ?? 0),
      eth: Number(r.eth ?? 0),
      usdt: Number(r.usdt ?? 0),
      ton: Number(r.ton ?? 0),
      createdAt: r.created_at instanceof Date ? r.created_at.toISOString() : String(r.created_at),
    };
  }

  /**
   * Seed the four demo identities' balances once. Idempotent and safe to run on every boot:
   *  - creates a missing row (ON CONFLICT DO NOTHING);
   *  - sets the ₽ + crypto balances ONLY on a row that has NO operations yet (no ₽ transfer and no
   *    crypto transfer), so a demo where money has already moved is left exactly as it is.
   */
  private async seedDemoBalances(): Promise<void> {
    for (const s of SEED) {
      await this.pg.query(
        `INSERT INTO demo_users (phone, display_name, balance, btc, eth, usdt, ton)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (phone) DO NOTHING`,
        [s.phone, s.name, s.rub, s.btc ?? 0, s.eth ?? 0, s.usdt ?? 0, s.ton ?? 0],
      );
      await this.pg.query(
        `UPDATE demo_users u
            SET display_name = $2, balance = $3, btc = $4, eth = $5, usdt = $6, ton = $7
          WHERE u.phone = $1
            AND NOT EXISTS (SELECT 1 FROM demo_transfers t        WHERE t.from_user_id = u.id OR t.to_user_id = u.id)
            AND NOT EXISTS (SELECT 1 FROM demo_crypto_transfers c WHERE c.from_user_id = u.id OR c.to_user_id = u.id)`,
        [s.phone, s.name, s.rub, s.btc ?? 0, s.eth ?? 0, s.usdt ?? 0, s.ton ?? 0],
      );
    }
    this.logger.log(`demo balances seeded/affirmed for ${SEED.length} identities (untouched if already used)`);
  }

  /** Validate a crypto amount: positive, finite, ≤ 8-decimal precision. */
  private parseCryptoAmount(raw: unknown): number {
    const n = typeof raw === 'string' ? Number(raw) : (raw as number);
    if (typeof n !== 'number' || !Number.isFinite(n) || n <= 0) {
      throw new BadRequestException({ error: 'invalid_amount', message: 'Сумма перевода должна быть положительной.' });
    }
    const rounded = Math.round(n * 1e8) / 1e8;
    if (rounded !== n) {
      throw new BadRequestException({ error: 'invalid_amount', message: 'Не более 8 знаков после запятой.' });
    }
    return rounded;
  }

  /**
   * Register a user by phone and credit the starting balance — exactly once per phone.
   *
   * Idempotent via `INSERT ... ON CONFLICT (phone) DO NOTHING`: a repeat registration of the same
   * number returns the existing user untouched and never re-credits.
   */
  async register(rawPhone: string, displayName?: string): Promise<{ user: DemoUser; created: boolean }> {
    await this.ensureDb();
    const phone = this.normalizePhone(rawPhone);
    const name = (displayName ?? '').trim() || `Пользователь ${phone.slice(-4)}`;

    const inserted = await this.pg.query(
      `INSERT INTO demo_users (phone, display_name, balance)
       VALUES ($1, $2, $3)
       ON CONFLICT (phone) DO NOTHING
       RETURNING *`,
      [phone, name, this.startBalance],
    );

    if (inserted.rows.length > 0) {
      const user = this.rowToUser(inserted.rows[0]);
      this.logger.log(
        `register-demo: NEW ${phone} («${name}») +${this.startBalance.toFixed(2)} ₽ стартовый баланс`,
      );
      return { user, created: true };
    }

    // Already registered — return the existing row, do NOT credit again (idempotent).
    const existing = await this.pg.query(`SELECT * FROM demo_users WHERE phone = $1`, [phone]);
    this.logger.log(`register-demo: EXISTING ${phone} — идемпотентно, повторного начисления нет`);
    return { user: this.rowToUser(existing.rows[0]), created: false };
  }

  /** Current balance (and identity) for a phone. 404 if the phone is not registered. */
  async balanceOf(rawPhone: string): Promise<DemoUser> {
    await this.ensureDb();
    const phone = this.normalizePhone(rawPhone);
    const res = await this.pg.query(`SELECT * FROM demo_users WHERE phone = $1`, [phone]);
    if (res.rows.length === 0) {
      throw new NotFoundException({
        error: 'user_not_found',
        message: `Пользователь ${phone} не зарегистрирован.`,
      });
    }
    return this.rowToUser(res.rows[0]);
  }

  /** All registered users (phone + name) so a client can pick a real recipient. */
  async listUsers(): Promise<Array<{ phone: string; displayName: string }>> {
    await this.ensureDb();
    const res = await this.pg.query(
      `SELECT phone, display_name FROM demo_users ORDER BY created_at ASC`,
    );
    return res.rows.map((r: any) => ({ phone: r.phone, displayName: r.display_name }));
  }

  /**
   * Move `amount` ₽ from one registered user to another, atomically.
   *
   * Inside a single DB transaction: lock both rows (in a deterministic `id` order to avoid deadlocks
   * under concurrent opposite-direction transfers), verify the sender can cover it, debit, credit and
   * append the transfer log — all commit together or roll back together. Returns both updated balances.
   */
  async transfer(rawFrom: string, rawTo: string, rawAmount: unknown): Promise<TransferResult> {
    await this.ensureDb();
    const fromPhone = this.normalizePhone(rawFrom);
    const toPhone = this.normalizePhone(rawTo);
    if (fromPhone === toPhone) {
      throw new BadRequestException({
        error: 'same_account',
        message: 'Нельзя переводить самому себе.',
      });
    }
    const amount = this.parseAmount(rawAmount);

    return this.pg.tx(async (client) => {
      // Lock both participant rows up front, ordered by id, so A→B and B→A can never deadlock.
      const locked = (
        await client.query(
          `SELECT * FROM demo_users WHERE phone = ANY($1::text[]) ORDER BY id FOR UPDATE`,
          [[fromPhone, toPhone]],
        )
      ).rows as any[];
      const sender = locked.find((r) => r.phone === fromPhone);
      const recipient = locked.find((r) => r.phone === toPhone);

      if (!sender) {
        throw new NotFoundException({
          error: 'sender_not_found',
          message: `Отправитель ${fromPhone} не зарегистрирован.`,
        });
      }
      if (!recipient) {
        throw new NotFoundException({
          error: 'recipient_not_found',
          message: `Получатель ${toPhone} не зарегистрирован.`,
        });
      }

      const senderBalance = Number(sender.balance);
      if (senderBalance < amount) {
        throw new HttpException(
          {
            error: 'insufficient_funds',
            message: `Недостаточно средств: на балансе ${senderBalance.toFixed(2)} ₽, требуется ${amount.toFixed(2)} ₽.`,
            balance: senderBalance,
            required: amount,
          },
          HttpStatus.UNPROCESSABLE_ENTITY,
        );
      }

      // Exact ₽ arithmetic in SQL over NUMERIC — no floating-point drift.
      const debited = (
        await client.query(`UPDATE demo_users SET balance = balance - $2 WHERE id = $1 RETURNING *`, [
          sender.id,
          amount,
        ])
      ).rows[0];
      const credited = (
        await client.query(`UPDATE demo_users SET balance = balance + $2 WHERE id = $1 RETURNING *`, [
          recipient.id,
          amount,
        ])
      ).rows[0];
      const tr = (
        await client.query(
          `INSERT INTO demo_transfers (from_user_id, to_user_id, from_phone, to_phone, amount)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING id, created_at`,
          [sender.id, recipient.id, fromPhone, toPhone, amount],
        )
      ).rows[0];

      this.logger.log(
        `transfer ${tr.id}: ${fromPhone} → ${toPhone} ${amount.toFixed(2)} ₽ | ` +
          `новые балансы ${Number(debited.balance).toFixed(2)} / ${Number(credited.balance).toFixed(2)} ₽`,
      );

      return {
        transferId: tr.id,
        amount,
        createdAt: tr.created_at instanceof Date ? tr.created_at.toISOString() : String(tr.created_at),
        from: this.rowToUser(debited),
        to: this.rowToUser(credited),
      };
    });
  }

  /**
   * Move `amount` of a fake crypto `asset` from one registered user to another, atomically — the exact
   * same shape as `transfer()` but on a crypto column instead of ₽. The asset maps to a fixed column
   * via `ASSET_COLUMN` (allowlist — the user's `asset` is never interpolated into SQL).
   */
  async cryptoTransfer(
    rawFrom: string,
    rawTo: string,
    rawAsset: unknown,
    rawAmount: unknown,
  ): Promise<CryptoTransferResult> {
    await this.ensureDb();
    const fromPhone = this.normalizePhone(rawFrom);
    const toPhone = this.normalizePhone(rawTo);
    if (fromPhone === toPhone) {
      throw new BadRequestException({ error: 'same_account', message: 'Нельзя переводить самому себе.' });
    }
    const asset = String(rawAsset ?? '').trim().toUpperCase();
    const col = ASSET_COLUMN[asset];
    if (!col) {
      throw new BadRequestException({
        error: 'invalid_asset',
        message: `Актив «${rawAsset ?? ''}» не поддерживается. Доступно: BTC, ETH, USDT, TON.`,
      });
    }
    const amount = this.parseCryptoAmount(rawAmount);

    return this.pg.tx(async (client) => {
      const locked = (
        await client.query(
          `SELECT * FROM demo_users WHERE phone = ANY($1::text[]) ORDER BY id FOR UPDATE`,
          [[fromPhone, toPhone]],
        )
      ).rows as any[];
      const sender = locked.find((r) => r.phone === fromPhone);
      const recipient = locked.find((r) => r.phone === toPhone);
      if (!sender) {
        throw new NotFoundException({ error: 'sender_not_found', message: `Отправитель ${fromPhone} не зарегистрирован.` });
      }
      if (!recipient) {
        throw new NotFoundException({ error: 'recipient_not_found', message: `Получатель ${toPhone} не зарегистрирован.` });
      }

      const senderHolding = Number(sender[col]);
      if (senderHolding < amount) {
        throw new HttpException(
          {
            error: 'insufficient_asset',
            message: `Недостаточно ${asset}: на балансе ${senderHolding}, требуется ${amount}.`,
            balance: senderHolding,
            required: amount,
            asset,
          },
          HttpStatus.UNPROCESSABLE_ENTITY,
        );
      }

      // `col` is from the ASSET_COLUMN allowlist, so this interpolation is safe; amounts are parameterised.
      const debited = (
        await client.query(`UPDATE demo_users SET ${col} = ${col} - $2 WHERE id = $1 RETURNING *`, [sender.id, amount])
      ).rows[0];
      const credited = (
        await client.query(`UPDATE demo_users SET ${col} = ${col} + $2 WHERE id = $1 RETURNING *`, [recipient.id, amount])
      ).rows[0];
      const tr = (
        await client.query(
          `INSERT INTO demo_crypto_transfers (from_user_id, to_user_id, from_phone, to_phone, asset, amount)
           VALUES ($1, $2, $3, $4, $5, $6)
           RETURNING id, created_at`,
          [sender.id, recipient.id, fromPhone, toPhone, asset, amount],
        )
      ).rows[0];

      this.logger.log(
        `crypto-transfer ${tr.id}: ${fromPhone} → ${toPhone} ${amount} ${asset} | ` +
          `новые холдинги ${Number(debited[col])} / ${Number(credited[col])} ${asset}`,
      );

      return {
        transferId: tr.id,
        asset,
        amount,
        createdAt: tr.created_at instanceof Date ? tr.created_at.toISOString() : String(tr.created_at),
        from: this.rowToUser(debited),
        to: this.rowToUser(credited),
      };
    });
  }
}
