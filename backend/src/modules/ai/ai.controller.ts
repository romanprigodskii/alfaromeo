import { Body, Controller, Get, Post, Query, Res } from '@nestjs/common';
import { Response } from 'express';
import { AiService } from './ai.service';
import { AiAuditService } from './ai.audit';
import { ChatRequest, ConfirmActionRequest, SSEEvent } from './ai.types';

/**
 * AI-orchestration endpoints (§11.7). The client talks ONLY to us — never to Anthropic directly
 * (same rule as prices). The key lives on the backend; nothing here echoes it.
 *
 *  - `POST /ai/chat`            → Server-Sent Events (`token` / `toolDraft` / `done`), iOS-compatible.
 *  - `POST /ai/confirm-action`  → execute a biometric-confirmed draft (server-verified, simulated).
 *  - `GET  /ai/health`          → engine + model summary (no secrets).
 *  - `GET  /ai/audit`           → redacted audit trail (demo/inspection).
 */
@Controller('ai')
export class AiController {
  constructor(
    private readonly ai: AiService,
    private readonly audit: AiAuditService,
  ) {}

  @Get('health')
  health() {
    return this.ai.health();
  }

  /**
   * Stream a copilot turn as SSE. We take the raw Express `Response` (so Nest doesn't buffer/serialize)
   * and write `event:`/`data:` frames ourselves; an `AbortController` tied to the socket stops the
   * upstream model call if the client hangs up.
   */
  @Post('chat')
  async chat(@Body() body: ChatRequest, @Res() res: Response): Promise<void> {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no'); // don't let nginx buffer the stream
    res.flushHeaders?.();

    // Abort the upstream model call only on a genuine client disconnect. Bind to the RESPONSE, not
    // the request: the request stream's 'close'/'end' fires as soon as the body parser drains the
    // POST body — which would self-abort the stream before it emits anything. `res` 'close' fires
    // only when the response/socket actually closes, and the `writableEnded` guard skips the normal
    // end-of-stream close.
    const abort = new AbortController();
    res.on('close', () => {
      if (!res.writableEnded) abort.abort();
    });
    res.on('error', () => abort.abort());

    const send = (event: SSEEvent): void => {
      if (res.writableEnded) return;
      res.write(`event: ${event.event}\n`);
      res.write(`data: ${JSON.stringify(event.data)}\n\n`);
    };

    try {
      await this.ai.streamChat(body ?? ({} as ChatRequest), send, abort.signal);
    } finally {
      if (!res.writableEnded) res.end();
    }
  }

  /** Execute a confirmed action draft (after Face ID on the client). Re-verified + simulated server-side. */
  @Post('confirm-action')
  confirm(@Body() body: ConfirmActionRequest) {
    return this.ai.confirmAction(body ?? ({} as ConfirmActionRequest));
  }

  /** Redacted audit trail (metadata only — no PII, no message text, no secrets). */
  @Get('audit')
  auditLog(@Query('profileId') profileId?: string, @Query('limit') limit?: string) {
    const n = limit ? Math.min(500, Math.max(1, Number(limit) || 100)) : 100;
    return { entries: this.audit.recent(profileId, n) };
  }
}
