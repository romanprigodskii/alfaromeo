import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { Logger } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors();

  // Default 4000 to avoid the common :3000 collision (§14). Override with PORT.
  const port = process.env.PORT ?? 4000;
  await app.listen(port);

  Logger.log(`Альфа-Ромео backend listening on http://localhost:${port}`, 'Bootstrap');
  Logger.log(`Prices: GET /prices?assets=BTC,ETH · WS ws://localhost:${port}/ws/prices`, 'Bootstrap');
}

void bootstrap();
