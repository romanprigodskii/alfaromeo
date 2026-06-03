# `/backend` — Альфа-Ромео (NestJS)

A NestJS modular monolith with one module per §11.2 service. Two modules carry real logic so far:
**Pricing** (§11.4) serves live crypto prices over REST + WebSocket with the unified ₽ equivalent
computed server-side, and **AI-orchestration** (§11.7) is the server-side copilot between the client
and the Anthropic API (the key never leaves the backend). The remaining modules are still stubs.

## Run

```bash
cd backend
npm install
npm run start          # http://localhost:4000   (use start:dev for watch mode)
```

The server defaults to **port 4000** (not 3000, which is commonly taken). Override with `PORT`:

```bash
PORT=4100 npm run start
```

Verify the scaffold:

```bash
curl http://localhost:4000/health
# {"status":"ok","service":"alfa-romeo-backend","timestamp":"..."}
```

The scaffold boots **without** Postgres/Redis. Pricing uses Redis as a shared price cache when it's
reachable and transparently falls back to an in-memory cache otherwise — so it runs with or without
infra. To run Postgres/Redis locally:

```bash
docker compose up -d   # postgres:5432 + redis:6379
```

## Pricing — live crypto prices (§11.4)

The client **never** calls Binance/CoinGecko directly. The backend aggregates upstream data, caches
it, computes the ₽ equivalent, and serves it over our own REST + WS. One upstream connection is
fanned out to all subscribers (§11.1).

- **Source:** CoinGecko REST (snapshots, 24h %, OHLC candles — free demo, no key needed) + a single
  upstream WS for live ticks (**Binance `@ticker`**, falling back to **CoinCap** with exponential
  backoff + source rotation). On CoinGecko `429`, exponential backoff; cached values serve meanwhile.
- **₽ conversion:** crypto is quoted in USD upstream → converted to ₽ with the **real USD→₽ rate**.
  See [USD→₽ exchange rate](#usd₽-exchange-rate-cbr-1114) below.
- **Cache:** Redis (`REDIS_URL`) when available, else in-memory.
- **Default tracked assets:** `BTC, ETH, USDT, SOL, TON` (`PRICING_ASSETS`).

### USD→₽ exchange rate (CBR) (§11.4)

The ₽ equivalent is **not** a hard-coded constant — it uses the **official Bank of Russia daily
fixing**, fetched from `https://www.cbr-xml-daily.ru/daily_json.js` (a stable JSON mirror of the CBR
feed; field `Valute.USD.Value / Valute.USD.Nominal`). **No API key, no scraping.**

- **Refresh:** on boot, then every `FX_REFRESH_HOURS` (default **6 h**). The CBR rate moves once per
  business day, so a few hours is plenty; the first `/prices` response already uses the real rate
  (the service warms the rate before its first snapshot).
- **Cache:** the last rate is stored in Redis under `fx:usdrub` with a long TTL (`FX_CACHE_TTL_SEC`,
  default **30 days**) so it survives a CBR outage and a backend restart.
- **Fallback chain** when CBR is unreachable:
  `CBR fix → last cached rate (Redis/memory) → the legacy 92 constant (emergency, logged)`.
  The `source` field (`cbr` / `cache` / `fallback`) and a `stale` flag make the provenance visible.

```bash
# The rate behind every ₽ price — clients show «курс ЦБ ~XX ₽/$»
curl "http://localhost:4000/prices/fx"
# {"usdRub":72.5597,"source":"cbr","asOf":"2026-06-03T11:30:00+03:00","stale":false}
```

Every `PriceTick` (REST + WS) also carries the `usdRub` it was converted at, so a client can show the
rate without a second call.

### REST

```bash
# Snapshot — array of PriceTick in ₽ with 24h % (each tick carries the usdRub it was converted at)
curl "http://localhost:4000/prices?assets=BTC,ETH,USDT,SOL,TON"
# [{"asset":"BTC","price":4895000.1,"changePct24h":-5.7,"ts":"2026-...","usdRub":72.5597}, ...]

# USD→₽ rate behind the ₽ prices (CBR fix)
curl "http://localhost:4000/prices/fx"
# {"usdRub":72.5597,"source":"cbr","asOf":"2026-...","stale":false}

# Historical ₽ OHLC candles (range: 1d · 7d · 30d · 90d · 365d)
curl "http://localhost:4000/prices/BTC/candles?range=7d"
# [{"t":"2026-...","o":...,"h":...,"l":...,"c":...}, ...]
```

### WebSocket

```
ws://localhost:4000/ws/prices
  → send:     {"type":"subscribe","assets":["BTC","ETH"]}
  ← receive:  {"asset":"BTC","price":6207424.3,"changePct24h":-5.7,"ts":"2026-..."}   (per tick)
```

On subscribe the server immediately replays the cached snapshot, then streams live ticks.

### Config (`.env`, all optional — safe defaults)

| Var | Default | Purpose |
|---|---|---|
| `PORT` | `4000` | HTTP + WS port |
| `REDIS_URL` | `redis://localhost:6379` | shared price cache (falls back to memory) |
| `COINGECKO_API_KEY` | _(empty)_ | optional demo key → higher rate limit |
| `CBR_URL` | `https://www.cbr-xml-daily.ru/daily_json.js` | USD→₽ source (CBR daily fixing) |
| `FX_REFRESH_HOURS` | `6` | how often to re-fetch the CBR fix |
| `FX_CACHE_TTL_SEC` | `2592000` | how long the last CBR rate stays cached (30 days) |
| `FX_USD_RUB` | `92` | emergency fallback rate (only if CBR + cache both fail) |
| `PRICING_ASSETS` | `BTC,ETH,USDT,SOL,TON` | tracked symbols |
| `PRICING_SNAPSHOT_SEC` | `45` | CoinGecko snapshot cadence |

### iOS

The iOS app stays on **mock data by default** (works with no backend). In **NetworkDebugView**
(avatar → profile switcher → «Сетевой слой») the **«Live prices»** toggle switches the price layer to
this backend: `LiveAPIClient` hits `GET /prices` + `/prices/:asset/candles`, and `PriceSocket(.live)`
streams `/ws/prices`. iOS targets `localhost:4000` by default (override at runtime via the
`AR_BACKEND_PORT` UserDefaults key).

## AI-копилот — Claude orchestration (§11.7)

The client **never** calls Anthropic directly (same rule as prices). It talks to `/ai/*`; the
`ANTHROPIC_API_KEY` lives on the backend only — it is never logged and never returned. The backend
builds the system prompt + a **PII-light** profile context, runs Claude with tool-use, and streams
the answer back over SSE.

- **Engine:** real Claude via the official `@anthropic-ai/sdk` (Messages API, streaming) whenever
  `ANTHROPIC_API_KEY` is set. With **no key** it transparently falls back to a deterministic
  **offline demo engine** so the whole pipeline (SSE, drafts, guardrails, audit) works without a key.
  `GET /ai/health` reports which engine is live.
- **Modes** (§10.9): `support` (FAQ/operations + escalation), `coach` (proactive advice),
  `agent` (tool-use that **proposes** financial actions).
- **Tools:** read-only (no confirmation) — `get_balance`, `explain_transaction`, `search_kb`,
  `escalate_to_human`; action (agent mode only, **draft-only**) — `make_transfer`, `open_deposit`,
  `freeze_card`. The AI never moves money: an action becomes a **signed draft** the user must confirm
  with biometrics, after which `POST /ai/confirm-action` re-verifies the signature and runs a
  simulation (no real ledger movement — demo, like the rest of §14).
- **Guardrails (§11.7):** action tools are scoped to `agent` mode; amounts over
  `AI_AGENT_MAX_AMOUNT_RUB` are shown as a draft but blocked from execution; out-of-domain questions
  are refused; every request/action is written to a **redacted audit log** (no PII, no message text,
  no secrets); a human operator can always be requested.

### SSE wire format (`POST /ai/chat`)

Events are named to match the iOS `AIStreamEvent` enum (`Networking/AIStreamClient.swift`):

```
event: token       data: {"text":"…"}                         → .token(String)
event: toolDraft   data: {"draftId","tool","name","summary","params","amount","currency",
                          "requiresBiometric":true,"blocked","blockReason","expiresAt","signature"}
                                                               → .toolDraft(name:summary:)
event: done        data: {"stopReason":"end|tool_draft|escalated|error","escalated":bool}
                                                               → .done
```

`name` mirrors `tool` (the iOS `.toolDraft(name:summary:)` label); `signature` is an HMAC over the
draft's material fields **plus the owning profileId**, so confirm-action proves both authenticity and
the target profile. The draft is **single-use** and expires at `expiresAt`.

### Endpoints

```bash
# Health — which engine is live + model summary (no secrets)
curl -s http://localhost:4000/ai/health
# {"engine":"anthropic","live":true,"models":"fast=claude-sonnet-4-5 …","agentAmountLimitRub":100000}

# Read-only question → streamed text tokens (works in every mode)
curl -sN -X POST http://localhost:4000/ai/chat -H 'Content-Type: application/json' \
  -d '{"profileId":"profile-personal-demo","mode":"support",
       "messages":[{"role":"user","content":"Какой у меня баланс?"}]}'
# event: token … "184 200,55 RUB; …"  →  event: done {"stopReason":"end",…}

# Agent action → a make_transfer DRAFT (never executed)
curl -sN -X POST http://localhost:4000/ai/chat -H 'Content-Type: application/json' \
  -d '{"profileId":"profile-personal-demo","mode":"agent",
       "messages":[{"role":"user","content":"Переведи маме 5000"}]}'
# … event: toolDraft {"tool":"make_transfer","amount":5000,"signature":"…"}  →  done {"stopReason":"tool_draft"}

# Confirm the draft (after Face ID on the client) — server re-verifies the signature, then simulates
curl -s -X POST http://localhost:4000/ai/confirm-action -H 'Content-Type: application/json' \
  -d '{"profileId":"profile-personal-demo","draft":{ …the toolDraft payload verbatim… }}'
# {"status":"executed","tool":"make_transfer","message":"Перевод 5 000 RUB … выполнен · TX-…","result":{…}}

# Redacted audit trail (metadata only)
curl -s "http://localhost:4000/ai/audit?profileId=profile-personal-demo&limit=20"
```

A draft is rejected by `confirm-action` if its signature is tampered, the `profileId` doesn't match
the one it was issued for, it has expired, it was already confirmed once (single-use / no replay), or
it was `blocked` by a guardrail (e.g. over the amount limit) — so a client cannot fabricate, alter,
reuse, or cross-confirm an action the AI never proposed. Non-RUB amounts are converted to a ₽
equivalent (via the Pricing service) before the limit check, so a crypto/FX amount can't slip a large
transfer under the nominal ceiling.

### Config (`.env`, all optional — safe defaults)

| Var | Default | Purpose |
|---|---|---|
| `ANTHROPIC_API_KEY` | _(empty)_ | Anthropic key (backend-only). Empty → offline demo engine |
| `AI_MODEL` | `claude-sonnet-4-5` | model for `support` (fast) |
| `AI_MODEL_STRONG` | = `AI_MODEL` | model for `coach` / `agent` |
| `AI_MAX_TOKENS` | `1024` | max output tokens per turn |
| `AI_AGENT_MAX_AMOUNT_RUB` | `100000` | agent action over this ₽ amount is blocked from execution |
| `AI_DRAFT_SECRET` | _(random)_ | HMAC secret for signing action drafts |
| `AI_DRAFT_TTL_SEC` | `600` | how long a signed draft stays valid |

## Layout

```
src/
├── main.ts              # bootstrap (listens on $PORT, default 4000)
├── app.module.ts        # wires ConfigModule + HealthModule + the 16 §11.2 modules
├── config/              # typed env configuration
├── health/             # GET /health
├── contracts/          # TS API contract (mirror of /shared — codegen later)
└── modules/            # service modules (§11.2) — pricing + ai implemented, rest are stubs:
    auth · identity · subscriptions · accounts · payments · cards · credit ·
    deposits · crypto · pricing · mobile · business · analytics · ai ·
    notifications · support
```

Module boundaries are the future microservice boundaries (§11.1). Each module is wired into
`AppModule` so adding a controller/service later is a local change.

## Conventions

- **Modular monolith** — one module per §11.2 service; `@Module({})` stubs gain controllers/
  providers per phase (§14).
- **Config via `@nestjs/config`** — environment values have safe local defaults (`config/`).
- **No DB connection at boot** — Postgres/Redis are wired in a later phase so the scaffold stays
  green offline.
- **API contract** lives in `src/contracts` (mirrors `/shared/schema`). The PAN token is
  server-only and never appears in the contract.
