/**
 * AI-orchestration DTOs and the SSE wire format (§11.7).
 *
 * The SSE event names (`token` / `toolDraft` / `done`) map 1:1 onto the iOS `AIStreamEvent` enum
 * (`Networking/AIStreamClient.swift`): `.token(String)` / `.toolDraft(name:summary:)` / `.done`.
 * Extra fields on a `toolDraft` (signature, params, amount…) are ignored by today's iOS decoder but
 * carry everything the confirm-card + `POST /ai/confirm-action` step needs later.
 */

/** Copilot mode (§10.9 / §8.2). `support` = FAQ/operations + escalation; `coach` = proactive advice;
 *  `agent` = personal tool-use that PROPOSES financial actions (drafts only, never executes);
 *  `business` = the AI-бухгалтер (§8.2) — business-context coach + agentic invoice/supplier-payment
 *  drafts. Like `agent`, business action tools only ever produce a signed draft the user confirms. */
export type AIMode = 'support' | 'coach' | 'agent' | 'business';

export const AI_MODES: readonly AIMode[] = ['support', 'coach', 'agent', 'business'];

/** One turn of conversation history. Only `user` / `assistant` — the system prompt is server-built. */
export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

/** `POST /ai/chat` body. `mode` defaults to `support`. */
export interface ChatRequest {
  profileId: string;
  mode?: AIMode;
  messages: ChatMessage[];
}

/** Confirmation-required action tools (§11.7 / §8.2). Drafts only — the AI never moves money.
 *  Personal: `make_transfer` / `open_deposit` / `freeze_card`. Business (§8.2): `create_invoice`
 *  (issue a receivable) / `pay_supplier` (pay a counterparty). All flow through the same signed-draft
 *  + biometric-confirm path. */
export type ActionTool =
  | 'make_transfer'
  | 'open_deposit'
  | 'freeze_card'
  | 'create_invoice'
  | 'pay_supplier';

/**
 * A proposed-but-unexecuted financial action. The client renders it as a confirm card, collects
 * biometrics, then echoes it (with `signature`) to `POST /ai/confirm-action` for the server to run a
 * simulation. `signature` is a server HMAC binding the draft so a client cannot fabricate an action
 * the AI never proposed (AI-proposes → client-confirms → server-verifies-it-was-genuine).
 */
export interface ToolDraft {
  draftId: string;
  tool: ActionTool;
  /** Alias of `tool` — matches the iOS `.toolDraft(name:summary:)` case. NOT part of the signature. */
  name?: string;
  /** Human-readable, PII-light one-liner shown on the confirm card. */
  summary: string;
  /** Validated tool arguments (e.g. `{ to, amount, currency }`). */
  params: Record<string, unknown>;
  amount?: number | null;
  currency?: string | null;
  /** Always true for action drafts — the client must gate execution behind Face ID / Touch ID. */
  requiresBiometric: true;
  /** A guardrail tripped (e.g. amount over the AI limit): show the card but block execution. */
  blocked: boolean;
  blockReason?: string | null;
  /** HMAC-SHA256 over the canonical draft payload (see `ai.guardrails.ts`). */
  signature: string;
  /** ISO-8601; the draft is rejected by confirm-action after this instant. */
  expiresAt: string;
}

/** `POST /ai/confirm-action` body — the draft the client received, verbatim, after biometrics. */
export interface ConfirmActionRequest {
  profileId: string;
  draft: ToolDraft;
}

/** Result of a confirmed action's simulation (`POST /ai/confirm-action` response). */
export interface ConfirmActionResult {
  status: 'executed' | 'rejected';
  tool: ActionTool;
  /** A short receipt for the UI (e.g. «Перевод 5 000 ₽ выполнен · TX-…»). */
  message: string;
  /** The simulated entity produced (Transaction / Deposit / Card), shape depends on `tool`. */
  result?: Record<string, unknown> | null;
  reason?: string | null;
}

// ── SSE event payloads ───────────────────────────────────────────────────────
// Emitted as `event: <name>\ndata: <json>\n\n`. Names match the iOS enum cases.

/** `event: token` — one streamed text fragment. */
export interface TokenEvent {
  text: string;
}

/** `event: done` — terminal event. `stopReason` lets a client distinguish a clean end, a drafted
 *  action, an escalation handoff, or an error (iOS just treats all of them as `.done`). */
export interface DoneEvent {
  stopReason: 'end' | 'tool_draft' | 'escalated' | 'error';
  escalated: boolean;
}

/** What a chat run emits to the SSE writer. `toolDraft` reuses the `ToolDraft` shape above. */
export type SSEEvent =
  | { event: 'token'; data: TokenEvent }
  | { event: 'toolDraft'; data: ToolDraft }
  | { event: 'done'; data: DoneEvent };

/** The SSE writer the controller hands to the service (one per HTTP connection). */
export type SSESend = (event: SSEEvent) => void;
