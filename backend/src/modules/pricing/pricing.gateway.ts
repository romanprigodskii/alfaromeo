import { Injectable, Logger, OnApplicationBootstrap, OnModuleDestroy } from '@nestjs/common';
import { HttpAdapterHost } from '@nestjs/core';
import { Subscription } from 'rxjs';
import { WebSocket, WebSocketServer } from 'ws';
import { normalizeAssets } from './assets';
import { PricingService } from './pricing.service';
import { PriceTick } from './types';

/** Per-connection state: the set of canonical symbols this client subscribed to. */
interface Client {
  socket: WebSocket;
  assets: Set<string>;
}

/**
 * WS gateway for `/ws/prices` (§11.9). A raw `ws` server is attached to Nest's HTTP server so the
 * iOS `URLSessionWebSocketTask` client speaks a clean, minimal protocol (no socket.io framing):
 *
 *   client → `{ "type": "subscribe", "assets": ["BTC","ETH"] }`
 *   server → `{ "asset":"BTC", "price":<₽>, "changePct24h":<n|null>, "ts":"…" }`   (one per tick)
 *
 * One upstream connection lives in ``PricingService``; this gateway just fans its ₽ ticks out to the
 * clients that asked for that asset, and replays the cached snapshot immediately on subscribe.
 */
@Injectable()
export class PricingGateway implements OnApplicationBootstrap, OnModuleDestroy {
  private readonly logger = new Logger('PricingGateway');
  private wss?: WebSocketServer;
  private tickSub?: Subscription;
  private readonly clients = new Map<WebSocket, Client>();

  constructor(
    private readonly adapterHost: HttpAdapterHost,
    private readonly pricing: PricingService,
  ) {}

  onApplicationBootstrap(): void {
    const httpServer = this.adapterHost.httpAdapter?.getHttpServer();
    if (!httpServer) {
      this.logger.error('No HTTP server available — /ws/prices not started');
      return;
    }

    // `noServer:false` with an explicit path: ws handles only `upgrade`s to /ws/prices, leaving the
    // REST routes to Express untouched.
    this.wss = new WebSocketServer({ server: httpServer, path: '/ws/prices' });
    this.wss.on('connection', (socket) => this.onConnection(socket));

    // Fan out every ₽ tick to the clients subscribed to that asset.
    this.tickSub = this.pricing.ticks$.subscribe((tick) => this.broadcast(tick));

    this.logger.log('WS gateway up · ws://<host>/ws/prices');
  }

  onModuleDestroy(): void {
    this.tickSub?.unsubscribe();
    this.clients.clear();
    this.wss?.close();
  }

  private onConnection(socket: WebSocket): void {
    this.clients.set(socket, { socket, assets: new Set() });
    this.logger.log(`Client connected (${this.clients.size} total)`);

    socket.on('message', (raw) => this.onMessage(socket, raw.toString()));
    socket.on('close', () => {
      this.clients.delete(socket);
      this.logger.log(`Client disconnected (${this.clients.size} total)`);
    });
    socket.on('error', () => {
      this.clients.delete(socket);
    });
  }

  private async onMessage(socket: WebSocket, text: string): Promise<void> {
    let msg: { type?: string; assets?: unknown };
    try {
      msg = JSON.parse(text);
    } catch {
      return;
    }
    if (msg.type !== 'subscribe' || !Array.isArray(msg.assets)) return;

    const metas = normalizeAssets(msg.assets.map(String));
    const client = this.clients.get(socket);
    if (!client) return;
    client.assets = new Set(metas.map((m) => m.symbol));

    // Replay the current cached snapshot immediately so the UI shows prices without waiting a tick.
    const snapshot = await this.pricing.getPrices([...client.assets]);
    for (const tick of snapshot) this.send(socket, tick);
  }

  private broadcast(tick: PriceTick): void {
    for (const client of this.clients.values()) {
      if (client.assets.has(tick.asset)) this.send(client.socket, tick);
    }
  }

  private send(socket: WebSocket, tick: PriceTick): void {
    if (socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify(tick));
    }
  }
}
