#!/usr/bin/env bash
# Start the Hermes CLI that is already on PATH as a headless backend.
# Does not install, does not rewrite PATH, and refuses the production home.
#
# Usage:
#   HERMES_DASHBOARD_SESSION_TOKEN='synthetic-token' \
#   werkzeug/linux_cli_probe_serve.sh /home/pascal/hermes-desktop-probe/backend-home
#
# Then point the desktop at http://127.0.0.1:${PORT:-9127} with the same token.
# Do not pass the production directory /home/pascal/.hermes.

set -euo pipefail

PROBE_HOME="${1:?empty backend home (must not be ~/.hermes)}"
PORT="${HERMES_SERVE_PORT:-9127}"
TOKEN="${HERMES_DASHBOARD_SESSION_TOKEN:-}"

if [[ -z "$TOKEN" ]]; then
  echo "HERMES_DASHBOARD_SESSION_TOKEN setzen. Das ist das Token für X-Hermes-Session-Token." >&2
  exit 2
fi

PROBE_HOME="$(readlink -f "$PROBE_HOME")"
REAL_HOME="${HOME}"
for bad in "$REAL_HOME/.hermes" "/home/pascal/.hermes"; do
  if [[ "$PROBE_HOME" == "$bad" || "$PROBE_HOME" == "$bad"/* ]]; then
    echo "Backend-Home $PROBE_HOME ist das Produktions-Home. Abgelehnt." >&2
    exit 2
  fi
done

if ! command -v hermes >/dev/null 2>&1; then
  echo "hermes ist nicht auf PATH. Es wird nichts installiert." >&2
  exit 2
fi

mkdir -p "$PROBE_HOME"
echo "CLI: $(command -v hermes)"
echo "Home: $PROBE_HOME"
echo "Bind: 127.0.0.1:$PORT"
exec env \
  HERMES_HOME="$PROBE_HOME" \
  HERMES_DASHBOARD_SESSION_TOKEN="$TOKEN" \
  hermes serve --host 127.0.0.1 --port "$PORT"
