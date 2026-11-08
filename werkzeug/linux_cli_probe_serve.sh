#!/usr/bin/env bash
# Start the already installed Hermes 0.22.7 backend against an empty data home.
#
# The PATH launcher (`hermes`) is store Python. Its dependency generation is
# selected from `<HERMES_HOME>/installs/<install_key>/facts.json`
# (`pm.environments.dependency_home_root`). An empty HERMES_HOME therefore has
# no committed environment, and `hermes --version` exits 1 with
# "no dependency environment is committed for this install" because `--version`
# is a metadata flag and skips the borrowed-home sync
# (`hermes_cli.venv_sync._METADATA_FLAGS`).
#
# This script does not call that launcher and does not run `hermes pm repair`.
# It reads only the install record `facts.json` (the `packages.venv.environment`
# path) and execs that generation's interpreter as the public module entry
# `python -m hermes_cli.main`. A venv interpreter keeps the packages it was
# built with (`pm.environments._require_own_dependencies`). HERMES_HOME still
# names only the empty probe, so config, sessions and logs are not the
# production home.
#
# Official serve flags used:
#   --skip-build   do not build the web UI (serve is already headless)
#   --isolated     dedicated server when a named profile is selected; it does
#                  not by itself retarget HERMES_HOME
# HERMES_DISABLE_LAZY_INSTALLS=1 is the documented probe switch that refuses
# on-demand installs (environment-variables.md). It is not written to .env.
#
# Usage:
#   HERMES_DASHBOARD_SESSION_TOKEN='synthetic-token' \
#     werkzeug/linux_cli_probe_serve.sh /home/pascal/hermes-desktop-probe/backend-home
#
# Optional:
#   HERMES_CHECKOUT=/path/to/hermes-agent
#   HERMES_DATA_ROOT=/path/to/the/install/data/root     # default: $HOME/.hermes
#     before this script changes HOME

set -euo pipefail

PROBE_HOME="${1:?empty backend home (must not be ~/.hermes)}"
PORT="${HERMES_SERVE_PORT:-9127}"
TOKEN="${HERMES_DASHBOARD_SESSION_TOKEN:-}"

if [[ -z "$TOKEN" ]]; then
  echo "HERMES_DASHBOARD_SESSION_TOKEN setzen. Das ist das Token für X-Hermes-Session-Token." >&2
  exit 2
fi

REAL_HOME="${HOME}"
PROBE_HOME="$(readlink -f "$PROBE_HOME")"
for bad in "$REAL_HOME/.hermes" "/home/pascal/.hermes"; do
  if [[ "$PROBE_HOME" == "$bad" || "$PROBE_HOME" == "$bad"/* ]]; then
    echo "Backend-Home $PROBE_HOME ist das Produktions-Home. Abgelehnt." >&2
    exit 2
  fi
done

DATA_ROOT="${HERMES_DATA_ROOT:-$REAL_HOME/.hermes}"
CHECKOUT="${HERMES_CHECKOUT:-$DATA_ROOT/hermes-agent}"
if [[ ! -f "$CHECKOUT/pyproject.toml" ]]; then
  echo "Checkout nicht gefunden: $CHECKOUT" >&2
  echo "HERMES_CHECKOUT auf den installierten Quellbaum setzen. Es wird nichts installiert." >&2
  exit 2
fi
CHECKOUT="$(readlink -f "$CHECKOUT")"
DATA_ROOT="$(readlink -f "$DATA_ROOT")"

KEY="$(printf '%s' "$CHECKOUT" | sha256sum | awk '{print substr($1,1,16)}')"
FACTS="$DATA_ROOT/installs/$KEY/facts.json"
if [[ ! -f "$FACTS" ]]; then
  echo "Keine Abhängigkeitsauswahl: $FACTS" >&2
  echo "Erwartet wird packages.venv.environment aus dem Install-Datensatz." >&2
  echo "hermes pm repair wird nicht ausgeführt." >&2
  exit 2
fi

ENVDIR="$(python3 -c '
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
print(data["packages"]["venv"]["environment"])
' "$FACTS")"
PYTHON="$ENVDIR/bin/python"
if [[ ! -x "$PYTHON" || ! -f "$ENVDIR/pyvenv.cfg" ]]; then
  echo "Das ausgewählte Environment ist kein venv-Interpreter: $PYTHON" >&2
  exit 2
fi

UNIX_HOME="${HERMES_PROBE_UNIX_HOME:-$PROBE_HOME.unixhome}"
XDG_CONFIG="${HERMES_PROBE_XDG_CONFIG:-$PROBE_HOME.xdg/config}"
XDG_DATA="${HERMES_PROBE_XDG_DATA:-$PROBE_HOME.xdg/data}"
XDG_CACHE="${HERMES_PROBE_XDG_CACHE:-$PROBE_HOME.xdg/cache}"
mkdir -p "$PROBE_HOME" "$UNIX_HOME" "$XDG_CONFIG" "$XDG_DATA" "$XDG_CACHE"

echo "Checkout (nur lesend als cwd): $CHECKOUT"
echo "facts.json: $FACTS"
echo "Interpreter: $PYTHON"
echo "Probe-HERMES_HOME: $PROBE_HOME"
echo "Bind: 127.0.0.1:$PORT"
echo "HERMES_DISABLE_LAZY_INSTALLS=1"

cd "$CHECKOUT"
exec env \
  HOME="$UNIX_HOME" \
  HERMES_HOME="$PROBE_HOME" \
  XDG_CONFIG_HOME="$XDG_CONFIG" \
  XDG_DATA_HOME="$XDG_DATA" \
  XDG_CACHE_HOME="$XDG_CACHE" \
  HERMES_DISABLE_LAZY_INSTALLS=1 \
  HERMES_DASHBOARD_SESSION_TOKEN="$TOKEN" \
  "$PYTHON" -B -m hermes_cli.main serve \
    --host 127.0.0.1 --port "$PORT" --skip-build --isolated
