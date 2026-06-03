import { Module } from '@nestjs/common';
import { PricingModule } from '../pricing/pricing.module';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { AnthropicEngine } from './ai.anthropic';
import { OfflineEngine } from './ai.offline';
import { AiContextService } from './ai.context';
import { AiKnowledgeBase } from './ai.kb';
import { AiGuardrails } from './ai.guardrails';
import { AiAuditService } from './ai.audit';

/**
 * AI-orchestration (§11.2, §11.7) — the server-side layer between the client and the Anthropic API.
 * The API key stays on the backend only and is never logged or returned. Financial tools return
 * signed action *drafts* (client confirms with biometrics → `confirm-action` re-verifies + simulates);
 * read-only tools run server-side. Falls back to a deterministic offline engine when no key is set.
 *
 * Endpoints: `POST /ai/chat` (SSE) · `POST /ai/confirm-action` · `GET /ai/health` · `GET /ai/audit`.
 */
@Module({
  imports: [PricingModule],
  controllers: [AiController],
  providers: [
    AiService,
    AnthropicEngine,
    OfflineEngine,
    AiContextService,
    AiKnowledgeBase,
    AiGuardrails,
    AiAuditService,
  ],
})
export class AiModule {}
