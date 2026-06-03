# Альфа-Ромео — банк 2035

A concept demo of a **2035 financial OS**: one identity → many profiles (personal / business /
joint / child), one money layer (₽ + digital ₽ + crypto), an own MVNO, and an AI co-pilot.
iOS-first (SwiftUI), with a NestJS backend.

> **Single source of truth:** [`docs/Alfa-Romeo_Master_Spec.md`](docs/Alfa-Romeo_Master_Spec.md).
> This repo is currently at **Phase 0 — foundation** (§14): a compiling, empty, themed iOS app +
> an empty backend skeleton. No product features yet.

## Monorepo layout

| Path        | What                                                                         |
|-------------|------------------------------------------------------------------------------|
| `ios/`      | SwiftUI app (iOS 17+, MVVM + `@Observable`, NavigationStack routers).        |
| `backend/`  | NestJS modular monolith — `GET /health` + empty stubs for every §11.2 service. |
| `shared/`   | The API contract: canonical **JSON Schemas** → source for Swift Codable + TS. |
| `docs/`     | The master spec.                                                             |

## Run the iOS app

Requires **Xcode 16+** (developed against Xcode 26.5).

```bash
open ios/AlfaRomeo.xcodeproj
# Select the "AlfaRomeo" scheme + any iOS Simulator, then ⌘R.
```

Or from the command line:

```bash
cd ios
xcodebuild -scheme AlfaRomeo -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

You get a dark, themed placeholder screen with the **«Альфа-Ромео»** wordmark.

> **Deployment target is iOS 17.0** (the pinned decision). This machine only has the iOS 26 SDK +
> simulators installed, so the app builds against the iOS 26 SDK and runs on an iOS 26 simulator;
> a literal iOS 17 simulator would need that runtime installed via Xcode. iOS-17 API compatibility
> is enforced by the deployment target either way.

## Run the backend

Requires **Node 20+** (developed against Node 22).

```bash
cd backend
npm install
npm run start            # http://localhost:3000  (override with PORT, e.g. PORT=3055 npm run start)
curl http://localhost:3000/health
# {"status":"ok","service":"alfa-romeo-backend","timestamp":"..."}
```

> **Port already in use?** The default is `3000`, which other dev servers commonly grab. If you see
> `Error: listen EADDRINUSE: address already in use :::3000` (or `/health` returns someone else's
> app), pick a free port: `PORT=3055 npm run start` then `curl http://localhost:3055/health`.

Optional Postgres + Redis (not needed for `/health`):

```bash
cd backend && docker compose up -d
```

## Architecture (pinned conventions)

**iOS**
- iOS 17+ · vanilla SwiftUI + Swift Concurrency · MVVM with `@Observable` (no TCA).
- Navigation: `NavigationStack` + a per-tab `Router`/coordinator (no third-party routers).
- DI through the SwiftUI **Environment**. Session state in `AppSession` (`@Observable`) holding
  auth state + `activeProfile`; **the theme is derived from `activeProfile.type`**.
- Charts: Swift Charts (added when charts appear). Dependencies: minimal/none.
- Structure: `Features/<Name>/{Views,ViewModels,Models}` + `DesignSystem`, `Networking`, `Core`.
- Networking: `protocol APIClient` (async) with `MockAPIClient` (default) and `LiveAPIClient`
  (URLSession, base URL from `APIEnvironment`); `WebSocketClient` (`URLSessionWebSocketTask`) and
  a separate `SSEClient` for AI streaming.

**Backend**
- NestJS modular monolith; one module per §11.2 service (module = future microservice boundary).
- PostgreSQL + Redis via `docker compose` (wired in a later phase).

**Shared contract**
- JSON Schema is canonical; Swift (`ios/AlfaRomeo/Core/Contracts`) and TS
  (`shared/ts`, `backend/src/contracts`) mirror it until codegen lands (Phase 0.3).
- Phase-0 entities: `User · Profile · Membership · Subscription · Account · Card · Transaction`.

## Roadmap

See §14 of the spec. Phase 0 (this) → Phase 1 personal core → Phase 2 products + crypto →
Phase 3 AI → Phase 4 Ромео-Бизнес → Phase 5 web + polish.
