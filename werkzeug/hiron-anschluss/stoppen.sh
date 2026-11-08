#!/usr/bin/env bash
# Stop only the adapter process recorded in this state directory.
set -euo pipefail
state="${HIRON_ANSCHLUSS_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/hiron-openai-anschluss}"
pidfile="$state/anschluss.pid"
if [[ ! -f "$pidfile" ]]; then
  echo "Kein Pidfile."
  exit 0
fi
pid="$(cat "$pidfile")"
if [[ "$pid" =~ ^[0-9]+$ ]] && [[ -r "/proc/$pid/cmdline" ]] && tr '\0' ' ' < "/proc/$pid/cmdline" | grep -q 'openai_anschluss.py'; then
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
fi
rm -f "$pidfile" "$state/port"
echo "Gestoppt. State bleibt: $state"
