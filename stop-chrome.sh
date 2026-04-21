#!/usr/bin/env bash
set -euo pipefail

# Stop Chromepilot Chrome/Chromium instance to free memory.

DEBUG_PORT="${DEBUG_PORT:-9222}"
DEBUG_PROFILE="${DEBUG_PROFILE:-/tmp/chromepilot-chrome-profile}"

is_cdp_live() {
  curl -fsS "http://127.0.0.1:${DEBUG_PORT}/json/version" >/dev/null 2>&1
}

collect_pids() {
  ps -eo pid=,args= | awk -v p="--remote-debugging-port=${DEBUG_PORT}" -v prof="--user-data-dir=${DEBUG_PROFILE}" '
    {
      pid=$1;
      $1="";
      cmd=substr($0,2);
      if ((index(cmd, "chrome") || index(cmd, "chromium")) && (index(cmd, p) || index(cmd, prof) || index(cmd, "chromepilot-chrome-profile"))) {
        print pid;
      }
    }
  ' | sort -u
}

mapfile -t pids < <(collect_pids)

if [[ ${#pids[@]} -eq 0 ]]; then
  if command -v lsof >/dev/null 2>&1; then
    mapfile -t pids < <(lsof -ti tcp:"${DEBUG_PORT}" || true)
  fi
fi

if [[ ${#pids[@]} -eq 0 ]]; then
  echo "No Chromepilot Chrome process found."
  exit 0
fi

echo "Stopping Chromepilot Chrome process(es): ${pids[*]}"
kill -TERM "${pids[@]}" 2>/dev/null || true

for _ in {1..10}; do
  alive=0
  for pid in "${pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      alive=1
      break
    fi
  done
  [[ $alive -eq 0 ]] && break
  sleep 0.5
done

leftovers=()
for pid in "${pids[@]}"; do
  if kill -0 "$pid" 2>/dev/null; then
    leftovers+=("$pid")
  fi
done

if [[ ${#leftovers[@]} -gt 0 ]]; then
  echo "Force-killing leftovers: ${leftovers[*]}"
  kill -KILL "${leftovers[@]}" 2>/dev/null || true
fi

if is_cdp_live; then
  echo "Warning: CDP endpoint still responding on port ${DEBUG_PORT}."
  exit 1
fi

echo "Chromepilot Chrome stopped. Memory freed."
