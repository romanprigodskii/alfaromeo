import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { AIEngine, EngineTurnParams, ToolCall, TurnResult } from './ai.engine';
import { AiContextService, BusinessCashflow } from './ai.context';
import { AiKnowledgeBase } from './ai.kb';
import { AIMode } from './ai.types';

/**
 * Deterministic offline engine (§11.7 fallback). Used when no `ANTHROPIC_API_KEY` is configured (or
 * Anthropic is unreachable) so the SSE stream, action drafts, guardrails and audit are fully
 * demonstrable without a key — and the demo never hard-fails. It is NOT a language model: it classifies
 * the last user message with simple heuristics, then either streams a templated answer (grounded in the
 * real profile context / KB) or returns an action tool call that flows through the exact same draft +
 * guardrail path as the live engine.
 */
@Injectable()
export class OfflineEngine implements AIEngine {
  readonly label = 'offline';
  readonly live = false;

  constructor(
    private readonly context: AiContextService,
    private readonly kb: AiKnowledgeBase,
  ) {}

  async runTurn(
    params: EngineTurnParams,
    onToken: (t: string) => void,
    _signal?: AbortSignal,
  ): Promise<TurnResult> {
    // Business mode (§8.2) has its own intents (invoice / pay-supplier drafts + cashflow/tax answers),
    // grounded in the same mock scenario the live engine sees via the context digest.
    if (params.mode === 'business') {
      return this.runBusinessTurn(params, onToken);
    }

    const text = lastUserText(params.messages);
    const intent = classify(text);

    // Action intents only fire in agent mode (scope guardrail mirrored offline).
    if (isActionIntent(intent)) {
      if (params.mode !== 'agent') {
        await this.streamText(
          onToken,
          'Это действие можно выполнить в режиме «Агент». Переключитесь в него — и я подготовлю черновик с подтверждением по Face ID. Также могу подключить оператора.',
        );
        return done([]);
      }
      return this.actionCall(intent, text, params.profileId, onToken);
    }

    switch (intent.kind) {
      case 'balance':
        await this.streamText(onToken, this.balanceAnswer(params.profileId));
        return done([]);
      case 'explain':
        await this.streamText(onToken, this.explainAnswer(params.profileId));
        return done([]);
      case 'faq':
        await this.streamText(onToken, this.faqAnswer(text));
        return done([]);
      case 'escalate':
        await this.streamText(
          onToken,
          `Подключаю оператора — создал обращение ${ticketId()}. Живой специалист ответит в чате в ближайшее время. Чем ещё помочь?`,
        );
        return { ...done([]), escalated: true };
      case 'offdomain':
        await this.streamText(
          onToken,
          'Я — копилот банка «Альфа-Ромео» и помогаю только с банковскими вопросами: счета, карты, переводы, вклады, крипто, тарифы. С этим — с удовольствием. Чем помочь по банку?',
        );
        return done([]);
      default:
        await this.streamText(onToken, this.generalAnswer(params.profileId, params.mode));
        return done([]);
    }
  }

  // ── Action drafts (agent mode) ───────────────────────────────────────────────

  private async actionCall(
    intent: Intent,
    text: string,
    profileId: string,
    onToken: (t: string) => void,
  ): Promise<TurnResult> {
    let call: ToolCall;
    switch (intent.kind) {
      case 'transfer': {
        // Don't silently draft a transfer "to «контакт»" — ask who, instead of guessing.
        if (!intent.recipient) {
          await this.streamText(onToken, 'Кому перевести? Уточните получателя — имя из контактов или номер телефона.');
          return done([]);
        }
        const amount = intent.amount ?? 0;
        const currency = intent.currency ?? 'RUB';
        const to = intent.recipient;
        await this.streamText(onToken, `Готовлю черновик перевода ${fmt(amount)} ${currency} получателю «${to}».`);
        call = synthCall('make_transfer', { to, amount, currency });
        break;
      }
      case 'deposit': {
        const amount = intent.amount ?? 0;
        const type = intent.depositType ?? 'ruble';
        const term = intent.term ?? 6;
        await this.streamText(onToken, `Готовлю черновик ${type === 'stake' ? 'крипто-стейка' : 'вклада'} на ${fmt(amount)} ₽.`);
        call = synthCall('open_deposit', type === 'stake' ? { amount, type } : { amount, term, type });
        break;
      }
      case 'freeze': {
        const card = this.context.defaultCard(profileId);
        const cardId = intent.cardId ?? card?.id ?? 'card-virt';
        const last4 = card?.last4 ? ` ··${card.last4}` : '';
        await this.streamText(onToken, `Готовлю черновик заморозки карты${last4}.`);
        call = synthCall('freeze_card', { cardId });
        break;
      }
      default:
        return done([]);
    }
    await this.streamText(onToken, ' Подтвердите действие по Face ID, чтобы я его выполнил.');
    return { toolCalls: [call], assistantContent: [{ type: 'tool_use', ...call }], stopReason: 'tool_use' };
  }

  // ── Business mode (§8.2) — AI-бухгалтер offline ──────────────────────────────

  private async runBusinessTurn(params: EngineTurnParams, onToken: (t: string) => void): Promise<TurnResult> {
    const text = lastUserText(params.messages);
    const t = text.toLowerCase();
    const cf = this.context.get(params.profileId).businessCashflow;

    if (/оператор|человек|свяжите|жалоб/.test(t)) {
      await this.streamText(onToken, `Подключаю специалиста — создал обращение ${ticketId()}. Живой бухгалтер/оператор ответит в чате. Чем ещё помочь?`);
      return { ...done([]), escalated: true };
    }

    // Agentic: выставить счёт (create_invoice) — входящий платёж.
    if (isInvoiceRequest(t)) {
      const amount = parseAmount(t);
      const counterparty = parseOrg(text, /(?:для|клиент[а-яё]*|контрагент[а-яё]*|компани[ияей]*)/i);
      if (!amount || !counterparty) {
        await this.streamText(onToken, 'Готов выставить счёт. Уточните, пожалуйста, контрагента и сумму — например: «выставь счёт на 120 000 ₽ для ООО Ромашка».');
        return done([]);
      }
      await this.streamText(onToken, `Готовлю черновик счёта на ${fmt(amount)} ₽ для «${counterparty}».`);
      const call = synthCall('create_invoice', { counterparty, amount, dueDays: 7 });
      await this.streamText(onToken, ' Подтвердите по Face ID — и счёт будет выставлен и отправлен.');
      return { toolCalls: [call], assistantContent: [{ type: 'tool_use', ...call }], stopReason: 'tool_use' };
    }

    // Agentic: оплатить поставщику (pay_supplier) — исходящий платёж.
    if (isPaySupplierRequest(t)) {
      const amount = parseAmount(t);
      const supplier = parseOrg(text, /(?:поставщик[а-яё]*|контрагент[а-яё]*|компани[ияей]*)/i);
      if (!amount || !supplier) {
        await this.streamText(onToken, 'Готов подготовить оплату поставщику. Уточните получателя и сумму — например: «оплати поставщику «Поставки-Юг» 85 000 ₽».');
        return done([]);
      }
      await this.streamText(onToken, `Готовлю черновик оплаты поставщику «${supplier}» на ${fmt(amount)} ₽.`);
      const call = synthCall('pay_supplier', { supplier, amount });
      await this.streamText(onToken, ' Подтвердите по Face ID. Крупные платежи потребуют второй подписи.');
      return { toolCalls: [call], assistantContent: [{ type: 'tool_use', ...call }], stopReason: 'tool_use' };
    }

    // Informational — grounded in the cashflow scenario.
    await this.streamText(onToken, this.businessInfoAnswer(t, cf));
    return done([]);
  }

  private businessInfoAnswer(t: string, cf?: BusinessCashflow): string {
    if (!cf) {
      return 'Я — AI-бухгалтер «Альфа-Ромео». Помогу с прогнозом денежного потока, кассовыми разрывами, налогами и счетами. Спросите, например: «когда возможен кассовый разрыв?».';
    }
    if (/налог|режим|оптимиз|усн|нагрузк/.test(t)) {
      return `По налогам: текущий режим — ${cf.tax.current}. ${cap(cf.tax.suggested)} снизит нагрузку примерно на ${cf.tax.savingPercent}% (≈ ${fmt(cf.tax.savingRubPerYear)} ₽/год) при вашей доле расходов. Это оценка — точный расчёт зависит от учётной политики и года перехода. Подготовить черновик заявления о смене режима?`;
    }
    if (/расход|траты|категори|анализ/.test(t)) {
      const top = cf.topExpenses.slice(0, 4).map((e) => `${e.label} — ${e.sharePercent}%`).join('; ');
      return `Структура расходов за месяц (авто-классификация): ${top}. Основной отток — закупки и ФОТ. Хотите детализацию по категории или черновик отчёта?`;
    }
    if (/счёт|счет|дебиторк|неоплач|invoice/.test(t)) {
      return `Неоплаченные выставленные счета: ${cf.unpaidInvoices.count} на ${fmt(cf.unpaidInvoices.totalRub)} ₽. Ускорение их оплаты — самый быстрый способ закрыть кассовый разрыв. Могу выставить новый счёт — скажите контрагента и сумму.`;
    }
    // Forecast / cash-gap (default business answer).
    if (cf.troughBalanceRub < 0) {
      return `Прогноз денежного потока на 90 дней: примерно через ${cf.troughInDays} дн. ожидается кассовый разрыв — дефицит ликвидности около ${fmt(Math.abs(cf.troughBalanceRub))} ₽ (остаток уйдёт в минус с текущих ${fmt(cf.startBalanceRub)} ₽). Рекомендую заранее ускорить оплату дебиторки (${cf.unpaidInvoices.count} счёта на ${fmt(cf.unpaidInvoices.totalRub)} ₽), перенести крупный платёж поставщику или подключить овердрафт. Показать, как сместить разрыв?`;
    }
    return `Прогноз на 90 дней: минимальный остаток ≈ ${fmt(cf.troughBalanceRub)} ₽ — кассового разрыва не ожидается. Текущий остаток ≈ ${fmt(cf.startBalanceRub)} ₽.`;
  }

  // ── Templated answers (grounded in real context / KB) ────────────────────────

  private balanceAnswer(profileId: string): string {
    const accounts = this.context.accounts(profileId);
    if (!accounts.length) return 'Пока не вижу счетов в этом профиле.';
    const parts = accounts.map((a) => `${accountWord(a.type)} — ${fmt(a.balance)} ${a.currency}`);
    return `Вот балансы по вашим счетам: ${parts.join('; ')}. Нужна детализация или перевод? Я рядом.`;
  }

  private explainAnswer(profileId: string): string {
    const tx = this.context.transaction(profileId);
    if (!tx) return 'Не нашёл недавних операций для разбора.';
    return (
      `Последняя операция ${tx.id}: ${kindWord(tx.kind)} на ${fmt(tx.amount)} ${tx.currency}` +
      `${tx.counterparty ? ` (${tx.counterparty})` : ''}, статус «${tx.status}»` +
      `${tx.fee ? `, комиссия ${fmt(tx.fee)} ${tx.currency}` : ''}. Если операция кажется незнакомой — могу подготовить заморозку карты или подключить оператора.`
    );
  }

  private faqAnswer(text: string): string {
    const hits = this.kb.search(text, 1);
    if (!hits.length) {
      return 'Не нашёл точного ответа в базе знаний. Могу подключить оператора или попробуйте переформулировать вопрос.';
    }
    return `${hits[0].title}: ${hits[0].snippet}`;
  }

  private generalAnswer(profileId: string, mode: AIMode): string {
    const free = this.context.accounts(profileId).find((a) => a.type === 'current');
    const balanceBit = free ? ` Свободно на текущем счёте около ${fmt(free.balance)} ${free.currency}.` : '';
    const modeBit =
      mode === 'agent'
        ? ' В режиме «Агент» могу подготовить перевод, вклад или заморозку карты — с подтверждением по Face ID.'
        : mode === 'coach'
          ? ' Могу подсказать, где оптимизировать траты и куда отложить.'
          : ' Помогу разобраться с операциями, продуктами и тарифами.';
    return `Я — Claude-копилот Альфа-Ромео.${balanceBit}${modeBit} Что хотите сделать?`;
  }

  // ── Streaming ────────────────────────────────────────────────────────────────

  /** Emit text as word-sized token events with a small delay — a realistic typewriter stream. */
  private async streamText(onToken: (t: string) => void, text: string): Promise<void> {
    const words = text.split(/(\s+)/); // keep whitespace as its own pieces
    for (const w of words) {
      if (w.length === 0) continue;
      onToken(w);
      await sleep(12);
    }
  }
}

// ── Intent classification ──────────────────────────────────────────────────────

type IntentKind =
  | 'transfer'
  | 'deposit'
  | 'freeze'
  | 'balance'
  | 'explain'
  | 'faq'
  | 'escalate'
  | 'offdomain'
  | 'general';

interface Intent {
  kind: IntentKind;
  amount?: number;
  currency?: string;
  recipient?: string;
  depositType?: 'ruble' | 'stake';
  term?: number;
  cardId?: string;
}

function isActionIntent(i: Intent): boolean {
  return i.kind === 'transfer' || i.kind === 'deposit' || i.kind === 'freeze';
}

const RELATIONS = ['маме', 'папе', 'жене', 'мужу', 'брату', 'сестре', 'другу', 'подруге', 'сыну', 'дочери', 'бабушке', 'дедушке'];

function classify(raw: string): Intent {
  const t = raw.toLowerCase();

  // Informational phrasing ("как работает перевод", "какая комиссия") is a QUESTION, not a command —
  // it must route to the KB, never to an action draft. Action intents require an imperative verb.
  // NB: `\b` is ASCII-only in JS regex (no `u` flag), so it never fires next to Cyrillic — match a
  // leading/standalone "как " with an explicit space/anchor instead.
  const informational = /(^|\s)как\s|что такое|какая комисси|какие комисси|сколько стоит|можно ли|расскажи|подскажи|объясни как|чем отлич/.test(t);

  if (!informational && /перевед[иь]|переведите|отправь|перечисли|скинь(?:те)?/.test(t)) {
    return { kind: 'transfer', amount: parseAmount(t), currency: parseCurrency(t), recipient: parseRecipient(raw) };
  }
  if (!informational && /открой вклад|открыть вклад|оформи вклад|положи(?:ть)? на (вклад|депозит|счёт|счет)|застейк|сделай вклад|хочу вклад/.test(t)) {
    const stake = /стейк|крипт|btc|eth|usdt/.test(t);
    // Strip a recognised term clause ("на 12 месяцев") so parseAmount doesn't grab the term as the sum.
    const forAmount = t.replace(/на\s+\d+\s*(?:месяц\w*|мес|год\w*|лет)/g, ' ');
    return { kind: 'deposit', amount: parseAmount(forAmount), depositType: stake ? 'stake' : 'ruble', term: parseTerm(t) };
  }
  if (!informational && /заморозь|заморозить карт|заблокируй карт|потерял карт|украли карт|freeze/.test(t)) {
    return { kind: 'freeze' };
  }
  if (/баланс|сколько у меня|сколько денег|остаток|на сч[её]т|свободн/.test(t)) {
    return { kind: 'balance' };
  }
  if (/объясни|что за (операц|транзакц|списан|платеж|покупк)|почему списал|разбери операц|что это за/.test(t)) {
    return { kind: 'explain' };
  }
  if (/оператор|человек|поддержк|менеджер|жалоб|свяжите/.test(t)) {
    return { kind: 'escalate' };
  }
  if (isOffDomain(t)) {
    return { kind: 'offdomain' };
  }
  if (/как |что такое|какой|где |тариф|лимит|комисси|вклад|стейк|крипт|карт|перевод|сбп|цифровой рубль/.test(t)) {
    return { kind: 'faq' };
  }
  return { kind: 'general' };
}

function isOffDomain(t: string): boolean {
  const off = /погод|рецепт|анекдот|стих|футбол|спорт|кино(?!\b.*подписк)|политик|новости|кто тебя сделал|напиши код|реши уравнен/;
  const bank = /банк|счет|счёт|карт|перевод|вклад|крипт|тариф|деньг|баланс|платеж|операц/;
  return off.test(t) && !bank.test(t);
}

function parseAmount(t: string): number | undefined {
  // First number, allowing thin/space grouping and a decimal comma/point: «5 000», «5000,50».
  const m = t.match(/(\d[\d\s ]*([.,]\d+)?)/);
  if (!m) return undefined;
  const n = Number(m[1].replace(/[\s ]/g, '').replace(',', '.'));
  return Number.isFinite(n) ? n : undefined;
}

function parseTerm(t: string): number | undefined {
  const m = t.match(/на\s+(\d+)\s*(месяц|мес|год|лет)/);
  if (!m) return undefined;
  const n = Number(m[1]);
  if (!Number.isFinite(n)) return undefined;
  return /год|лет/.test(m[2]) ? n * 12 : n;
}

function parseCurrency(t: string): string {
  if (/usdt/.test(t)) return 'USDT';
  if (/btc|бткоин|биткоин/.test(t)) return 'BTC';
  if (/eth|эфир/.test(t)) return 'ETH';
  if (/доллар|usd|\$/.test(t)) return 'USD';
  if (/евро|eur|€/.test(t)) return 'EUR';
  return 'RUB';
}

// ── Business intent parsing (offline, §8.2) ──────────────────────────────────

// NB: JS regex `\w` is ASCII-only (no `u` flag) → it never matches Cyrillic. Use explicit [а-яё]
// classes for word-stem suffixes, never `\w`, or a Cyrillic stem won't extend past its first letter.
function isInvoiceRequest(t: string): boolean {
  return /выстав[а-яё]*\s+сч[её]т|сделай\s+сч[её]т|создай\s+сч[её]т|сч[её]т\s+на\s+\d|инвойс|invoice/.test(t);
}

function isPaySupplierRequest(t: string): boolean {
  // An outbound payment to a counterparty — "оплати/заплати поставщику", "проведи платёж контрагенту".
  return /(?:оплат[а-яё]*|заплат[а-яё]*|проведи\s+плат[её]ж|плат[её]ж)\s+(?:поставщик[а-яё]*|контрагент[а-яё]*)|поставщик[а-яё]*.*(?:оплат|заплат)/.test(t);
}

/** Pull an org/counterparty name: a «…»/"…" quote first, else 1–4 words after a cue (для/поставщику…). */
function parseOrg(raw: string, cue: RegExp): string | undefined {
  const q = raw.match(/[«"“]([^»"”]{2,40})[»"”]/);
  if (q) return q[1].trim();
  const src = cue.source;
  const re = new RegExp(`${src}\\s+([A-ZА-ЯЁ][A-Za-zА-Яа-яЁё0-9.\\-]*(?:\\s+[A-ZА-ЯЁ0-9«"][A-Za-zА-Яа-яЁё0-9.\\-]*){0,3})`);
  const m = raw.match(re);
  if (!m) return undefined;
  // Trim a trailing amount/preposition clause the greedy match may have caught ("… на 120000").
  return m[1].replace(/\s+(?:на|за|по|сумм\w*|\d).*$/i, '').replace(/[«»"“”]/g, '').trim() || undefined;
}

function cap(s: string): string {
  return s.length ? s[0].toUpperCase() + s.slice(1) : s;
}

function parseRecipient(raw: string): string | undefined {
  const lower = raw.toLowerCase();
  for (const r of RELATIONS) {
    if (lower.includes(r)) return r;
  }
  // A capitalized name token (skip the leading word of the sentence).
  const caps = raw.match(/(?:^|\s)([А-ЯЁ][а-яё]{2,})/g);
  if (caps && caps.length) {
    const name = caps[caps.length - 1].trim();
    if (!/^Переведи|^Отправь|^Перечисли|^Скинь/i.test(name)) return name;
  }
  return undefined;
}

// ── Synthetic helpers ────────────────────────────────────────────────────────

function synthCall(name: string, input: Record<string, unknown>): ToolCall {
  return { id: `offline_${randomUUID()}`, name, input };
}

function done(toolCalls: ToolCall[]): TurnResult {
  return { toolCalls, assistantContent: [], stopReason: toolCalls.length ? 'tool_use' : 'end_turn' };
}

function lastUserText(messages: EngineTurnParams['messages']): string {
  for (let i = messages.length - 1; i >= 0; i--) {
    const m = messages[i];
    if (m.role === 'user' && typeof m.content === 'string') return m.content;
  }
  return '';
}

function ticketId(): string {
  return `SUP-${randomUUID().slice(0, 8).toUpperCase()}`;
}

function accountWord(t: string): string {
  return { current: 'текущий', savings: 'накопительный', crypto: 'крипто', digital_ruble: 'цифровой ₽' }[t] ?? t;
}
function kindWord(k: string): string {
  return { transfer: 'перевод', payment: 'платёж', convert: 'конвертация', trade: 'сделка', payout: 'выплата', acquire: 'эквайринг' }[k] ?? k;
}
function fmt(n: number): string {
  return new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 2 }).format(n);
}
function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}
