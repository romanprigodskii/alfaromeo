import { AIMode } from './ai.types';
import { ToolDef } from './ai.tools';

/**
 * Engine abstraction (§11.7). The orchestration loop in `ai.service.ts` is engine-agnostic: it runs
 * one model turn, streams the text tokens, and inspects the returned tool calls — applying guardrails,
 * drafts, and audit identically regardless of which engine produced them.
 *
 * Two implementations:
 *  - `AnthropicEngine` — the real Claude Messages API (used whenever `ANTHROPIC_API_KEY` is set).
 *  - `OfflineEngine` — a deterministic heuristic fallback (no key, or Anthropic unreachable) so the
 *    SSE / draft / guardrail / audit pipeline is fully demonstrable offline. Clearly labelled.
 */

/** A tool call the model wants to make this turn. */
export interface ToolCall {
  id: string;
  name: string;
  input: Record<string, unknown>;
}

/** One conversation entry. `content` is a plain string OR provider content blocks (tool loop). */
export interface EngineMessage {
  role: 'user' | 'assistant';
  content: unknown;
}

export interface EngineTurnParams {
  profileId: string;
  mode: AIMode;
  system: string;
  messages: EngineMessage[];
  tools: ToolDef[];
}

export interface TurnResult {
  /** Tool calls the model requested (empty ⇒ it produced a final text answer). */
  toolCalls: ToolCall[];
  /** Raw assistant content to push back into history before tool results (read-only loop). */
  assistantContent: unknown;
  /** Provider stop reason, when known. */
  stopReason: string | null;
  /** Set by an engine that itself handled a human-escalation (the offline engine does). */
  escalated?: boolean;
}

export interface AIEngine {
  /** Short label for logs / audit / `GET /ai/health` (`anthropic` | `offline`). */
  readonly label: string;
  /** Whether this is the real model (vs the offline fallback). */
  readonly live: boolean;
  /** Run one model turn. `onToken` receives text fragments as they stream. */
  runTurn(params: EngineTurnParams, onToken: (t: string) => void, signal?: AbortSignal): Promise<TurnResult>;
}
