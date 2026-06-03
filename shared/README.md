# `/shared` — API contract

The cross-platform API contract for Альфа-Ромео. **JSON Schema is the source of truth**; the
Swift and TypeScript types mirror it until codegen replaces the hand-written mirrors.

```
shared/
├── schema/        # canonical JSON Schema 2020-12 — the source of truth
│   ├── user.schema.json
│   ├── profile.schema.json
│   ├── membership.schema.json
│   ├── subscription.schema.json
│   ├── account.schema.json
│   ├── card.schema.json
│   └── transaction.schema.json
└── ts/
    └── contracts.ts   # canonical TypeScript mirror
```

## Where each language consumes it

| Layer            | Location                                            | Status                |
|------------------|-----------------------------------------------------|-----------------------|
| Canonical schema | `shared/schema/*.json`                              | source of truth       |
| TypeScript       | `shared/ts/contracts.ts`                            | hand mirror           |
| TS (backend)     | `backend/src/contracts/index.ts`                   | working copy (mirror) |
| Swift (iOS)      | `ios/AlfaRomeo/Core/Contracts/*.swift`             | hand mirror           |

## Conventions

- **camelCase** field names everywhere (TS-native; Swift `Codable` matches property names 1:1, so
  no `keyDecodingStrategy` is needed).
- **Dates are ISO-8601 strings** (`createdAt`, `renewsAt`, …) to keep decoding trivial in the
  scaffold. A typed date strategy can be added later.
- `additionalProperties: false` — the contract is closed; new fields are added deliberately.
- **Security:** card `panToken` is server-only and is intentionally absent from the contract;
  clients only ever see `last4`.

## Phase-0 entity set

`User · Profile · Membership · Subscription · Account · Card · Transaction` (§11.3, minimal slice).
Extended per phase per the roadmap (§14).

## Roadmap

- **Phase 0.3:** replace the hand-written Swift/TS mirrors with codegen from `schema/*.json`
  (single command), so the three representations can never drift.
