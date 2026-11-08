#!/usr/bin/env bash
# Exercises the user installer and launcher without a real Hermes checkout,
# without ~/.hermes, and without --no-sandbox.
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/werkzeug/hermes-desktop-starten.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Production paths are refused.
set +e
hermes_desktop_forbid "$TMP/home/.hermes/backend" "$TMP/home"
status=$?
set -e
[[ "$status" -eq 2 ]] || fail "production path status $status"

# install_key matches pm.environments.install_key (sha256, 16 hex).
checkout="$TMP/checkout"
mkdir -p "$checkout"
printf '%s\n' '[project]' 'name = "example"' > "$checkout/pyproject.toml"
key="$(hermes_desktop_install_key "$checkout")"
[[ "$key" =~ ^[0-9a-f]{16}$ ]] || fail "install key shape: $key"
python3 - << PY
import hashlib
from pathlib import Path
p = Path("$checkout").resolve()
expect = hashlib.sha256(str(p).encode("utf-8")).hexdigest()[:16]
got = "$key"
assert got == expect, (got, expect)
PY

# Discover the interpreter only from facts.json.
venv="$TMP/venv"
mkdir -p "$venv/bin"
printf '%s\n' 'home = /usr' > "$venv/pyvenv.cfg"
cat > "$venv/bin/python" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == *--version* ]]; then
  echo "Hermes Agent vtest"
  exit 0
fi
port="0"
prev=""
for arg in "$@"; do
  if [[ "$prev" == --port ]]; then
    port="$arg"
  fi
  prev="$arg"
done
if [[ "$port" == 0 ]]; then
  port=39127
fi
echo "HERMES_BACKEND_READY port=$port"
# Stay up until the launcher stops this process.
while true; do sleep 0.2; done
EOF
chmod +x "$venv/bin/python"
data_root="$TMP/data-root"
mkdir -p "$data_root/installs/$key"
python3 - << PY
import json
open("$data_root/installs/$key/facts.json", "w", encoding="utf-8").write(json.dumps({
    "schema": 1,
    "packages": {"venv": {"environment": "$venv"}},
}))
PY
found="$(hermes_desktop_discover_python "$data_root" "$checkout")"
[[ "$found" == "$venv/bin/python" ]] || fail "discover returned $found"

# Installer lays down a user desktop entry named Hermes Desktop.
fake_app="$TMP/Hermes.AppImage"
cat > "$fake_app" << 'EOF'
#!/usr/bin/env bash
echo desktop-started
sleep 2
EOF
chmod +x "$fake_app"
install_root="$TMP/install-home"
mkdir -p "$install_root"
HOME="$install_root" \
XDG_DATA_HOME="$install_root/.local/share" \
HERMES_DESKTOP_DATA_DIR="$install_root/.local/share/hermes-desktop" \
  "$ROOT/werkzeug/hermes-desktop-installieren.sh" "$fake_app" >"$TMP/install.out"
desk="$install_root/.local/share/applications/hermes-desktop.desktop"
grep -q '^Name=Hermes Desktop$' "$desk" || fail "desktop name"
grep -q 'hermes-desktop$' "$desk" || fail "desktop exec"
grep -q -- '--no-sandbox' "$desk" && fail "desktop file passes --no-sandbox"
grep -q 'nicht ~/.hermes' "$install_root/.local/share/hermes-desktop/backend-home/LESE-MICH.txt"
grep -q 'nicht ~/.hermes' "$install_root/.local/share/hermes-desktop/desktop-home/LESE-MICH.txt"
[[ -x "$install_root/.local/share/hermes-desktop/Hermes.AppImage" ]] || fail "appimage not installed"

# Launcher: one backend, token absent from logs, second click does not start another.
run_data="$TMP/run-data"
mkdir -p "$run_data"
launcher="$install_root/.local/share/hermes-desktop/bin/hermes-desktop"
# The installed launcher is a copy; point it at this fixture.
HOME="$install_root" \
HERMES_DESKTOP_DATA_DIR="$run_data" \
HERMES_DESKTOP_APPIMAGE="$fake_app" \
HERMES_CHECKOUT="$checkout" \
HERMES_DATA_ROOT="$data_root" \
  "$launcher" >"$TMP/first.out" 2>"$TMP/first.err" &
first=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if [[ -f "$run_data/run/backend.pid" ]]; then
    break
  fi
  sleep 0.1
done
[[ -f "$run_data/run/backend.pid" ]] || fail "backend pid missing"
ready_count="$(grep -c '^HERMES_BACKEND_READY port=' "$run_data/logs/backend.log" || true)"
[[ "$ready_count" == 1 ]] || fail "ready count $ready_count"
HOME="$install_root" \
HERMES_DESKTOP_DATA_DIR="$run_data" \
HERMES_DESKTOP_APPIMAGE="$fake_app" \
HERMES_CHECKOUT="$checkout" \
HERMES_DATA_ROOT="$data_root" \
  "$launcher" >"$TMP/second.out" 2>"$TMP/second.err" || fail "second click failed"
ready_after="$(grep -c '^HERMES_BACKEND_READY port=' "$run_data/logs/backend.log" || true)"
[[ "$ready_after" == 1 ]] || fail "second click started another backend ($ready_after)"
if grep -R -E 'HERMES_DASHBOARD_SESSION_TOKEN=|HERMES_DESKTOP_REMOTE_TOKEN=' "$run_data/logs" >/dev/null 2>&1; then
  fail "token was written to a log"
fi
wait "$first" || true
echo OK
