/**
 * Альфа-Ромео — shared API contract (backend working copy).
 *
 * SOURCE OF TRUTH: /shared/schema/*.json. This mirrors /shared/ts/contracts.ts so the backend
 * stays self-contained (clean `nest build` / `nest start`, no cross-package import).
 * Keep in sync until codegen replaces both hand-written mirrors (Phase 0.3).
 *
 * All date fields are ISO-8601 strings. Minimal Phase-0 entity set; extended per phase (§14).
 */

// ── Enums (as string unions) ────────────────────────────────────────────────

export type KycStatus = 'none' | 'pending' | 'verified' | 'rejected';
export type InvestorStatus = 'none' | 'unqualified' | 'qualified';

export type ProfileType = 'personal' | 'business' | 'joint' | 'child';

export type MembershipRole = 'owner' | 'admin' | 'accountant' | 'manager' | 'member';

export type SubscriptionTier =
  | 'base'
  | 'pro'
  | 'infinite'
  | 'biz_start'
  | 'biz_pro'
  | 'biz_corp';
export type SubscriptionStatus = 'active' | 'trialing' | 'canceled' | 'past_due';

export type AccountType = 'current' | 'savings' | 'crypto' | 'digital_ruble';

export type CardType = 'virtual' | 'plastic' | 'crypto' | 'disposable';
export type CardState = 'active' | 'frozen' | 'issuing' | 'shipping' | 'expired' | 'burned';

export type TransactionKind =
  | 'transfer'
  | 'payment'
  | 'convert'
  | 'trade'
  | 'payout'
  | 'acquire';
export type TransactionStatus =
  | 'pending'
  | 'processing'
  | 'completed'
  | 'failed'
  | 'declined';

// ── Entities ────────────────────────────────────────────────────────────────

/** One human, one KYC. Owns many Profiles. */
export interface User {
  id: string;
  phone: string;
  kycStatus: KycStatus;
  investorStatus: InvestorStatus;
  createdAt: string;
}

/** An isolated context under one User. App theme is derived from `type`. */
export interface Profile {
  id: string;
  userId: string;
  type: ProfileType;
  displayName?: string;
  theme?: string | null;
  createdAt: string;
}

/** Role + permissions of a User within a Profile. */
export interface Membership {
  userId: string;
  profileId: string;
  role: MembershipRole;
  permissions: string[];
}

/** Membership tier for a Profile (feature-flags + limits). */
export interface Subscription {
  profileId: string;
  tier: SubscriptionTier;
  status: SubscriptionStatus;
  renewsAt?: string | null;
  price?: number | null;
}

/** A balance container scoped to a Profile. */
export interface Account {
  id: string;
  profileId: string;
  type: AccountType;
  currency: string;
  balance: number;
}

/** A payment card. The PAN token never leaves the server — only `last4` is exposed. */
export interface Card {
  id: string;
  accountId: string;
  profileId: string;
  type: CardType;
  last4: string;
  state: CardState;
  designId?: string | null;
  isDefault: boolean;
  assetLink?: string | null;
}

/** A money movement scoped to a Profile. */
export interface Transaction {
  id: string;
  profileId: string;
  kind: TransactionKind;
  status: TransactionStatus;
  amount: number;
  currency: string;
  counterparty?: string | null;
  fee?: number | null;
  fxRate?: number | null;
  createdAt: string;
}

// ── NEW: Enums (as string unions) ───────────────────────────────────────────

export type PhysicalCardStatus = 'none' | 'ordered' | 'printing' | 'shipping' | 'delivered';

export type OrderSide = 'buy' | 'sell';
export type OrderType = 'market' | 'limit';
export type OrderStatus = 'open' | 'filled' | 'partial' | 'canceled' | 'rejected';

export type DepositKind = 'ruble' | 'stake';

export type LegalForm = 'ip' | 'ooo' | 'self_employed';
export type InvoiceStatus = 'draft' | 'sent' | 'paid' | 'overdue' | 'canceled';
export type PayrollStatus = 'draft' | 'processing' | 'completed' | 'failed';
export type AcquiringType = 'online' | 'terminal' | 'qr' | 'link' | 'crypto';
export type ApprovalStatus = 'pending' | 'signed' | 'rejected';

// ── NEW: Entities ───────────────────────────────────────────────────────────

/** A card order: virtual issues instantly; the optional physical card ships with mock tracking. */
export interface CardOrder {
  id: string;
  profileId: string;
  cardType: CardType;
  designId?: string | null;
  virtualIssuedAt?: string | null;
  physicalStatus: PhysicalCardStatus;
  tracking?: string | null;
  address?: string | null;
}

/** A per-asset crypto wallet scoped to a Profile. */
export interface CryptoWallet {
  id: string;
  profileId: string;
  asset: string;
  chain: string;
  address: string;
  balance: number;
}

/** A crypto trading order (demo execution simulated against live prices). */
export interface Order {
  id: string;
  profileId: string;
  asset: string;
  side: OrderSide;
  type: OrderType;
  qty: number;
  price?: number | null;
  status: OrderStatus;
  createdAt: string;
}

/** A savings product: ruble deposit or crypto stake. */
export interface Deposit {
  id: string;
  profileId: string;
  kind: DepositKind;
  asset?: string | null;
  principal: number;
  rateApy: number;
  term?: number | null;
  lockUntil?: string | null;
}

/** Ромео Mobile (MVNO) plan for a Profile — mock operator. */
export interface MobilePlan {
  profileId: string;
  msisdn: string;
  esimId: string;
  tariff: string;
  dataGb: number;
  minutes: number;
  usedGb: number;
  usedMin: number;
  roaming: boolean;
}

/** A price point for an asset. `price` is the unified ₽ equivalent. */
export interface PriceTick {
  asset: string;
  price: number;
  changePct24h?: number | null;
  ts: string;
  /** USD→₽ rate used for this tick (so clients can show «курс ЦБ ~XX ₽/$»). */
  usdRub?: number | null;
}

/** The unified USD→₽ rate served at `GET /prices/fx` (§11.4). `source`: cbr | cache | fallback. */
export interface FxRate {
  usdRub: number;
  source: 'cbr' | 'cache' | 'fallback';
  asOf: string;
  stale: boolean;
}

/** A legal entity behind a business Profile. */
export interface Business {
  profileId: string;
  legalForm: LegalForm;
  ogrn: string;
  inn: string;
  name: string;
}

/** A counterparty in the business address book. */
export interface Counterparty {
  id: string;
  businessId: string;
  inn: string;
  name: string;
  account?: string | null;
}

/** An issued/received invoice. */
export interface Invoice {
  id: string;
  businessId: string;
  counterpartyId?: string | null;
  amount: number;
  status: InvoiceStatus;
  due?: string | null;
}

/** A payroll run (items collapsed to a count + total for the mock). */
export interface PayrollRun {
  id: string;
  businessId: string;
  status: PayrollStatus;
  itemsCount: number;
  totalAmount: number;
}

/** An acquiring point (online / QR / terminal / crypto). */
export interface AcquiringPoint {
  id: string;
  businessId: string;
  type: AcquiringType;
  label?: string | null;
}

/** A multi-step (2-of-N) approval request for a business operation. */
export interface ApprovalRequest {
  id: string;
  businessId: string;
  opId: string;
  required: number;
  signedBy: string[];
  status: ApprovalStatus;
}
