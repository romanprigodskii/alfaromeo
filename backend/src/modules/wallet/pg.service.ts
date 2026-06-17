import { Injectable, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Pool, PoolClient, QueryResult } from 'pg';

/**
 * Schema bootstrap for the closed demo economy (§11.3 `User`, `LedgerEntry`).
 *
 * Two tables, intentionally minimal and clearly demo-scoped so they never collide with a future
 * real `users`/`accounts` ledger:
 *  - `demo_users`     — one registered user with a single ₽ balance (conditional money, NOT SBP).
 *  - `demo_transfers` — append-only P2P transfer log (every move is durably auditable, §11.1 «логи»).
 *
 * `CHECK (balance >= 0)` is defence-in-depth: the DB itself refuses to let a balance go negative,
 * so even a logic bug can never overdraw. `gen_random_uuid()` is core in Postgres 13+ (no extension).
 */
const SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS demo_users (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone        TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  balance      NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Demo crypto holdings — fake assets that live on the server and move between users like ₽ (NOT a real
-- blockchain). Added idempotently so existing rows gain the columns at 0 without losing their ₽ balance.
ALTER TABLE demo_users ADD COLUMN IF NOT EXISTS btc  NUMERIC(24,8) NOT NULL DEFAULT 0 CHECK (btc  >= 0);
ALTER TABLE demo_users ADD COLUMN IF NOT EXISTS eth  NUMERIC(24,8) NOT NULL DEFAULT 0 CHECK (eth  >= 0);
ALTER TABLE demo_users ADD COLUMN IF NOT EXISTS usdt NUMERIC(24,8) NOT NULL DEFAULT 0 CHECK (usdt >= 0);
ALTER TABLE demo_users ADD COLUMN IF NOT EXISTS ton  NUMERIC(24,8) NOT NULL DEFAULT 0 CHECK (ton  >= 0);

CREATE TABLE IF NOT EXISTS demo_transfers (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id UUID NOT NULL REFERENCES demo_users(id),
  to_user_id   UUID NOT NULL REFERENCES demo_users(id),
  from_phone   TEXT NOT NULL,
  to_phone     TEXT NOT NULL,
  amount       NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS demo_transfers_from_idx ON demo_transfers (from_user_id);
CREATE INDEX IF NOT EXISTS demo_transfers_to_idx   ON demo_transfers (to_user_id);

-- Append-only log of crypto moves (asset + 8-decimal amount), mirroring demo_transfers for ₽.
CREATE TABLE IF NOT EXISTS demo_crypto_transfers (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id UUID NOT NULL REFERENCES demo_users(id),
  to_user_id   UUID NOT NULL REFERENCES demo_users(id),
  from_phone   TEXT NOT NULL,
  to_phone     TEXT NOT NULL,
  asset        TEXT NOT NULL,
  amount       NUMERIC(24,8) NOT NULL CHECK (amount > 0),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS demo_crypto_transfers_from_idx ON demo_crypto_transfers (from_user_id);
CREATE INDEX IF NOT EXISTS demo_crypto_transfers_to_idx   ON demo_crypto_transfers (to_user_id);
`;

/**
 * Thin Postgres wrapper (node-postgres `Pool`) for the demo wallet module.
 *
 * Follows the existing scaffold convention (see `PriceCache`): infra being down must NOT crash the
 * app at boot. If Postgres is unreachable we log a warning and mark ourselves not-ready; the wallet
 * endpoints then return 503 until it comes up. `ensureReady()` lazily (re)runs the migration, so the
 * backend recovers on its own once Postgres is started — no restart required.
 */
@Injectable()
export class PgService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger('PgService');
  private pool?: Pool;
  private ready = false;

  constructor(private readonly config: ConfigService) {}

  async onModuleInit(): Promise<void> {
    const url = this.config.get<string>('database.url');
    if (!url) {
      this.logger.warn('DATABASE_URL not set — demo balances/transfers disabled');
      return;
    }
    this.pool = new Pool({
      connectionString: url,
      max: 10,
      // Fail fast rather than hanging the request/boot if Postgres is absent.
      connectionTimeoutMillis: 4000,
    });
    // A pool-level error (e.g. server restart) must not bubble up as an unhandled rejection.
    this.pool.on('error', (err) => this.logger.warn(`pg pool error: ${err.message}`));
    if (await this.ensureReady()) {
      this.logger.log('Postgres connected — demo wallet ready (demo_users, demo_transfers)');
    } else {
      this.logger.warn(
        'Postgres unavailable at boot — wallet endpoints return 503 until it is up ' +
          '(start it with: docker compose up -d)',
      );
    }
  }

  async onModuleDestroy(): Promise<void> {
    await this.pool?.end().catch(() => undefined);
  }

  /** True once the schema is in place. Lazily (re)connects + migrates so a late Postgres recovers. */
  async ensureReady(): Promise<boolean> {
    if (this.ready) return true;
    if (!this.pool) return false;
    try {
      await this.pool.query(SCHEMA_SQL);
      this.ready = true;
    } catch (err) {
      this.ready = false;
      this.logger.debug?.(`Postgres not ready yet: ${(err as Error).message}`);
    }
    return this.ready;
  }

  /** One-shot parameterised query on a pooled connection. */
  async query(text: string, params?: unknown[]): Promise<QueryResult> {
    if (!this.pool) throw new Error('Postgres pool not initialised');
    return this.pool.query(text, params as any[]);
  }

  /**
   * Run `fn` inside a single BEGIN/COMMIT transaction on one dedicated connection; ROLLBACK on any
   * throw. This is what makes a transfer atomic — debit, credit and the log row all commit together
   * or not at all.
   */
  async tx<T>(fn: (client: PoolClient) => Promise<T>): Promise<T> {
    if (!this.pool) throw new Error('Postgres pool not initialised');
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const out = await fn(client);
      await client.query('COMMIT');
      return out;
    } catch (err) {
      await client.query('ROLLBACK').catch(() => undefined);
      throw err;
    } finally {
      client.release();
    }
  }
}
