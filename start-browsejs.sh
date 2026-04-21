#!/usr/bin/env bash
# Idempotent launcher for the full browser-js stack:
#   - Chrome with CDP on port 9222 (separate debug profile)
#   - HTTP server on port 9223 (node server.js)
# Safe to run multiple times. Safe to run at login.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SERVER_JS="${HERE}/server.js"
LOG_FILE="${LOG_FILE:-${HERE}/server.log}"
CDP_PORT="${DEBUG_PORT:-9222}"
HTTP_PORT="${HTTP_PORT:-9223}"

is_cdp_live()   { curl -fsS "http://127.0.0.1:${CDP_PORT}/json/version" >/dev/null 2>&1; }
is_http_live()  { curl -fsS "http://127.0.0.1:${HTTP_PORT}/health"       >/dev/null 2>&1; }

# ── 1. Chrome on 9222 ───────────────────────────────────────────────────────
if is_cdp_live; then
  echo "[chrome]  ${CDP_PORT} already live — skipping launch"
else
  echo "[chrome]  launching debug Chrome (separate profile)"
  bash "${HERE}/launch-chrome.sh"
fi

# ── 2. HTTP server on 9223 ──────────────────────────────────────────────────
if is_http_live; then
  echo "[server]  ${HTTP_PORT} already live — skipping launch"
else
  echo "[server]  launching node server.js (log: ${LOG_FILE})"
  nohup node "${SERVER_JS}" >"${LOG_FILE}" 2>&1 &
  disown || true
  for _ in {1..15}; do
    is_http_live && break
    sleep 1
  done
fi

# ── 3. Verify ───────────────────────────────────────────────────────────────
echo
if is_cdp_live;  then echo "Chrome (${CDP_PORT}): OK";    else echo "Chrome (${CDP_PORT}): DOWN";    fi
if is_http_live; then echo "Server (${HTTP_PORT}): OK";    else echo "Server (${HTTP_PORT}): DOWN";    fi
is_cdp_live && is_http_live
