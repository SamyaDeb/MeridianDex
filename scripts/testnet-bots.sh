#!/usr/bin/env bash
# Start / stop the 10143 testnet bots (keeper -> MM -> flow), per keepers/RUNBOOK.md "Run MM + flow + keeper together".
# Keys come ONLY from a gitignored env file you create yourself (never commit it, never paste keys in chat):
#   BOTS_ENV (default: ./.env.bots) with KEEPER_PK=0x…  MM_PK=0x…  FLOW_PK=0x…  [RPC_URL=…]
# Usage: scripts/testnet-bots.sh start|start-perpl|stop|status
# RPC budget: the public testnet RPC rate-limits per IP (429 after a few req/s, 4 Nov 2026), and the browser shares
# that IP when the app runs locally, so both bots poll every 1.5 s (default 250 ms: ~11 req/s, which starved the app).
# Demo bias (TESTNET ONLY, disclosed): the MM centres its quotes QUOTE_SKEW_BPS over the index and the house flow
# leans to FLOW_TARGET_LOTS long, i.e. net long demand, so funding stays positive and the basis vault can enter.
# The vault may short only 0.8 x the net long of non-MM accounts, so the house long (200 lots = 20k MON) is what
# lets a ~600 USDC vault hedge fully. Set QUOTE_SKEW_BPS=0 FLOW_TARGET_LOTS=0 for a neutral book. Measured burn ≈ 6.3 MON/h for all three (4 Nov).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${BOTS_ENV:-$ROOT/.env.bots}"
LOGS="${BOTS_LOGS:-$ROOT/.bots}"
mkdir -p "$LOGS"
P=0x31491744e2dbf6df7fcf4ac0820d18a609b49076d45066d3568424e62f686cd1   # R12 Pyth MON/USD feed id (RUNBOOK)
READ=https://testnet-rpc.monad.xyz

run() { # name dir cmd...
  local name=$1 dir=$2; shift 2
  (cd "$ROOT/$dir" && env -i PATH="$PATH" HOME="$HOME" CHAIN_ID=10143 RPC_URL="$RPC_URL" "$@" >>"$LOGS/$name.log" 2>&1 & echo $! >"$LOGS/$name.pid")
  echo "started $name (pid $(cat "$LOGS/$name.pid"), log $LOGS/$name.log)"
}

case "${1:-}" in
  start)
    [ -f "$ENV_FILE" ] || { echo "missing $ENV_FILE (KEEPER_PK / MM_PK / FLOW_PK)"; exit 1; }
    set -a; source "$ENV_FILE"; set +a
    : "${KEEPER_PK:?}" "${MM_PK:?}" "${FLOW_PK:?}"
    RPC_URL="${RPC_URL:-$READ}"
    run keeper keepers/ts-fallback KEEPER_PK="$KEEPER_PK" PYTH_MON_USD_FEED_ID=$P LOG_SPAN=10 LOOKBACK_BLOCKS=3000 \
      FEED_HEARTBEAT_SEC="${FEED_HEARTBEAT_SEC:-30}" MAX_FUNDING_GAP_BLOCKS="${MAX_FUNDING_GAP_BLOCKS:-100}" \
      VAULT_REBALANCE=1 POLL_MS="${KEEPER_POLL_MS:-1500}" HEALTH_PORT=8797 pnpm start
    sleep 20
    # K3 Perpl hedge (docs/PERPL_HEDGE.md): on when .env.bots has the hedge wallet's Perpl API key (account 1404)
    HEDGE=()
    if [ -n "${PERPL_API_KEY:-}" ] && [ "${PERPL_HEDGE:-1}" = "1" ]; then
      HEDGE=(PERPL_HEDGE=1 PERPL_API_KEY="$PERPL_API_KEY" PERPL_API_KEY_SECRET="$PERPL_API_KEY_SECRET" PERPL_ACCOUNT_ID="${PERPL_ACCOUNT_ID:-1404}"
        HEDGE_BAND_BPS="${HEDGE_BAND_BPS:-500}" HEDGE_MAX_ORDER_MON="${HEDGE_MAX_ORDER_MON:-5000}" HEDGE_MAX_NOTIONAL_USD="${HEDGE_MAX_NOTIONAL_USD:-500}"
        HEDGE_EVIDENCE="$LOGS/hedge-evidence.jsonl")
    fi
    run mm mm-bot "${HEDGE[@]}" MM_PK="$MM_PK" READ_RPC_URL=$READ LEVELS="${MM_LEVELS:-1}" LOTS_PER_LEVEL="${MM_LOTS:-5}" \
      REQUOTE_BPS=10 TICK_EVERY_BLOCKS=3 POLL_MS="${MM_POLL_MS:-1500}" \
      QUOTE_SKEW_BPS="${QUOTE_SKEW_BPS:-1}" MAX_INVENTORY_LOTS="${MM_MAX_INVENTORY_LOTS:-1000}" pnpm start
    sleep 30
    run flow mm-bot FLOW_PK="$FLOW_PK" MM_PK="$MM_PK" READ_RPC_URL=$READ FLOW_MIN_SEC="${FLOW_MIN_SEC:-20}" FLOW_MAX_SEC="${FLOW_MAX_SEC:-70}" \
      FLOW_MAX_LOTS="${FLOW_MAX_LOTS:-5}" FLOW_TARGET_LOTS="${FLOW_TARGET_LOTS:-200}" \
      FLOW_POSITION_CAP_LOTS="${FLOW_POSITION_CAP_LOTS:-240}" pnpm flow
    ;;
  start-perpl) # the swap market settling on Perpl's funding (MON-FUNDING-PERPL): its keeper + its own MM
    [ -f "$ENV_FILE" ] || { echo "missing $ENV_FILE"; exit 1; }
    set -a; source "$ENV_FILE"; set +a
    : "${DEPLOYER_PK:?}" "${SWAP_MM_PK:?}"
    RPC_URL="${RPC_URL:-$READ}"
    # pokes PerplFundingSource once per Perpl funding event (~43 min); the deployer key, so no nonce clash with the keeper
    run perplkeeper keepers/ts-fallback KEEPER_PK="$DEPLOYER_PK" SWAP_MARKET=perpl POLL_MS=3000 HEALTH_PORT=8790 pnpm perpl-swap
    sleep 10
    # quotes the Perpl-funding swap book around Perpl's funding APR; re-quotes only when that moves 100 APR bps
    run swapmm mm-bot MM_PK="$SWAP_MM_PK" MARKET=swap SWAP_MARKET=perpl READ_RPC_URL=$READ LEVELS=1 LOTS_PER_LEVEL=3 \
      REQUOTE_BPS=100 TICK_EVERY_BLOCKS=10 POLL_MS=3000 KILL_FILE="$LOGS/KILL-swap" pnpm start
    ;;
  stop) # SIGINT: the MM cancels its resting orders
    for n in swapmm perplkeeper flow mm keeper; do
      [ -f "$LOGS/$n.pid" ] && { pkill -INT -P "$(cat "$LOGS/$n.pid")" 2>/dev/null || true; kill -INT "$(cat "$LOGS/$n.pid")" 2>/dev/null || true; rm -f "$LOGS/$n.pid"; echo "stopped $n"; }
    done ;;
  status)
    for n in keeper mm flow perplkeeper swapmm; do
      if [ -f "$LOGS/$n.pid" ] && kill -0 "$(cat "$LOGS/$n.pid")" 2>/dev/null; then echo "$n up"; else echo "$n down"; fi
    done
    curl -s -m 3 localhost:8797/health || true; echo ;;
  *) echo "usage: $0 start|start-perpl|stop|status"; exit 2 ;;
esac
