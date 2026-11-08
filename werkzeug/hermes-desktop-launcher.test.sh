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
  bash "$ROOT/werkzeug/hermes-desktop-installieren.sh" "$fake_app" >"$TMP/install.out"
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

# A ready line already in the log is an old port. This run must wait for
# its own line and must not hand the GUI that old port.
stale="$TMP/stale-data"
mkdir -p "$stale/logs" "$stale/run"
printf '%s\n' 'HERMES_BACKEND_READY port=45553' > "$stale/logs/backend.log"
printf '%s\n' 45553 > "$stale/run/port"
slow="$TMP/slow-venv/bin"
mkdir -p "$slow"
cat > "$slow/python" << 'EOF'
#!/usr/bin/env bash
sleep 0.6
echo "HERMES_BACKEND_READY port=45079"
while true; do sleep 0.2; done
EOF
chmod +x "$slow/python"
slow_checkout="$TMP/slow-checkout"
mkdir -p "$slow_checkout"
printf '%s\n' '[project]' 'name = "slow"' > "$slow_checkout/pyproject.toml"
slow_key="$(hermes_desktop_install_key "$slow_checkout")"
mkdir -p "$TMP/slow-root/installs/$slow_key"
python3 - << PY
import json
open("$TMP/slow-root/installs/$slow_key/facts.json", "w", encoding="utf-8").write(json.dumps({
    "packages": {"venv": {"environment": "$TMP/slow-venv"}},
}))
PY
printf '%s\n' 'home = /usr' > "$TMP/slow-venv/pyvenv.cfg"
record_app="$TMP/record-app"
cat > "$record_app" << EOF
#!/usr/bin/env bash
printf '%s\n' "\${HERMES_DESKTOP_REMOTE_URL:-}" > "$TMP/seen-url"
# The token is present in this process and must not be written.
sleep 30
EOF
chmod +x "$record_app"
HOME="$install_root" \
HERMES_DESKTOP_DATA_DIR="$stale" \
HERMES_DESKTOP_APPIMAGE="$record_app" \
HERMES_CHECKOUT="$slow_checkout" \
HERMES_DATA_ROOT="$TMP/slow-root" \
HERMES_DESKTOP_READY_SECONDS=5 \
  "$launcher" >"$TMP/stale.out" 2>"$TMP/stale.err" &
stale_pid=$!
seen=""
for _ in $(seq 1 40); do
  if [[ -f "$TMP/seen-url" ]]; then
    seen="$(cat "$TMP/seen-url")"
    break
  fi
  sleep 0.1
done
[[ "$seen" == "http://127.0.0.1:45079" ]] || fail "gui url is '$seen'"
[[ "$(cat "$stale/run/port")" == "45079" ]] || fail "port file $(cat "$stale/run/port")"
grep -q '127.0.0.1:45553' "$TMP/stale.err" && fail "launcher announced the old port"
grep -q '127.0.0.1:45079' "$TMP/stale.err" || fail "launcher did not announce 45079"
if grep -R -E 'HERMES_DASHBOARD_SESSION_TOKEN=|HERMES_DESKTOP_REMOTE_TOKEN=' "$stale/logs" >/dev/null 2>&1; then
  fail "token was written to a log"
fi
kill "$(cat "$stale/run/desktop.pid")" 2>/dev/null || true
wait "$stale_pid" || true

# No new ready line: do not keep or announce the old port.
dead="$TMP/dead-data"
mkdir -p "$dead/logs" "$dead/run"
printf '%s\n' 'HERMES_BACKEND_READY port=45553' > "$dead/logs/backend.log"
printf '%s\n' 45553 > "$dead/run/port"
rm -f "$TMP/seen-url"
dead_app="$TMP/dead-app"
cat > "$dead_app" << EOF
#!/usr/bin/env bash
printf '%s\n' "\${HERMES_DESKTOP_REMOTE_URL:-}" > "$TMP/seen-url-dead"
EOF
chmod +x "$dead_app"
dead_bin="$TMP/dead-venv/bin"
mkdir -p "$dead_bin"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$dead_bin/python"
chmod +x "$dead_bin/python"
printf '%s\n' 'home = /usr' > "$TMP/dead-venv/pyvenv.cfg"
dead_checkout="$TMP/dead-checkout"
mkdir -p "$dead_checkout"
printf '%s\n' '[project]' 'name = "dead"' > "$dead_checkout/pyproject.toml"
dead_key="$(hermes_desktop_install_key "$dead_checkout")"
mkdir -p "$TMP/dead-root/installs/$dead_key"
python3 - << PY
import json
open("$TMP/dead-root/installs/$dead_key/facts.json", "w", encoding="utf-8").write(json.dumps({
    "packages": {"venv": {"environment": "$TMP/dead-venv"}},
}))
PY
set +e
HOME="$install_root" \
HERMES_DESKTOP_DATA_DIR="$dead" \
HERMES_DESKTOP_APPIMAGE="$dead_app" \
HERMES_CHECKOUT="$dead_checkout" \
HERMES_DATA_ROOT="$TMP/dead-root" \
HERMES_DESKTOP_READY_SECONDS=2 \
  "$launcher" >"$TMP/dead.out" 2>"$TMP/dead.err"
dead_status=$?
set -e
[[ "$dead_status" -ne 0 ]] || fail "stale-only log was treated as ready"
grep -q '127.0.0.1:45553' "$TMP/dead.err" && fail "dead run announced 45553"
[[ ! -f "$dead/run/port" ]] || fail "stale port file was kept"
[[ ! -f "$TMP/seen-url-dead" ]] || fail "gui was started from the old port"
echo OK
