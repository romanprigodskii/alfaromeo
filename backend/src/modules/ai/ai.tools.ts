import { AIMode, ActionTool } from './ai.types';

/**
 * Tool catalogue for the copilot (§11.7).
 *
 * - **Action tools** (`make_transfer`, `open_deposit`, `freeze_card`) — EXACTLY the three required
 *   for the demo. Each only ever produces a *draft*; the AI never executes. Scoped to `agent` mode.
 * - **Read-only tools** (`get_balance`, `explain_transaction`, `search_kb`) — no confirmation, no
 *   side effects; available in every mode. `escalate_to_human` is the mandatory escalation guardrail
 *   (also no side effect — it opens a support ticket simulation).
 *
 * `toolsForMode` is the scope guardrail: action tools are simply never offered outside `agent` mode,
 * so the model cannot call them there (defence-in-depth re-checks happen in `ai.service.ts`).
 */

/** Anthropic tool definition (mirrors `Anthropic.Tool` without importing the SDK type here). */
export interface ToolDef {
  name: string;
  description: string;
  input_schema: {
    type: 'object';
    properties: Record<string, unknown>;
    required?: string[];
  };
}

/** Personal agentic actions (agent mode). */
export const PERSONAL_ACTION_TOOLS: readonly ActionTool[] = ['make_transfer', 'open_deposit', 'freeze_card'];
/** Business agentic actions — the AI-бухгалтер (business mode, §8.2). */
export const BUSINESS_ACTION_TOOLS: readonly ActionTool[] = ['create_invoice', 'pay_supplier'];

export const ACTION_TOOLS: readonly ActionTool[] = [...PERSONAL_ACTION_TOOLS, ...BUSINESS_ACTION_TOOLS];

export function isActionTool(name: string): name is ActionTool {
  return (ACTION_TOOLS as readonly string[]).includes(name);
}

/** The action tools a given mode is allowed to PROPOSE — the scope guardrail (§11.7, §8.2). A business
 *  action can never surface in personal `agent` mode, nor a personal action in `business` mode. */
export function actionToolsForMode(mode: AIMode): readonly ActionTool[] {
  if (mode === 'agent') return PERSONAL_ACTION_TOOLS;
  if (mode === 'business') return BUSINESS_ACTION_TOOLS;
  return [];
}

/** Is `name` an action tool that `mode` is permitted to use? Defence-in-depth re-check (`ai.service.ts`). */
export function isActionToolForMode(name: string, mode: AIMode): name is ActionTool {
  return (actionToolsForMode(mode) as readonly string[]).includes(name);
}

// ── Action tools (agent mode only) — produce drafts, never execute ───────────

const MAKE_TRANSFER: ToolDef = {
  name: 'make_transfer',
  description:
    'Подготовить ЧЕРНОВИК перевода денег. НЕ исполняет перевод — возвращает черновик, который ' +
    'пользователь подтверждает биометрией. Используй, когда пользователь явно просит перевести/' +
    'отправить деньги конкретному получателю.',
  input_schema: {
    type: 'object',
    properties: {
      to: { type: 'string', description: 'Получатель: имя из контактов, телефон или подпись (напр. «маме»).' },
      amount: { type: 'number', description: 'Сумма перевода (положительное число).' },
      currency: { type: 'string', description: 'Валюта, ISO-код. По умолчанию RUB.', default: 'RUB' },
    },
    required: ['to', 'amount'],
  },
};

const OPEN_DEPOSIT: ToolDef = {
  name: 'open_deposit',
  description:
    'Подготовить ЧЕРНОВИК открытия вклада или крипто-стейка. НЕ открывает вклад — возвращает ' +
    'черновик для подтверждения. Используй при просьбе открыть вклад / положить на депозит / застейкать.',
  input_schema: {
    type: 'object',
    properties: {
      amount: { type: 'number', description: 'Сумма вклада (положительное число).' },
      term: { type: 'number', description: 'Срок в месяцах (для рублёвого вклада).' },
      type: { type: 'string', enum: ['ruble', 'stake'], description: 'ruble — рублёвый вклад; stake — крипто-стейкинг.' },
    },
    required: ['amount', 'type'],
  },
};

const FREEZE_CARD: ToolDef = {
  name: 'freeze_card',
  description:
    'Подготовить ЧЕРНОВИК заморозки карты. НЕ замораживает — возвращает черновик для подтверждения. ' +
    'Используй при просьбе заморозить/заблокировать карту (например, при утере).',
  input_schema: {
    type: 'object',
    properties: {
      cardId: { type: 'string', description: 'ID карты. Если не указан — берётся карта по умолчанию.' },
    },
    required: [],
  },
};

// ── Business action tools (business mode only) — produce drafts, never execute ─

const CREATE_INVOICE: ToolDef = {
  name: 'create_invoice',
  description:
    'Подготовить ЧЕРНОВИК выставления счёта (инвойса) контрагенту. НЕ выставляет счёт — возвращает ' +
    'черновик, который пользователь подтверждает биометрией. Используй, когда предприниматель просит ' +
    'выставить/сделать счёт на оплату для клиента/контрагента. Это входящий платёж (дебиторка) — ' +
    'деньги не уходят со счёта компании.',
  input_schema: {
    type: 'object',
    properties: {
      counterparty: { type: 'string', description: 'Контрагент-плательщик (название юрлица/ИП), напр. «ООО Ромашка».' },
      amount: { type: 'number', description: 'Сумма счёта в рублях (положительное число).' },
      description: { type: 'string', description: 'Назначение платежа / за что счёт (необязательно).' },
      dueDays: { type: 'number', description: 'Срок оплаты в днях от сегодня (по умолчанию 7).' },
    },
    required: ['counterparty', 'amount'],
  },
};

const PAY_SUPPLIER: ToolDef = {
  name: 'pay_supplier',
  description:
    'Подготовить ЧЕРНОВИК оплаты поставщику/контрагенту по счёту или реквизитам. НЕ исполняет платёж — ' +
    'возвращает черновик для подтверждения биометрией. Это исходящий платёж: крупные суммы будут ' +
    'помечены как требующие подтверждения оператора/второй подписи (2-of-N, §8.2). Используй при ' +
    'просьбе оплатить поставщику / провести платёж контрагенту.',
  input_schema: {
    type: 'object',
    properties: {
      supplier: { type: 'string', description: 'Получатель: поставщик/контрагент (название), напр. «Поставки-Юг».' },
      amount: { type: 'number', description: 'Сумма платежа в рублях (положительное число).' },
      invoiceId: { type: 'string', description: 'Номер счёта поставщика, если указан (необязательно).' },
      description: { type: 'string', description: 'Назначение платежа (необязательно).' },
    },
    required: ['supplier', 'amount'],
  },
};

// ── Read-only tools (every mode) — executed server-side, no confirmation ─────

const GET_BALANCE: ToolDef = {
  name: 'get_balance',
  description: 'Вернуть текущие балансы по счетам активного профиля. Read-only, без подтверждения.',
  input_schema: { type: 'object', properties: {} },
};

const EXPLAIN_TRANSACTION: ToolDef = {
  name: 'explain_transaction',
  description:
    'Объяснить операцию пользователя простыми словами. Read-only. Если transactionId не указан — ' +
    'берётся последняя операция.',
  input_schema: {
    type: 'object',
    properties: {
      transactionId: { type: 'string', description: 'ID операции (необязательно).' },
    },
  },
};

const SEARCH_KB: ToolDef = {
  name: 'search_kb',
  description:
    'Найти ответ в базе знаний банка (продукты, тарифы, лимиты, инструкции). Read-only. Используй ' +
    'для фактических вопросов «как/что/где» по банку.',
  input_schema: {
    type: 'object',
    properties: {
      query: { type: 'string', description: 'Поисковый запрос на русском.' },
    },
    required: ['query'],
  },
};

const ESCALATE_TO_HUMAN: ToolDef = {
  name: 'escalate_to_human',
  description:
    'Создать обращение к живому оператору поддержки. Используй ОБЯЗАТЕЛЬНО, когда пользователь ' +
    'просит человека/оператора или вопрос вне твоих возможностей. Read-only (создаёт тикет-симуляцию).',
  input_schema: {
    type: 'object',
    properties: {
      reason: { type: 'string', description: 'Краткая причина обращения (без персональных данных).' },
    },
  },
};

export const READONLY_TOOLS: readonly string[] = [
  'get_balance',
  'explain_transaction',
  'search_kb',
  'escalate_to_human',
];

export function isReadonlyTool(name: string): boolean {
  return READONLY_TOOLS.includes(name);
}

const READONLY_DEFS = [GET_BALANCE, EXPLAIN_TRANSACTION, SEARCH_KB, ESCALATE_TO_HUMAN];
const PERSONAL_ACTION_DEFS = [MAKE_TRANSFER, OPEN_DEPOSIT, FREEZE_CARD];
const BUSINESS_ACTION_DEFS = [CREATE_INVOICE, PAY_SUPPLIER];

/**
 * Tools offered to the model for `mode` — the scope guardrail (§11.7, §8.2). Personal action tools are
 * exposed ONLY in `agent` mode; business action tools ONLY in `business` mode; every mode gets the
 * read-only set. The model literally cannot call a tool it isn't given (defence-in-depth re-checks in
 * `ai.service.ts` via `isActionToolForMode`).
 */
export function toolsForMode(mode: AIMode): ToolDef[] {
  if (mode === 'agent') return [...READONLY_DEFS, ...PERSONAL_ACTION_DEFS];
  if (mode === 'business') return [...READONLY_DEFS, ...BUSINESS_ACTION_DEFS];
  return [...READONLY_DEFS];
}
