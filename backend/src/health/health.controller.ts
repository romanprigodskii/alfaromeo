import { Controller, Get } from '@nestjs/common';

/** The single working endpoint for the Phase-0 scaffold: `GET /health` → 200. */
@Controller()
export class HealthController {
  @Get('health')
  health() {
    return {
      status: 'ok',
      service: 'alfa-romeo-backend',
      timestamp: new Date().toISOString(),
    };
  }
}
