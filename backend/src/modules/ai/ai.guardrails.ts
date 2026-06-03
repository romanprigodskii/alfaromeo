import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac, randomBytes, randomUUID, timingSafeEqual } from 'node:crypto';
import { ActionTool, ToolDraft } from './ai.types';

/**
 * Agentic-action guardrails (§11.7).
 *
 * Protections here:
 *  1. **Amount limits** — an action whose ₽-equivalent amount exceeds `ai.agentMaxAmountRub` is still
 *     surfaced as a draft (so the user sees the suggestion) but marked `blocked`; confirm-action
 *     refuses to run it. The limit is checked against a **RUB-equivalent** the caller computes, so a
 *     non-RUB currency can't sneak a huge transfer under the nominal ceiling.
 *  2. **Draft signing** — every draft is HMAC-signed over an explicit field set **plus the owning
 *     profileId**. `confirm-action` re-derives the signature from the echoed draft + the request's
 *     profileId, so a client cannot fabricate a draft, tamper its fields, or confirm one profile's
 *     draft against another profile. (AI proposes → client confirms → server verifies authenticity.)
 *  3. **Replay protection** — a draftId is single-use: once confirmed it cannot be confirmed again
 *     within its TTL.
 *
 * The HMAC secret comes from `AI_DRAFT_SECRET`; if unset, a random per-process secret is generated
 * (drafts then don't survive a restart / multiple instances — logged, mirrors the FX-fallback pattern).
 */
@Injectable()
export class AiGuardrails {
  private readonly logger = new Logger('AiGuardrails');
  private readonly secret: Buffer;
  private readonly maxAmountRub: number;
  private readonly ttlSec: number;
  /** Single-use ledger: draftId → expiry(ms). Pruned lazily. In-memory for the demo. */
  private readonly consumed = new Map<string, number>();

  constructor(config: ConfigService) {
    const configured = config.get<string>('ai.draftSecret');
    if (configured && configured.trim()) {
      this.secret = Buffer.from(configured, 'utf8');
    } else {
      this.secret = randomBytes(32);
      this.logger.warn(
        'AI_DRAFT_SECRET not set — using a random per-process secret. Action drafts will not verify ' +
          'across a restart or a second instance. Set AI_DRAFT_SECRET for stable confirm-action.',
      );
    }
    this.maxAmountRub = config.get<number>('ai.agentMaxAmountRub') ?? 100000;
    this.ttlSec = config.get<number>('ai.draftTtlSec') ?? 600;
  }

  get amountLimitRub(): number {
    return this.maxAmountRub;
  }

  /**
   * Amount-limit decision. `amount` is the displayed amount (any currency, may be undefined for a
   * no-amount action like freeze_card); `amountRub` is its RUB-equivalent computed by the caller.
   * Any amount-bearing action without a usable RUB-equivalent is blocked (conservative — needs a human).
   */
  evaluateLimit(amount?: number | null, amountRub?: number | null): { blocked: boolean; reason?: string } {
    if (amount == null) return { blocked: false }; // no-amount action (e.g. freeze_card)
    if (amountRub == null || !Number.isFinite(amountRub)) {
      return { blocked: true, reason: 'Не удалось пересчитать сумму в рубли для проверки лимита — требуется оператор.' };
    }
    if (amountRub <= 0) return { blocked: true, reason: 'Некорректная сумма.' };
    if (amountRub > this.maxAmountRub) {
      const suffix = amount != null && Number.isFinite(amount) && amountRub !== amount ? ` (≈${fmt(amountRub)} ₽)` : '';
      return { blocked: true, reason: `Сумма${suffix} превышает лимит AI-агента (${fmt(this.maxAmountRub)} ₽). Нужно подтверждение оператора.` };
    }
    return { blocked: false };
  }

  /** Build a signed, possibly-blocked action draft bound to `profileId`. */
  buildDraft(params: {
    tool: ActionTool;
    summary: string;
    args: Record<string, unknown>;
    profileId: string;
    amount?: number | null;
    currency?: string | null;
    /** RUB-equivalent of `amount` for the limit check (== amount when currency is RUB). */
    amountRub?: number | null;
    /** Skip the outbound amount-limit (e.g. create_invoice — issuing a receivable moves no money out,
     *  so a large invoice must not be blocked). The amount is still shown + signed. */
    limitExempt?: boolean;
    now?: Date;
  }): ToolDraft {
    const now = params.now ?? new Date();
    const { blocked, reason } = params.limitExempt
      ? { blocked: false, reason: undefined as string | undefined }
      : this.evaluateLimit(params.amount, params.amountRub);
    const expiresAt = new Date(now.getTime() + this.ttlSec * 1000).toISOString();

    const core = {
      draftId: randomUUID(),
      tool: params.tool,
      summary: params.summary,
      params: params.args,
      amount: params.amount ?? null,
      currency: params.currency ?? null,
      requiresBiometric: true as const,
      blocked,
      blockReason: reason ?? null,
      expiresAt,
    };
    const signature = this.sign(this.signedPayload(core, params.profileId));
    // `name` is an unsigned alias for the iOS decoder — excluded from `signedPayload`, so it's safe.
    return { ...core, name: core.tool, signature };
  }

  /**
   * Verify a draft echoed back by the client for `profileId`: authentic signature (binding tool, params,
   * amount, blocked, expiry AND the owning profile), not expired, not blocked. Returns `{ ok:false }`
   * with a reason on any failure.
   */
  verifyDraft(draft: ToolDraft, profileId: string, now: Date = new Date()): { ok: boolean; reason?: string } {
    if (!draft || typeof draft.signature !== 'string' || draft.signature.length === 0) {
      return { ok: false, reason: 'Черновик без подписи.' };
    }
    const expected = this.sign(this.signedPayload(draft, profileId));
    if (!safeEqualHex(draft.signature, expected)) {
      return { ok: false, reason: 'Подпись черновика недействительна (или другой профиль) — действие не подтверждено AI.' };
    }
    if (!draft.expiresAt || new Date(draft.expiresAt).getTime() < now.getTime()) {
      return { ok: false, reason: 'Срок действия черновика истёк. Попросите AI подготовить заново.' };
    }
    if (draft.blocked) {
      return { ok: false, reason: draft.blockReason ?? 'Действие заблокировано гардрейлами.' };
    }
    return { ok: true };
  }

  /**
   * Atomically claim a draftId for execution (replay protection). Returns false if it was already
   * confirmed (within TTL). Call AFTER `verifyDraft` succeeds and BEFORE running the action.
   */
  consume(draftId: string, expiresAtIso: string, now: Date = new Date()): boolean {
    const nowMs = now.getTime();
    this.prune(nowMs);
    if (!draftId || this.consumed.has(draftId)) return false;
    const exp = new Date(expiresAtIso).getTime();
    this.consumed.set(draftId, Number.isFinite(exp) ? exp : nowMs + this.ttlSec * 1000);
    return true;
  }

  // ── HMAC ───────────────────────────────────────────────────────────────────

  /** Explicit, deterministic field set that the signature covers (binds the action + its profile). */
  private signedPayload(d: Partial<ToolDraft>, profileId: string): Record<string, unknown> {
    return {
      draftId: d.draftId,
      tool: d.tool,
      summary: d.summary,
      params: d.params ?? {},
      amount: d.amount ?? null,
      currency: d.currency ?? null,
      requiresBiometric: true,
      blocked: d.blocked ?? false,
      blockReason: d.blockReason ?? null,
      expiresAt: d.expiresAt,
      profileId,
    };
  }

  private sign(payload: Record<string, unknown>): string {
    return createHmac('sha256', this.secret).update(canonical(payload)).digest('hex');
  }

  private prune(nowMs: number): void {
    for (const [id, exp] of this.consumed) {
      if (exp < nowMs) this.consumed.delete(id);
    }
  }
}

/** Deterministic JSON with recursively sorted keys, so signing is independent of property order. */
function canonical(value: unknown): string {
  return JSON.stringify(sortKeys(value));
}

function sortKeys(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value && typeof value === 'object') {
    const obj = value as Record<string, unknown>;
    return Object.keys(obj)
      .sort()
      .reduce<Record<string, unknown>>((acc, k) => {
        acc[k] = sortKeys(obj[k]);
        return acc;
      }, {});
  }
  return value;
}

/** Constant-time compare of two hex strings (avoids leaking signature bytes via timing). */
function safeEqualHex(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  try {
    return timingSafeEqual(Buffer.from(a, 'hex'), Buffer.from(b, 'hex'));
  } catch {
    return false;
  }
}

function fmt(n: number): string {
  return new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 0 }).format(n);
}
