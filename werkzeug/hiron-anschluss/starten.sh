#!/usr/bin/env bash
# Start the loopback adapter. Does not read or write a Hermes home.
set -euo pipefail
hier="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
state="${HIRON_ANSCHLUSS_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/hiron-openai-anschluss}"
case "$state" in
  *"/.hermes"|*"/.hermes"/*) echo "State liegt in einem Hermes-Home. Abgelehnt." >&2; exit 2 ;;
esac
if [[ -z "${HIRON_ROUTER_TOKEN:-}" ]]; then
  echo "HIRON_ROUTER_TOKEN fehlt. Es wird nichts gestartet." >&2
  exit 2
fi
mkdir -p "$state"
if [[ -f "$state/anschluss.pid" ]] && kill -0 "$(cat "$state/anschluss.pid")" 2>/dev/null; then
  echo "Läuft schon: $(cat "$state/port")" >&2
  exit 0
fi
port="${HIRON_ANSCHLUSS_PORT:-0}"
python3 "$hier/openai_anschluss.py" --port "$port" >"$state/anschluss.log" 2>&1 &
echo $! > "$state/anschluss.pid"
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  if grep -q '"event": "listening"' "$state/anschluss.log" 2>/dev/null; then
    python3 -c 'import json,sys; print(json.loads(sys.stdin.readline())["port"])' < "$state/anschluss.log" > "$state/port"
    echo "127.0.0.1:$(cat "$state/port")"
    exit 0
  fi
  sleep 0.1
done
echo "Kein Listening. Log: $state/anschluss.log" >&2
exit 1
