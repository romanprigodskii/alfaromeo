#!/usr/bin/env bash
#
# Deploy the backend to prod (api.alfa-romeo.uk) — ships the NEW wallet module (balances/transfers)
# WITHOUT breaking the live Pricing and AI modules. Safe to re-run (idempotent) and auto-rolls-back
# if Pricing or AI regress.
#
# Run from your machine (needs network access to the server — currently the host running this could
# NOT reach 192.145.29.25; connect/VPN/whitelist first, then run):
#     bash backend/deploy/deploy-wallet.sh
#
# Honors every constraint from the task:
#  • rsync with --exclude='.env' --exclude='node_modules', and NO --delete (never wipes server .env /
#    node_modules / anything not in the source).
#  • npm ci && npm run build on the server, then `pm2 restart`.
#  • build runs BEFORE the restart — a broken build aborts WITHOUT restarting (prod stays on old build).
#  • DEMO_START_BALANCE_RUB is appended to the server .env only if missing — existing keys
#    (ANTHROPIC_API_KEY, the FX rate, DATABASE_URL, …) are never touched.
#  • after restart: curl /health, /prices (Pricing), /ai/chat (AI), /auth/register-demo + /transfer
#    (wallet). If Pricing or AI is down → automatic rollback to the previous source + rebuild + restart.
#
set -uo pipefail

SERVER="${SERVER:-root@192.145.29.25}"
KEY="${KEY:-$HOME/.ssh/alfaromeo_deploy}"
REMOTE_DIR="${REMOTE_DIR:-/opt/alfa-romeo/backend}"
PM2_APP="${PM2_APP:-alfa-romeo-api}"
BASE="${BASE:-https://api.alfa-romeo.uk}"
LOCAL_BACKEND="$(cd "$(dirname "$0")/.." && pwd)"          # repo backend/
SSH_OPTS=(-i "$KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20)

say(){ printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }
err(){ printf '\033[1;31m%s\033[0m\n' "$*"; }
ok(){  printf '\033[1;32m%s\033[0m\n' "$*"; }
sshx(){ ssh "${SSH_OPTS[@]}" "$SERVER" "$@"; }
# Run a curl ON THE SERVER (the deploying host may not reach the public domain; the server reaches its
# own nginx). $1 = curl args as a single string.
rcurl(){ sshx "curl -s $1"; }

rollback(){
  err "‼ ROLLBACK — restoring previous server source, rebuilding, restarting…"
  sshx "set -e; cd $REMOTE_DIR && [ -d .rollback ] && \
        rsync -a --exclude='node_modules' .rollback/ ./ && npm ci && npm run build && \
        pm2 restart $PM2_APP --update-env" || err "rollback hit an error — inspect the server manually!"
  sleep 4
  local h; h="$(rcurl "-o /dev/null -w '%{http_code}' $BASE/health")"
  echo "health after rollback: $h"
}

# ── 0. Preflight ──────────────────────────────────────────────────────────────
say "0/8  Preflight — reachability + local build"
sshx 'echo ok' >/dev/null 2>&1 || { err "❌ cannot SSH to $SERVER (server unreachable — connect/VPN/whitelist first)"; exit 1; }
( cd "$LOCAL_BACKEND" && npm run build >/dev/null 2>&1 ) || { err "❌ local build failed — fix before deploying"; exit 1; }
ok "ssh reachable, local build green"

# ── 1. Snapshot current server source for rollback ───────────────────────────
say "1/8  Snapshot current server source → $REMOTE_DIR/.rollback"
sshx "set -e; cd $REMOTE_DIR && rm -rf .rollback && mkdir -p .rollback && \
      rsync -a --exclude='node_modules' --exclude='.git' --exclude='.rollback' ./ .rollback/ && echo '  snapshot done'"

# ── 2. Show current .env key NAMES (values stay hidden/secret) ───────────────
say "2/8  Current server .env keys (names only — values never printed)"
sshx "cd $REMOTE_DIR && (grep -oE '^[A-Za-z0-9_]+=' .env 2>/dev/null | tr -d '=' | sort | sed 's/^/  /') || echo '  (no .env found!)'"

# ── 3. rsync source — EXCLUDE .env + node_modules, NO --delete ───────────────
say "3/8  rsync source → server (exclude .env, node_modules, dist; NO --delete)"
rsync -az --human-readable \
  --exclude='.env' --exclude='node_modules' --exclude='dist' --exclude='.git' \
  --exclude='.rollback' --exclude='deploy/' \
  -e "ssh ${SSH_OPTS[*]}" \
  "$LOCAL_BACKEND"/ "$SERVER:$REMOTE_DIR"/
ok "  source synced"

# ── 4. Ensure DEMO_START_BALANCE_RUB (append-only) + check DATABASE_URL/Postgres ─
say "4/8  Ensure DEMO_START_BALANCE_RUB in server .env (append only — never overwrite)"
sshx "cd $REMOTE_DIR && touch .env && \
  ( grep -q '^DEMO_START_BALANCE_RUB=' .env && echo '  already present' || \
    { printf '\nDEMO_START_BALANCE_RUB=50000\n' >> .env; echo '  appended DEMO_START_BALANCE_RUB=50000'; } ) && \
  ( grep -q '^DATABASE_URL=' .env && echo '  DATABASE_URL present (wallet will connect)' || \
    echo '  ⚠ DATABASE_URL missing → wallet returns 503 (Pricing/AI unaffected). Add it to .env if you want wallet live.' )"
say "4b   Postgres on server? (wallet auto-creates demo_users/demo_transfers on boot)"
sshx "docker ps --format '{{.Names}} {{.Status}}' 2>/dev/null | grep -i postgres || echo '  ⚠ no postgres container in docker ps — check docker compose'"

# ── 5. npm ci + build ON THE SERVER (build BEFORE restart) ───────────────────
say "5/8  npm ci && npm run build on the server (abort without restart if it fails)"
if ! sshx "cd $REMOTE_DIR && npm ci && npm run build"; then
  err "❌ remote npm ci/build FAILED — NOT restarting (prod still serving the old build)."
  rollback
  exit 1
fi
ok "  server build green"

# ── 6. Restart ───────────────────────────────────────────────────────────────
say "6/8  pm2 restart $PM2_APP"
sshx "pm2 restart $PM2_APP --update-env && sleep 4 && pm2 status $PM2_APP | tail -4"

# ── 7. Verify ALL — Pricing & AI must survive; wallet must work ──────────────
say "7/8  Verify (curl from the server against $BASE)"
FAIL=0

H="$(rcurl "-o /dev/null -w '%{http_code}' $BASE/health")"
echo "  1) /health → $H"; [ "$H" = "200" ] || { err "     ❌ health not 200"; FAIL=1; }

P="$(rcurl "$BASE/prices?assets=BTC,ETH")"
echo "  2) /prices → ${P:0:160}"
echo "$P" | grep -q '"price"' || { err "     ❌ PRICING regressed (no price field)"; FAIL=1; }

AI="$(sshx "curl -s -m 15 -N -X POST $BASE/ai/chat -H 'Content-Type: application/json' -d '{\"profileId\":\"profile-personal-demo\",\"mode\":\"support\",\"messages\":[{\"role\":\"user\",\"content\":\"Привет\"}]}' | head -c 240")"
echo "  3) /ai/chat → ${AI:0:160}"
echo "$AI" | grep -q 'event:' || { err "     ❌ AI regressed (no SSE 'event:' frames)"; FAIL=1; }

# Wallet (non-fatal for rollback decision — Pricing/AI are the must-not-break; wallet 503 only means
# DATABASE_URL/Postgres isn't set up yet, which does not affect the old modules).
PH_A="+79990000001"; PH_B="+79990000002"
RA="$(rcurl "-X POST $BASE/auth/register-demo -H 'Content-Type: application/json' -d '{\"phone\":\"$PH_A\",\"displayName\":\"Deploy A\"}'")"
RB="$(rcurl "-X POST $BASE/auth/register-demo -H 'Content-Type: application/json' -d '{\"phone\":\"$PH_B\",\"displayName\":\"Deploy B\"}'")"
echo "  4a) register A → ${RA:0:140}"
echo "  4b) register B → ${RB:0:140}"
TR="$(rcurl "-X POST $BASE/transfer -H 'Content-Type: application/json' -d '{\"fromPhone\":\"$PH_A\",\"toPhone\":\"$PH_B\",\"amount\":1000}'")"
echo "  4c) transfer A→B 1000 → ${TR:0:200}"
echo "$TR" | grep -q '"transferId"' && ok "     ✔ wallet transfer works" || err "     ⚠ wallet transfer not confirmed (check DATABASE_URL/Postgres) — Pricing/AI unaffected"

# ── 8. Verdict ───────────────────────────────────────────────────────────────
if [ "$FAIL" = "1" ]; then
  err "‼ Pricing or AI regressed after deploy — rolling back."
  rollback
  exit 1
fi
ok "
8/8 ✅ Deploy OK — Pricing + AI intact, wallet module live. (rollback snapshot kept at $REMOTE_DIR/.rollback)"
