import { Logger } from '@nestjs/common';
import WebSocket from 'ws';
import { AssetMeta, symbolForBinance, symbolForCoincap } from './assets';

/** A USD price update from an upstream exchange (before ₽ conversion). */
export interface UpstreamTick {
  symbol: string; // canonical, e.g. "BTC"
  usd: number;
  changePct24h?: number | null;
  source: 'binance' | 'coincap';
}

type Provider = 'binance' | 'coincap';

/**
 * Single upstream price stream (§11.4): the backend holds ONE connection to a public exchange WS and
 * the gateway fans ticks out to all subscribed clients. Clients never connect to Binance/CoinGecko
 * directly (§11.1).
 *
 * Resilience: on disconnect/error we reconnect with exponential backoff and **rotate the source**
 * (Binance ↔ CoinCap), so a single provider outage doesn't stop the stream. Binance `@ticker` gives
 * last price + 24h %; CoinCap gives price only (% is filled in from the REST snapshot downstream).
 */
export class UpstreamStream {
  private readonly logger = new Logger('PriceUpstream');
  private ws?: WebSocket;
  private provider: Provider = 'binance';
  private attempt = 0;
  private stopped = false;
  private reconnectTimer?: ReturnType<typeof setTimeout>;

  constructor(
    private readonly metas: AssetMeta[],
    private readonly onTick: (tick: UpstreamTick) => void,
  ) {}

  start(): void {
    this.stopped = false;
    this.connect();
  }

  stop(): void {
    this.stopped = true;
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.ws?.removeAllListeners();
    try {
      this.ws?.close();
    } catch {
      /* ignore */
    }
    this.ws = undefined;
  }

  /** Which provider is currently feeding ticks (for status/logs). */
  get currentSource(): Provider {
    return this.provider;
  }

  private connect(): void {
    if (this.stopped) return;
    const url = this.provider === 'binance' ? this.binanceUrl() : this.coincapUrl();
    if (!url) {
      this.rotateAndRetry();
      return;
    }

    this.logger.log(`Connecting upstream (${this.provider}) …`);
    const socket = new WebSocket(url);
    this.ws = socket;

    socket.on('open', () => {
      this.attempt = 0;
      this.logger.log(`Upstream connected (${this.provider})`);
    });
    socket.on('message', (raw: WebSocket.RawData) => this.handleMessage(raw.toString()));
    socket.on('close', () => this.onDrop('closed'));
    socket.on('error', (err) => this.onDrop(`error: ${err.message}`));
  }

  private onDrop(reason: string): void {
    if (this.stopped) return;
    this.ws?.removeAllListeners();
    this.ws = undefined;
    this.logger.warn(`Upstream ${this.provider} ${reason} — rotating + backing off`);
    this.rotateAndRetry();
  }

  /** Rotate provider and reconnect with exponential backoff (cap 15s). */
  private rotateAndRetry(): void {
    if (this.stopped) return;
    this.provider = this.provider === 'binance' ? 'coincap' : 'binance';
    const delay = Math.min(1000 * 2 ** this.attempt, 15_000);
    this.attempt += 1;
    this.reconnectTimer = setTimeout(() => this.connect(), delay);
  }

  // MARK: Provider URLs

  private binanceUrl(): string | undefined {
    const streams = this.metas
      .filter((m) => m.binanceSymbol)
      .map((m) => `${m.binanceSymbol.toLowerCase()}@ticker`);
    if (streams.length === 0) return undefined;
    return `wss://stream.binance.com:9443/stream?streams=${streams.join('/')}`;
  }

  private coincapUrl(): string | undefined {
    const ids = this.metas.map((m) => m.coincapId).filter(Boolean);
    if (ids.length === 0) return undefined;
    return `wss://ws.coincap.io/prices?assets=${ids.join(',')}`;
  }

  // MARK: Message parsing

  private handleMessage(text: string): void {
    if (this.provider === 'binance') this.handleBinance(text);
    else this.handleCoincap(text);
  }

  private handleBinance(text: string): void {
    try {
      const msg = JSON.parse(text) as { data?: { s?: string; c?: string; P?: string } };
      const d = msg.data;
      if (!d?.s || d.c == null) return;
      const symbol = symbolForBinance(d.s);
      if (!symbol) return;
      this.onTick({
        symbol,
        usd: Number(d.c),
        changePct24h: d.P != null ? Number(d.P) : null,
        source: 'binance',
      });
    } catch {
      /* ignore malformed frame */
    }
  }

  private handleCoincap(text: string): void {
    try {
      const map = JSON.parse(text) as Record<string, string>;
      for (const [id, priceStr] of Object.entries(map)) {
        const symbol = symbolForCoincap(id);
        if (!symbol) continue;
        const usd = Number(priceStr);
        if (!Number.isFinite(usd)) continue;
        this.onTick({ symbol, usd, changePct24h: null, source: 'coincap' });
      }
    } catch {
      /* ignore malformed frame */
    }
  }
}
