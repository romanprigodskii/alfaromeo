import { Injectable } from '@nestjs/common';
import {
  Account,
  Card,
  Deposit,
  MobilePlan,
  Profile,
  Subscription,
  Transaction,
} from '../../contracts';

/**
 * Profile context provider for the copilot (§11.7).
 *
 * In production this reads through the Accounts / Cards / Payments services (§11.2). Those modules
 * are still stubs (Phase 0/1), so this serves a small, realistic mock dataset — the same role the
 * iOS `MockData` plays on the client. Everything here is already **PII-minimised**: cards expose
 * only `last4` + state (never a PAN), transactions carry a counterparty *label* (never an account
 * number), and no phone number is included. `buildContextDigest` is what actually reaches Claude.
 */

/** Everything the copilot may know about one profile. Minimised by construction. */
export interface ProfileContext {
  profile: Profile;
  subscription: Subscription;
  accounts: Account[];
  cards: Card[];
  recentTransactions: Transaction[];
  mobilePlan?: MobilePlan;
  /** Business-only — grounds the AI-бухгалтер's 90-day forecast / cash-gap / tax answers (§8.2). */
  businessCashflow?: BusinessCashflow;
}

/**
 * Mock business cashflow scenario (§8.2). Deterministic — the SAME scenario the iOS AI-accountant
 * renders on its 90-day chart and insight cards, so the streamed chat and the visual cards agree. The
 * cash gap is expressed RELATIVELY (in days) so it doesn't drift against the server clock; the client
 * stamps the absolute date for display.
 */
export interface BusinessCashflow {
  /** Operating-account balance today, ₽. */
  startBalanceRub: number;
  /** Projected minimum balance over the 90-day horizon, ₽ (negative ⇒ a cash gap). */
  troughBalanceRub: number;
  /** Days from today to that minimum. */
  troughInDays: number;
  /** Current simplified-tax regime + a cheaper alternative and the estimated saving. */
  tax: { current: string; suggested: string; savingPercent: number; savingRubPerYear: number };
  /** Top monthly expense categories (label → share %), already auto-classified. */
  topExpenses: { label: string; sharePercent: number }[];
  /** Receivables: unpaid invoices the business has issued. */
  unpaidInvoices: { count: number; totalRub: number };
}

@Injectable()
export class AiContextService {
  /**
   * Resolve a profile's context. Unknown ids fall back to a demo profile — but pick the BUSINESS demo
   * for a business-looking id (e.g. the iOS `p_business`), so the AI-бухгалтер is grounded in the
   * cashflow scenario for any business profile, not just the canonical `profile-business-demo` (§8.2).
   */
  get(profileId: string): ProfileContext {
    if (DATASET[profileId]) return DATASET[profileId];
    const base = /biz|business/i.test(profileId) ? DATASET[DEMO_BUSINESS] : DATASET[DEMO_PERSONAL];
    return withId(base, profileId);
  }

  /** A profile's accounts (backs the `get_balance` read-only tool). */
  accounts(profileId: string): Account[] {
    return this.get(profileId).accounts;
  }

  /** Look up one transaction (backs `explain_transaction`); newest first when `txId` is omitted. */
  transaction(profileId: string, txId?: string): Transaction | undefined {
    const txs = this.get(profileId).recentTransactions;
    if (!txId) return txs[0];
    return txs.find((t) => t.id === txId) ?? txs[0];
  }

  /** A card to act on (backs `freeze_card` when the model doesn't specify one). */
  defaultCard(profileId: string): Card | undefined {
    const cards = this.get(profileId).cards;
    return cards.find((c) => c.isDefault) ?? cards[0];
  }

  /**
   * The compact, PII-light context block injected into the system prompt. Amounts and labels only —
   * no PANs, no phone, no account numbers. Kept short so it's cheap and leaks nothing sensitive.
   */
  buildContextDigest(profileId: string): string {
    const ctx = this.get(profileId);
    const lines: string[] = [];

    lines.push(`Профиль: ${ctx.profile.displayName ?? ctx.profile.type} (${ctx.profile.type}), тариф ${ctx.subscription.tier}.`);

    const balances = ctx.accounts
      .map((a) => `${accountLabel(a.type)} — ${fmtAmount(a.balance)} ${a.currency}`)
      .join('; ');
    lines.push(`Счета: ${balances || 'нет данных'}.`);

    if (ctx.cards.length) {
      const cards = ctx.cards
        .map((c) => `${cardLabel(c.type)} ··${c.last4} (${cardState(c.state)})`)
        .join('; ');
      lines.push(`Карты: ${cards}.`);
    }

    if (ctx.recentTransactions.length) {
      const txs = ctx.recentTransactions
        .slice(0, 5)
        .map((t) => `${t.id}: ${txKind(t.kind)} ${fmtAmount(t.amount)} ${t.currency}${t.counterparty ? ` · ${t.counterparty}` : ''} [${t.status}]`)
        .join('; ');
      lines.push(`Последние операции: ${txs}.`);
    }

    if (ctx.mobilePlan) {
      const m = ctx.mobilePlan;
      lines.push(`Ромео Mobile: тариф ${m.tariff}, осталось ${Math.max(0, m.dataGb - m.usedGb)} ГБ из ${m.dataGb}.`);
    }

    if (ctx.profile.type === 'business' && ctx.businessCashflow) {
      lines.push(this.businessSection(ctx.businessCashflow));
    }

    return lines.join('\n');
  }

  /** The AI-бухгалтер's grounding block (§8.2): forecast, cash gap, tax, expenses, receivables. */
  private businessSection(cf: BusinessCashflow): string {
    const gap = cf.troughBalanceRub < 0
      ? `Прогноз на 90 дней: примерно через ${cf.troughInDays} дн. ожидается КАССОВЫЙ РАЗРЫВ — минимальный остаток опустится до ≈ ${fmtAmount(cf.troughBalanceRub)} ₽ (дефицит ≈ ${fmtAmount(Math.abs(cf.troughBalanceRub))} ₽). После этого поток восстанавливается за счёт поступлений от клиентов.`
      : `Прогноз на 90 дней: минимальный остаток ≈ ${fmtAmount(cf.troughBalanceRub)} ₽ — кассового разрыва не ожидается.`;
    const tax = `Налоги: текущий режим — ${cf.tax.current}. Рекомендация — ${cf.tax.suggested}: при текущей доле расходов это снижает нагрузку примерно на ${cf.tax.savingPercent}% (≈ ${fmtAmount(cf.tax.savingRubPerYear)} ₽/год).`;
    const exp = `Структура расходов (за месяц, авто-классификация): ${cf.topExpenses.map((e) => `${e.label} ${e.sharePercent}%`).join(', ')}.`;
    const inv = `Неоплаченные выставленные счета (дебиторка): ${cf.unpaidInvoices.count} на ${fmtAmount(cf.unpaidInvoices.totalRub)} ₽.`;
    return [
      `Бизнес-контекст (для AI-бухгалтера; текущий остаток операц. счёта ≈ ${fmtAmount(cf.startBalanceRub)} ₽):`,
      `• ${gap}`,
      `• ${tax}`,
      `• ${exp}`,
      `• ${inv}`,
    ].join('\n');
  }
}

// ── Labels (kept Russian + user-facing) ──────────────────────────────────────

function accountLabel(t: Account['type']): string {
  return { current: 'Текущий', savings: 'Накопительный', crypto: 'Крипто', digital_ruble: 'Цифровой ₽' }[t];
}
function cardLabel(t: Card['type']): string {
  return { virtual: 'Виртуальная', plastic: 'Пластиковая', crypto: 'Крипто', disposable: 'Одноразовая' }[t];
}
function cardState(s: Card['state']): string {
  return { active: 'активна', frozen: 'заморожена', issuing: 'выпускается', shipping: 'в доставке', expired: 'истекла', burned: 'погашена' }[s];
}
function txKind(k: Transaction['kind']): string {
  return { transfer: 'перевод', payment: 'платёж', convert: 'конвертация', trade: 'сделка', payout: 'выплата', acquire: 'эквайринг' }[k];
}
function fmtAmount(n: number): string {
  return new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 2 }).format(n);
}

// ── Demo dataset ──────────────────────────────────────────────────────────────

const DEMO_PERSONAL = 'profile-personal-demo';
const DEMO_BUSINESS = 'profile-business-demo';

function withId(base: ProfileContext, profileId: string): ProfileContext {
  // Reuse the demo personal context but stamp the requested id so scoping/audit stays consistent.
  return { ...base, profile: { ...base.profile, id: profileId } };
}

const DATASET: Record<string, ProfileContext> = {
  [DEMO_PERSONAL]: {
    profile: {
      id: DEMO_PERSONAL,
      userId: 'user-demo',
      type: 'personal',
      displayName: 'Личный',
      theme: null,
      createdAt: '2026-01-04T10:00:00.000Z',
    },
    subscription: { profileId: DEMO_PERSONAL, tier: 'pro', status: 'active', renewsAt: null, price: 399 },
    accounts: [
      { id: 'acc-cur', profileId: DEMO_PERSONAL, type: 'current', currency: 'RUB', balance: 184200.55 },
      { id: 'acc-sav', profileId: DEMO_PERSONAL, type: 'savings', currency: 'RUB', balance: 540000 },
      { id: 'acc-cry', profileId: DEMO_PERSONAL, type: 'crypto', currency: 'USDT', balance: 1250.4 },
    ],
    cards: [
      { id: 'card-virt', accountId: 'acc-cur', profileId: DEMO_PERSONAL, type: 'virtual', last4: '4417', state: 'active', designId: 'pro', isDefault: true, assetLink: null },
      { id: 'card-crypto', accountId: 'acc-cry', profileId: DEMO_PERSONAL, type: 'crypto', last4: '0291', state: 'active', designId: 'crypto', isDefault: false, assetLink: 'USDT' },
    ],
    recentTransactions: [
      { id: 'tx-1001', profileId: DEMO_PERSONAL, kind: 'payment', status: 'completed', amount: 2890, currency: 'RUB', counterparty: 'Пятёрочка', fee: 0, fxRate: null, createdAt: '2026-06-01T19:24:00.000Z' },
      { id: 'tx-1002', profileId: DEMO_PERSONAL, kind: 'transfer', status: 'completed', amount: 15000, currency: 'RUB', counterparty: 'Иван П.', fee: 0, fxRate: null, createdAt: '2026-05-31T12:10:00.000Z' },
      { id: 'tx-1003', profileId: DEMO_PERSONAL, kind: 'payment', status: 'completed', amount: 1199, currency: 'RUB', counterparty: 'Подписка «Кино»', fee: 0, fxRate: null, createdAt: '2026-05-30T08:00:00.000Z' },
      { id: 'tx-1004', profileId: DEMO_PERSONAL, kind: 'trade', status: 'completed', amount: 25000, currency: 'RUB', counterparty: 'BTC', fee: 75, fxRate: null, createdAt: '2026-05-28T15:42:00.000Z' },
    ],
    mobilePlan: {
      profileId: DEMO_PERSONAL,
      msisdn: '+7 900 ··· ·· 12',
      esimId: 'esim-demo',
      tariff: 'Ромео S',
      dataGb: 30,
      minutes: 600,
      usedGb: 12.4,
      usedMin: 210,
      roaming: false,
    },
  },
  [DEMO_BUSINESS]: {
    profile: {
      id: DEMO_BUSINESS,
      userId: 'user-demo',
      type: 'business',
      displayName: 'ООО «Ромео»',
      theme: 'graphite',
      createdAt: '2026-02-11T09:00:00.000Z',
    },
    subscription: { profileId: DEMO_BUSINESS, tier: 'biz_pro', status: 'active', renewsAt: null, price: 2900 },
    accounts: [
      { id: 'acc-biz-cur', profileId: DEMO_BUSINESS, type: 'current', currency: 'RUB', balance: 2750000 },
    ],
    cards: [
      { id: 'card-biz', accountId: 'acc-biz-cur', profileId: DEMO_BUSINESS, type: 'plastic', last4: '8830', state: 'active', designId: 'business', isDefault: true, assetLink: null },
    ],
    recentTransactions: [
      { id: 'tx-2001', profileId: DEMO_BUSINESS, kind: 'payout', status: 'completed', amount: 480000, currency: 'RUB', counterparty: 'Зарплатный реестр', fee: 0, fxRate: null, createdAt: '2026-06-01T10:00:00.000Z' },
      { id: 'tx-2002', profileId: DEMO_BUSINESS, kind: 'acquire', status: 'completed', amount: 96400, currency: 'RUB', counterparty: 'Эквайринг (QR)', fee: 1200, fxRate: null, createdAt: '2026-05-31T18:30:00.000Z' },
    ],
    // Mock cashflow scenario — mirror of the iOS AI-accountant's `BusinessCashflowMock` (§8.2).
    businessCashflow: {
      startBalanceRub: 2750000,
      troughBalanceRub: -1200000,
      troughInDays: 14,
      tax: {
        current: 'УСН «Доходы» 6%',
        suggested: 'переход на УСН «Доходы минус расходы» 15%',
        savingPercent: 8,
        savingRubPerYear: 210000,
      },
      topExpenses: [
        { label: 'Закупки/поставщики', sharePercent: 42 },
        { label: 'Зарплаты (ФОТ)', sharePercent: 28 },
        { label: 'Аренда', sharePercent: 12 },
        { label: 'Налоги и взносы', sharePercent: 9 },
        { label: 'Реклама', sharePercent: 6 },
        { label: 'Прочее', sharePercent: 3 },
      ],
      unpaidInvoices: { count: 3, totalRub: 980000 },
    },
  },
};
