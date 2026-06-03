import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Anthropic from '@anthropic-ai/sdk';
import { AIEngine, EngineTurnParams, ToolCall, TurnResult } from './ai.engine';
import { AIMode } from './ai.types';

/**
 * Real Claude engine — Anthropic Messages API via the official SDK (§11.7). The API key is read from
 * config (env only) and is NEVER logged. Streams text deltas as they arrive, then resolves the turn's
 * tool calls from the final message so the orchestration loop can apply guardrails / build drafts.
 *
 * Model is configurable (`AI_MODEL` for fast/FAQ, `AI_MODEL_STRONG` for coach/agent) — "модель под
 * задачу" (§11.7).
 */
@Injectable()
export class AnthropicEngine implements AIEngine {
  readonly label = 'anthropic';
  readonly live = true;

  private readonly logger = new Logger('AnthropicEngine');
  private readonly client?: Anthropic;
  private readonly modelFast: string;
  private readonly modelStrong: string;
  private readonly maxTokens: number;

  constructor(config: ConfigService) {
    const apiKey = config.get<string>('ai.apiKey') ?? '';
    // Construct the client only when a key is present. The key never leaves this constructor / SDK.
    this.client = apiKey ? new Anthropic({ apiKey }) : undefined;
    this.modelFast = config.get<string>('ai.model') ?? 'claude-sonnet-4-5';
    this.modelStrong = config.get<string>('ai.modelStrong') || this.modelFast;
    this.maxTokens = config.get<number>('ai.maxTokens') ?? 1024;
  }

  /** True when an API key is configured — the service uses this to pick the live vs offline engine. */
  get available(): boolean {
    return this.client != null;
  }

  /** Log-safe model summary (no key). */
  describe(): string {
    return `fast=${this.modelFast} strong=${this.modelStrong} max_tokens=${this.maxTokens}`;
  }

  async runTurn(
    params: EngineTurnParams,
    onToken: (t: string) => void,
    signal?: AbortSignal,
  ): Promise<TurnResult> {
    if (!this.client) throw new Error('Anthropic client not configured');

    const stream = this.client.messages.stream(
      {
        model: this.modelFor(params.mode),
        max_tokens: this.maxTokens,
        system: params.system,
        // Content is either a plain string or provider content blocks (tool-result turns).
        messages: params.messages as Anthropic.MessageParam[],
        tools: params.tools as Anthropic.Tool[],
      },
      { signal },
    );

    for await (const event of stream) {
      if (event.type === 'content_block_delta' && event.delta.type === 'text_delta') {
        onToken(event.delta.text);
      }
    }

    const final = await stream.finalMessage();
    const toolCalls: ToolCall[] = final.content
      .filter((b): b is Anthropic.ToolUseBlock => b.type === 'tool_use')
      .map((b) => ({ id: b.id, name: b.name, input: (b.input ?? {}) as Record<string, unknown> }));

    return {
      toolCalls,
      assistantContent: final.content,
      stopReason: final.stop_reason ?? null,
    };
  }

  private modelFor(mode: AIMode): string {
    // FAQ/support → fast; coach & agent → stronger reasoning.
    return mode === 'support' ? this.modelFast : this.modelStrong;
  }
}
