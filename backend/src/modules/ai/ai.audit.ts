import { Injectable, Logger } from '@nestjs/common';
import { AIMode } from './ai.types';

/**
 * Audit trail for every AI request and agentic action (§11.7, §11.8).
 *
 * Records only **metadata** — never the raw conversation, never PII, never the API key or a draft
 * signature. Message text is reduced to a length; amounts/tools/outcomes are kept because auditing
 * agent actions is the whole point. In-memory ring buffer for the demo (swap for an append-only
 * store later); each entry is also logged so it shows up in the server log without secrets.
 */

export type AuditEvent =
  | 'chat_request'
  | 'tool_draft'
  | 'tool_readonly'
  | 'action_confirmed'
  | 'action_rejected'
  | 'refused'
  | 'escalation'
  | 'error';

export interface AuditEntry {
  ts: string;
  event: AuditEvent;
  profileId: string;
  mode?: AIMode;
  tool?: string;
  amount?: number | null;
  currency?: string | null;
  /** Short, non-sensitive outcome note (e.g. «blocked: over limit», «draft issued»). */
  outcome?: string;
  /** Length of the user prompt — proxy for "a message happened" without storing its content. */
  promptChars?: number;
}

@Injectable()
export class AiAuditService {
  private readonly logger = new Logger('AiAudit');
  private readonly buffer: AuditEntry[] = [];
  private readonly capacity = 500;

  /** `now` is injected (no `Date.now()` inside, keeps callers testable) — but defaults to real time. */
  record(entry: Omit<AuditEntry, 'ts'>, now: Date = new Date()): void {
    const full: AuditEntry = { ts: now.toISOString(), ...redact(entry) };
    this.buffer.push(full);
    if (this.buffer.length > this.capacity) this.buffer.shift();

    const bits = [full.event, `profile=${full.profileId}`];
    if (full.mode) bits.push(`mode=${full.mode}`);
    if (full.tool) bits.push(`tool=${full.tool}`);
    if (full.amount != null) bits.push(`amount=${full.amount}${full.currency ?? ''}`);
    if (full.outcome) bits.push(full.outcome);
    this.logger.log(bits.join(' · '));
  }

  /** Recent entries (newest first), optionally filtered by profile — for `GET /ai/audit` (demo). */
  recent(profileId?: string, limit = 100): AuditEntry[] {
    const list = profileId ? this.buffer.filter((e) => e.profileId === profileId) : this.buffer;
    return list.slice(-limit).reverse();
  }
}

/** Defensive scrub: drop anything that smells like free-form content; keep only known-safe fields. */
function redact(entry: Omit<AuditEntry, 'ts'>): Omit<AuditEntry, 'ts'> {
  return {
    event: entry.event,
    profileId: entry.profileId,
    mode: entry.mode,
    tool: entry.tool,
    amount: entry.amount ?? null,
    currency: entry.currency ?? null,
    outcome: entry.outcome ? entry.outcome.slice(0, 120) : undefined,
    promptChars: entry.promptChars,
  };
}
