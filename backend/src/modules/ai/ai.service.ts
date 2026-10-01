import { Injectable, Logger } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { PricingService } from '../pricing/pricing.service';
import { AiAuditService } from './ai.audit';
import { AiContextService } from './ai.context';
import { AiGuardrails } from './ai.guardrails';
import { AiKnowledgeBase } from './ai.kb';
import { AnthropicEngine } from './ai.anthropic';
import { OfflineEngine } from './ai.offline';
import { AIEngine, EngineMessage, ToolCall } from './ai.engine';
import { buildSystemPrompt } from './ai.prompt';
import { isActionTool, isActionToolForMode, isReadonlyTool, toolsForMode } from './ai.tools';
import {
  AIMode,
  ActionTool,
  ChatRequest,
  ConfirmActionRequest,
  ConfirmActionResult,
  SSESend,
  ToolDraft,
} from './ai.types';

const MAX_TURNS = 6;
const DEFAULT_PROFILE = 'profile-personal-demo';

/**
 * Copilot orchestration (§11.7). Engine-agnostic: it builds the system prompt + PII-light context,
 * streams a model turn, and applies the SAME guardrails / drafts / audit whichever engine answered.
 *
 * Key flow for `agent` mode: an action tool call becomes a *signed draft* (`toolDraft` SSE event) —
 * the AI NEVER executes. Real execution is a separate, biometric-gated step via `confirmAction`,
 * which re-verifies the draft signature and runs a simulation (no real ledger movement — demo, like
 * the rest of the project). Read-only tools (`get_balance` / `explain_transaction` / `search_kb` /
 * `escalate_to_human`) run server-side with no confirmation.
 */
@Injectable()
export class AiService {
  private readonly logger = new Logger('AiService');
  private readonly primary: AIEngine;
  /** Circuit breaker for the live engine: while open, turns run on the offline engine. */
  private liveDownUntil = 0;
  private liveDownReason: string | null = null;

  constructor(
    private readonly anthropic: AnthropicEngine,
    private readonly offline: OfflineEngine,
    private readonly context: AiContextService,
    private readonly kb: AiKnowledgeBase,
    private readonly guardrails: AiGuardrails,
    private readonly audit: AiAuditService,
    private readonly pricing: PricingService,
  ) {
    // Live Claude whenever a key is configured; otherwise the deterministic offline demo engine.
    this.primary = this.anthropic.available ? this.anthropic : this.offline;
    if (this.anthropic.available) {
      this.logger.log(`AI online · engine=anthropic · ${this.anthropic.describe()} · limit=${this.guardrails.amountLimitRub}₽`);
    } else {
      this.logger.warn('ANTHROPIC_API_KEY not set — AI runs in OFFLINE demo mode (deterministic). Set the key for real Claude.');
    }
  }

  /**
   * Engine for the next turn: the live engine unless its breaker is open (e.g. the Anthropic account
   * ran out of credits), then the offline engine, so the copilot keeps answering instead of erroring.
   */
  private get engine(): AIEngine {
    return this.primary === this.anthropic && Date.now() < this.liveDownUntil ? this.offline : this.primary;
  }

  /** Status for `GET /ai/health` — never includes the key. */
  health(): { engine: string; live: boolean; models: string; agentAmountLimitRub: number; degraded?: string } {
    const degraded = this.engine !== this.primary ? (this.liveDownReason ?? 'live engine unavailable') : undefined;
    return {
      engine: this.engine.label,
      live: this.engine.live,
      models: this.anthropic.available ? this.anthropic.describe() : 'offline-demo',
      agentAmountLimitRub: this.guardrails.amountLimitRub,
      ...(degraded ? { degraded } : {}),
    };
  }

  // ── POST /ai/chat (SSE) ──────────────────────────────────────────────────────

  /** Stream a chat turn over SSE. `send` writes one event; `signal` aborts on client disconnect. */
  async streamChat(req: ChatRequest, send: SSESend, signal?: AbortSignal): Promise<void> {
    const engine = this.engine;
    // Track whether anything reached the client: a live-engine failure before the first event can be
    // retried transparently on the offline engine; after that, the stream is already committed.
    let emitted = false;
    const upstream = send;
    send = (e) => {
      emitted = true;
      upstream(e);
    };
    const mode: AIMode = req.mode ?? 'support';
    const profileId = (req.profileId && req.profileId.trim()) || DEFAULT_PROFILE;
    const history = sanitizeHistory(req.messages);

    this.audit.record({
      event: 'chat_request',
      profileId,
      mode,
      promptChars: lastUserChars(history),
      outcome: `engine=${engine.label}`,
    });

    // No usable user turn → answer locally instead of sending an empty request to the live API (400).
    if (history.length === 0 || history[history.length - 1].role !== 'user') {
      send({ event: 'token', data: { text: 'Напишите вопрос — и я помогу с банковскими задачами: счета, карты, переводы, вклады, крипто.' } });
      send({ event: 'done', data: { stopReason: 'end', escalated: false } });
      return;
    }

    const system = buildSystemPrompt(mode, this.context.buildContextDigest(profileId));
    const tools = toolsForMode(mode);
    const messages: EngineMessage[] = history.map((m) => ({ role: m.role, content: m.content }));

    let escalated = false;

    try {
      for (let turn = 0; turn < MAX_TURNS; turn++) {
        if (signal?.aborted) return;

        const result = await engine.runTurn(
          { profileId, mode, system, messages, tools },
          (text) => send({ event: 'token', data: { text } }),
          signal,
        );
        escalated = escalated || !!result.escalated;

        if (result.toolCalls.length === 0) {
          send({ event: 'done', data: { stopReason: escalated ? 'escalated' : 'end', escalated } });
          return;
        }

        const actions = result.toolCalls.filter((c) => isActionTool(c.name));
        const readonly = result.toolCalls.filter((c) => isReadonlyTool(c.name));
        const unknown = result.toolCalls.filter((c) => !isActionTool(c.name) && !isReadonlyTool(c.name));

        // Action tools — only the action-capable modes (`agent` personal / `business` AI-бухгалтер),
        // and only the tools that mode is scoped to. Defence-in-depth: refuse anything out of scope.
        if (actions.length) {
          const actionCapable = mode === 'agent' || mode === 'business';
          // Per-tool scope: a business tool can't fire in agent mode, nor a personal tool in business.
          const allowed = actions.filter((c) => isActionToolForMode(c.name, mode));
          const outOfScope = actions.filter((c) => !isActionToolForMode(c.name, mode));
          for (const call of outOfScope) {
            this.audit.record({ event: 'refused', profileId, mode, tool: call.name, outcome: `action out of scope for ${mode} mode` });
          }
          if (!actionCapable || allowed.length === 0) {
            send({
              event: 'token',
              data: {
                text:
                  mode === 'business'
                    ? 'Это действие сейчас недоступно в бизнес-режиме. Я могу выставить счёт или подготовить оплату поставщику — с подтверждением биометрией.'
                    : 'Это действие доступно только в режиме «Агент» (личный) или «AI-бухгалтер» (бизнес). Переключитесь — и я подготовлю черновик с подтверждением.',
              },
            });
            send({ event: 'done', data: { stopReason: 'end', escalated } });
            return;
          }
          for (const call of allowed) {
            const draft = await this.buildActionDraft(call, profileId);
            send({ event: 'toolDraft', data: draft });
            this.audit.record({
              event: 'tool_draft',
              profileId,
              mode,
              tool: draft.tool,
              amount: draft.amount,
              currency: draft.currency,
              outcome: draft.blocked ? `blocked: ${draft.blockReason ?? 'guardrail'}` : 'draft issued',
            });
          }
          // An action call short-circuits the turn (the AI proposes, never executes). If the model
          // also batched read-only calls this turn, they're not run — record that for the audit trail.
          if (readonly.length || unknown.length) {
            this.audit.record({ event: 'tool_readonly', profileId, mode, tool: [...readonly, ...unknown].map((c) => c.name).join(','), outcome: 'dropped (action turn)' });
          }
          send({ event: 'done', data: { stopReason: 'tool_draft', escalated } });
          return;
        }

        // Read-only tools: execute server-side, feed results back, continue the loop.
        messages.push({ role: 'assistant', content: result.assistantContent });
        const toolResults: unknown[] = [];
        for (const call of readonly) {
          const { content, isEscalation } = this.runReadonly(call, profileId);
          escalated = escalated || isEscalation;
          this.audit.record({
            event: isEscalation ? 'escalation' : 'tool_readonly',
            profileId,
            mode,
            tool: call.name,
          });
          toolResults.push({ type: 'tool_result', tool_use_id: call.id, content });
        }
        for (const call of unknown) {
          this.audit.record({ event: 'refused', profileId, mode, tool: call.name, outcome: 'unknown tool' });
          toolResults.push({ type: 'tool_result', tool_use_id: call.id, content: 'Неизвестный инструмент.', is_error: true });
        }
        messages.push({ role: 'user', content: toolResults });
      }

      // Loop budget exhausted — close cleanly.
      send({ event: 'done', data: { stopReason: 'end', escalated } });
    } catch (err) {
      if (signal?.aborted) return; // client hung up — not an error worth surfacing
      if (engine === this.anthropic && !emitted) {
        this.tripLiveBreaker(err);
        this.audit.record({ event: 'error', profileId, mode, outcome: `${errorClass(err)} → offline fallback` });
        return this.streamChat(req, upstream, signal);
      }
      this.logger.error(`chat turn failed: ${(err as Error).message}`);
      this.audit.record({ event: 'error', profileId, mode, outcome: errorClass(err) });
      send({ event: 'token', data: { text: 'Извините, AI-сервис временно недоступен. Попробуйте позже или подключите оператора.' } });
      send({ event: 'done', data: { stopReason: 'error', escalated } });
    }
  }

  /**
   * Open the live-engine breaker after a failure. Account-level errors (no credits, bad key, no
   * access) won't fix themselves in seconds, so they back off longer than transient ones.
   */
  private tripLiveBreaker(err: unknown): void {
    const message = (err as Error)?.message ?? String(err);
    const status = (err as { status?: number })?.status;
    const accountLevel = status === 401 || status === 403 || /credit balance|billing|api key/i.test(message);
    const minutes = accountLevel ? 30 : 5;
    this.liveDownUntil = Date.now() + minutes * 60_000;
    this.liveDownReason = accountLevel ? 'anthropic account unavailable (credits/key)' : 'anthropic unreachable';
    this.logger.warn(`live engine failed (${message.slice(0, 160)}); offline engine for ${minutes} min`);
  }

  // ── POST /ai/confirm-action ──────────────────────────────────────────────────

  /**
   * Execute a confirmed action draft (after biometrics on the client). Re-verifies the server
   * signature + guardrails, then runs a SIMULATION (no real ledger movement — demo). Audited.
   */
  confirmAction(req: ConfirmActionRequest): ConfirmActionResult {
    const draft = req?.draft;
    const profileId = (req?.profileId && req.profileId.trim()) || DEFAULT_PROFILE;

    if (!draft || !isActionTool(draft.tool)) {
      this.audit.record({ event: 'action_rejected', profileId, tool: draft?.tool, outcome: 'invalid draft' });
      return { status: 'rejected', tool: (draft?.tool ?? 'make_transfer') as ActionTool, message: 'Действие отклонено.', reason: 'Некорректный черновик действия.' };
    }

    // Signature binds the draft to its owning profile — a draft issued for another profile won't verify.
    const verdict = this.guardrails.verifyDraft(draft, profileId);
    if (!verdict.ok) {
      this.audit.record({
        event: 'action_rejected',
        profileId,
        tool: draft.tool,
        amount: draft.amount,
        currency: draft.currency,
        outcome: verdict.reason,
      });
      return { status: 'rejected', tool: draft.tool, message: 'Действие отклонено.', reason: verdict.reason };
    }

    // Replay protection: a draft is single-use within its TTL.
    if (!this.guardrails.consume(draft.draftId, draft.expiresAt)) {
      this.audit.record({ event: 'action_rejected', profileId, tool: draft.tool, amount: draft.amount, currency: draft.currency, outcome: 'draft already used' });
      return { status: 'rejected', tool: draft.tool, message: 'Действие отклонено.', reason: 'Этот черновик уже был подтверждён.' };
    }

    const sim = this.simulate(draft, profileId);
    this.audit.record({
      event: 'action_confirmed',
      profileId,
      tool: draft.tool,
      amount: draft.amount,
      currency: draft.currency,
      outcome: 'executed (simulated)',
    });
    return { status: 'executed', tool: draft.tool, message: sim.message, result: sim.entity };
  }

  // ── Drafts + read-only execution + simulation ────────────────────────────────

  /** Turn an action tool call into a signed (possibly blocked) draft. Guardrails applied here. */
  private async buildActionDraft(call: ToolCall, profileId: string): Promise<ToolDraft> {
    const tool = call.name as ActionTool;
    const input = call.input ?? {};

    if (tool === 'make_transfer') {
      const to = String(input.to ?? 'контакт');
      const amount = toNumber(input.amount);
      const currency = String(input.currency ?? 'RUB').toUpperCase();
      // The limit is in ₽: convert non-RUB amounts before checking, so a crypto/FX amount can't slip
      // a huge transfer under the nominal ceiling. Unconvertible currency → blocked (needs a human).
      const amountRub = await this.amountToRub(amount, currency);
      const summary = `Перевод ${fmt(amount)} ${currency} получателю «${to}»`;
      return this.guardrails.buildDraft({ tool, summary, args: { to, amount, currency }, profileId, amount, currency, amountRub });
    }

    if (tool === 'open_deposit') {
      const amount = toNumber(input.amount);
      const type = input.type === 'stake' ? 'stake' : 'ruble';
      const term = input.term != null ? toNumber(input.term) : 6;
      const args = type === 'stake' ? { amount, type } : { amount, term, type };
      const summary = type === 'stake' ? `Крипто-стейк на ${fmt(amount)} ₽` : `Рублёвый вклад ${fmt(amount)} ₽ на ${term} мес.`;
      // open_deposit has no currency arg → the amount is a ₽ figure by contract.
      return this.guardrails.buildDraft({ tool, summary, args, profileId, amount, currency: 'RUB', amountRub: amount });
    }

    if (tool === 'create_invoice') {
      // Business (§8.2): issue a receivable. No money leaves the company → exempt from the outbound
      // amount limit (a 1.2M ₽ invoice is normal), but the amount is still shown + signed.
      const counterparty = String(input.counterparty ?? 'контрагент');
      const amount = toNumber(input.amount);
      const dueDays = input.dueDays != null ? toNumber(input.dueDays) : 7;
      const desc = input.description != null ? String(input.description).trim() : '';
      const summary = `Счёт на ${fmt(amount)} ₽ для «${counterparty}»${desc ? ` — ${desc}` : ''} · оплата в течение ${dueDays} дн.`;
      const args: Record<string, unknown> = { counterparty, amount, dueDays };
      if (desc) args.description = desc;
      return this.guardrails.buildDraft({ tool, summary, args, profileId, amount, currency: 'RUB', amountRub: amount, limitExempt: true });
    }

    if (tool === 'pay_supplier') {
      // Business (§8.2): outbound payment to a counterparty → amount-limited in ₽ exactly like a
      // transfer (a large payment is surfaced but blocked, routed to operator / 2-of-N signature).
      const supplier = String(input.supplier ?? 'поставщик');
      const amount = toNumber(input.amount);
      const invoiceId = input.invoiceId != null ? String(input.invoiceId).trim() : '';
      const desc = input.description != null ? String(input.description).trim() : '';
      const summary = `Оплата поставщику «${supplier}» на ${fmt(amount)} ₽${invoiceId ? ` по счёту ${invoiceId}` : ''}`;
      const args: Record<string, unknown> = { supplier, amount };
      if (invoiceId) args.invoiceId = invoiceId;
      if (desc) args.description = desc;
      return this.guardrails.buildDraft({ tool, summary, args, profileId, amount, currency: 'RUB', amountRub: amount });
    }

    // freeze_card — no amount, never blocked by the amount limit.
    const card = this.context.defaultCard(profileId);
    const cardId = String(input.cardId ?? card?.id ?? 'card-virt');
    const last4 = card && card.id === cardId ? card.last4 : undefined;
    const summary = `Заморозка карты${last4 ? ` ··${last4}` : ''}`;
    return this.guardrails.buildDraft({ tool: 'freeze_card', summary, args: { cardId }, profileId });
  }

  /**
   * RUB-equivalent of `amount` in `currency` for the agent amount limit. RUB → itself; USD → CBR fix
   * (`pricing.getFxRate`); a tradable asset (BTC/ETH/USDT/…) → its live ₽ price (`pricing.getPrices`);
   * anything else (e.g. EUR) → `null`, which the guardrail treats as "block, needs a human". Reuses the
   * Pricing service so there are no hard-coded rates.
   */
  private async amountToRub(amount: number, currency: string): Promise<number | null> {
    if (!Number.isFinite(amount)) return amount; // NaN flows through → guardrail blocks
    const cur = (currency || 'RUB').toUpperCase();
    if (cur === 'RUB') return amount;
    try {
      if (cur === 'USD') {
        const fx = this.pricing.getFxRate();
        return fx?.usdRub ? amount * fx.usdRub : null;
      }
      const ticks = await this.pricing.getPrices([cur]);
      const tick = ticks.find((t) => t.asset === cur);
      return tick?.price ? amount * tick.price : null;
    } catch (err) {
      this.logger.warn(`amountToRub(${cur}) failed: ${(err as Error).message}`);
      return null;
    }
  }

  /** Run a read-only tool and return its tool_result content (+ escalation flag). */
  private runReadonly(call: ToolCall, profileId: string): { content: string; isEscalation: boolean } {
    const input = call.input ?? {};
    switch (call.name) {
      case 'get_balance':
        return {
          content: JSON.stringify({
            accounts: this.context.accounts(profileId).map((a) => ({ type: a.type, currency: a.currency, balance: a.balance })),
          }),
          isEscalation: false,
        };
      case 'explain_transaction': {
        const tx = this.context.transaction(profileId, input.transactionId ? String(input.transactionId) : undefined);
        return { content: JSON.stringify({ transaction: tx ?? null }), isEscalation: false };
      }
      case 'search_kb':
        return { content: JSON.stringify({ results: this.kb.search(String(input.query ?? '')) }), isEscalation: false };
      case 'escalate_to_human':
        return {
          content: JSON.stringify({ status: 'escalated', ticket: `SUP-${randomUUID().slice(0, 8).toUpperCase()}`, note: 'Оператор подключится в чате.' }),
          isEscalation: true,
        };
      default:
        return { content: 'Неизвестный инструмент.', isEscalation: false };
    }
  }

  /** Simulate a confirmed action (no real money moves — feature-local mock, like the rest of §14). */
  private simulate(draft: ToolDraft, profileId: string): { message: string; entity: Record<string, unknown> } {
    const now = new Date().toISOString();
    const p = draft.params;

    if (draft.tool === 'make_transfer') {
      const id = `TX-${shortId()}`;
      const amount = num(draft.amount);
      const currency = draft.currency ?? 'RUB';
      return {
        message: `Перевод ${fmt(amount)} ${currency} получателю «${String(p.to ?? 'контакт')}» выполнен · ${id}`,
        entity: { id, profileId, kind: 'transfer', status: 'completed', amount, currency, counterparty: p.to ?? null, fee: 0, createdAt: now },
      };
    }

    if (draft.tool === 'open_deposit') {
      const id = `DEP-${shortId()}`;
      const amount = num(draft.amount);
      const isStake = p.type === 'stake';
      return {
        message: `Открыт ${isStake ? 'крипто-стейк' : 'вклад'} на ${fmt(amount)} ₽ · ${id}`,
        entity: { id, profileId, kind: isStake ? 'stake' : 'ruble', principal: amount, rateApy: isStake ? 8.2 : 18.5, term: p.term ?? null, asset: isStake ? 'USDT' : null, lockUntil: null, createdAt: now },
      };
    }

    if (draft.tool === 'create_invoice') {
      const id = `INV-${shortId()}`;
      const amount = num(draft.amount);
      const counterparty = String(p.counterparty ?? 'контрагент');
      return {
        message: `Счёт ${id} на ${fmt(amount)} ₽ для «${counterparty}» выставлен и отправлен`,
        entity: { id, profileId, kind: 'invoice', status: 'sent', amount, currency: 'RUB', counterparty, dueDays: p.dueDays ?? 7, createdAt: now },
      };
    }

    if (draft.tool === 'pay_supplier') {
      const id = `PAY-${shortId()}`;
      const amount = num(draft.amount);
      const supplier = String(p.supplier ?? 'поставщик');
      return {
        message: `Оплата поставщику «${supplier}» на ${fmt(amount)} ₽ отправлена · ${id}`,
        entity: { id, profileId, kind: 'supplier_payment', status: 'completed', amount, currency: 'RUB', counterparty: supplier, invoiceId: p.invoiceId ?? null, createdAt: now },
      };
    }

    // freeze_card
    const cardId = String(p.cardId ?? 'card-virt');
    return { message: `Карта заморожена · ${cardId}`, entity: { cardId, profileId, state: 'frozen', frozenAt: now } };
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Keep only valid user/assistant string turns (drop anything malformed from the client). */
function sanitizeHistory(messages: ChatRequest['messages']): { role: 'user' | 'assistant'; content: string }[] {
  if (!Array.isArray(messages)) return [];
  return messages
    .filter((m) => m && (m.role === 'user' || m.role === 'assistant') && typeof m.content === 'string' && m.content.length > 0)
    .map((m) => ({ role: m.role, content: m.content }));
}

function lastUserChars(history: { role: string; content: string }[]): number {
  for (let i = history.length - 1; i >= 0; i--) {
    if (history[i].role === 'user') return history[i].content.length;
  }
  return 0;
}

function toNumber(v: unknown): number {
  if (typeof v === 'number') return v;
  if (typeof v === 'string') return Number(v.replace(/[\s ]/g, '').replace(',', '.'));
  return NaN;
}

function num(v: number | null | undefined): number {
  return typeof v === 'number' && Number.isFinite(v) ? v : 0;
}

function shortId(): string {
  return randomUUID().slice(0, 8).toUpperCase();
}

function fmt(n: number): string {
  return Number.isFinite(n) ? new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 2 }).format(n) : '—';
}

function errorClass(err: unknown): string {
  const name = (err as { name?: string })?.name ?? 'Error';
  const status = (err as { status?: number })?.status;
  return status ? `${name}:${status}` : name;
}
