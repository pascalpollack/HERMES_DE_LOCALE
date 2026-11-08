#!/usr/bin/env bash
# Hermes Desktop — user launcher.
#
# Starts the installed AppImage against a fresh backend home and a fresh
# desktop home. The backend interpreter is the committed venv recorded in
# <data-root>/installs/<install_key>/facts.json. The PATH command `hermes`
# is not used. Nothing is installed into ~/.hermes, PATH is not changed,
# and `hermes pm repair` / `hermes update` are not run.
#
# HERMES_DISABLE_LAZY_INSTALLS=1 refuses on-demand installs.
# A session token is generated for this run, passed only in the child
# environment, and never written to a log or printed.
# --port 0 lets the backend pick a free port. This process never signals a
# server whose HERMES_HOME is not this installation's backend home.
#
# A second click, while this launcher still holds its lock, only tries to
# focus the existing window and then exits.

set -euo pipefail

hermes_desktop_self_dir() {
  cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd
}

hermes_desktop_data_dir() {
  if [[ -n "${HERMES_DESKTOP_DATA_DIR:-}" ]]; then
    printf '%s\n' "$HERMES_DESKTOP_DATA_DIR"
    return
  fi
  local here
  here="$(hermes_desktop_self_dir)"
  if [[ "$(basename "$here")" == bin && -f "$(dirname "$here")/Hermes.AppImage" ]]; then
    dirname "$here"
    return
  fi
  printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/hermes-desktop"
}

hermes_desktop_install_key() {
  local checkout
  checkout="$(readlink -f "$1")"
  printf '%s' "$checkout" | sha256sum | awk '{print substr($1,1,16)}'
}

hermes_desktop_discover_python() {
  local data_root="$1" checkout="$2" facts key envdir
  checkout="$(readlink -f "$checkout")"
  data_root="$(readlink -f "$data_root")"
  key="$(hermes_desktop_install_key "$checkout")"
  facts="$data_root/installs/$key/facts.json"
  if [[ ! -f "$facts" ]]; then
    echo "Keine Abhängigkeitsauswahl: $facts" >&2
    return 2
  fi
  envdir="$(python3 -c '
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
value = data.get("packages", {}).get("venv", {}).get("environment")
if not isinstance(value, str) or not value:
    raise SystemExit(2)
print(value)
' "$facts")"
  if [[ ! -x "$envdir/bin/python" || ! -f "$envdir/pyvenv.cfg" ]]; then
    echo "Ausgewähltes Environment ist kein venv-Interpreter: $envdir/bin/python" >&2
    return 2
  fi
  printf '%s\n' "$envdir/bin/python"
}

hermes_desktop_norm() {
  python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

hermes_desktop_forbid() {
  local path="$1" real_home="${2:-$HOME}" bad
  path="$(hermes_desktop_norm "$path")"
  real_home="$(hermes_desktop_norm "$real_home")"
  for bad in "$real_home/.hermes" "/home/pascal/.hermes"; do
    bad="$(hermes_desktop_norm "$bad")"
    if [[ "$path" == "$bad" || "$path" == "$bad"/* ]]; then
      echo "Pfad liegt im Produktions-Home ($bad): $path" >&2
      return 2
    fi
  done
}

hermes_desktop_userns_ok() {
  [[ -L /proc/self/ns/user ]] && unshare --user true
}

hermes_desktop_pid_alive() {
  local pid="$1"
  [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null
}

hermes_desktop_environ_has() {
  local pid="$1" key="$2" want="$3" line
  [[ -r "/proc/$pid/environ" ]] || return 1
  while IFS= read -r -d '' line; do
    if [[ "$line" == "$key=$want" ]]; then
      return 0
    fi
  done < "/proc/$pid/environ"
  return 1
}

hermes_desktop_focus() {
  if command -v wmctrl >/dev/null 2>&1; then
    wmctrl -xa Hermes && return 0
  fi
  if command -v xdotool >/dev/null 2>&1; then
    xdotool search --class Hermes windowactivate >/dev/null 2>&1 && return 0
  fi
  return 1
}

hermes_desktop_log() {
  local log="$1"
  shift
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$log"
  printf '%s\n' "$*" >&2
}

hermes_desktop_main() {
  local real_home="${HOME}"
  local data app checkout data_root backend_home desktop_home userdata logs run
  local launcher_log backend_log desktop_log token port python
  data="$(hermes_desktop_data_dir)"
  data="$(readlink -f "$data")"
  app="${HERMES_DESKTOP_APPIMAGE:-$data/Hermes.AppImage}"
  checkout="${HERMES_CHECKOUT:-$real_home/.hermes/hermes-agent}"
  data_root="${HERMES_DATA_ROOT:-$real_home/.hermes}"
  backend_home="$data/backend-home"
  desktop_home="$data/desktop-home"
  userdata="$data/userdata"
  logs="$data/logs"
  run="$data/run"
  launcher_log="$logs/launcher.log"
  backend_log="$logs/backend.log"
  desktop_log="$logs/desktop.log"

  hermes_desktop_forbid "$data" "$real_home"
  mkdir -p "$backend_home" "$desktop_home" "$userdata" "$logs" "$run"
  if [[ ! -x "$app" && ! -f "$app" ]]; then
    hermes_desktop_log "$launcher_log" "AppImage fehlt: $app"
    exit 2
  fi
  if ! hermes_desktop_userns_ok; then
    hermes_desktop_log "$launcher_log" "User-Namespaces fehlen (unshare --user). Kein Start und kein --no-sandbox. Log: $launcher_log"
    exit 3
  fi

  exec 9>"$run/launcher.lock"
  if ! flock -n 9; then
    hermes_desktop_focus || hermes_desktop_log "$launcher_log" "Hermes Desktop läuft bereits. Log: $launcher_log"
    exit 0
  fi

  python="$(hermes_desktop_discover_python "$data_root" "$checkout")"
  token="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32), end="")')"
  # The token stays in this process environment only.
  export HERMES_DASHBOARD_SESSION_TOKEN="$token"
  export HERMES_DESKTOP_REMOTE_TOKEN="$token"

  hermes_desktop_log "$launcher_log" "Starte Backend. Interpreter aus facts.json. Log: $backend_log"
  (
    cd "$checkout"
    exec env \
      HOME="$real_home" \
      HERMES_HOME="$backend_home" \
      HERMES_DISABLE_LAZY_INSTALLS=1 \
      HERMES_DASHBOARD_SESSION_TOKEN="$token" \
      "$python" -B -m hermes_cli.main serve \
        --host 127.0.0.1 --port 0 --skip-build --isolated
  ) >>"$backend_log" 2>&1 &
  local backend_pid=$!
  printf '%s\n' "$backend_pid" > "$run/backend.pid"

  port=""
  local deadline=$((SECONDS + 60)) line
  while [[ "$SECONDS" -lt "$deadline" ]]; do
    if ! hermes_desktop_pid_alive "$backend_pid"; then
      hermes_desktop_log "$launcher_log" "Backend endete vor der Bereitmeldung. Log: $backend_log"
      exit 1
    fi
    if [[ -f "$backend_log" ]]; then
      line="$(grep -E '^HERMES_BACKEND_READY port=[0-9]+$' "$backend_log" | tail -n 1 || true)"
      if [[ -n "$line" ]]; then
        port="${line#HERMES_BACKEND_READY port=}"
        break
      fi
    fi
    sleep 0.2
  done
  if [[ -z "$port" ]]; then
    if hermes_desktop_environ_has "$backend_pid" HERMES_HOME "$backend_home"; then
      kill "$backend_pid" 2>/dev/null || true
    fi
    hermes_desktop_log "$launcher_log" "Keine HERMES_BACKEND_READY-Zeile. Log: $backend_log"
    exit 1
  fi
  printf '%s\n' "$port" > "$run/port"
  hermes_desktop_log "$launcher_log" "Backend bereit auf 127.0.0.1:$port. Starte Hermes Desktop. Log: $desktop_log"

  local app_args=()
  if [[ ! -e /dev/fuse && "${HERMES_APPIMAGE_EXTRACT:-}" == 1 ]]; then
    app_args+=(--appimage-extract-and-run)
  fi
  env -u HERMES_DESKTOP_HERMES \
    HERMES_HOME="$desktop_home" \
    HERMES_DESKTOP_USER_DATA_DIR="$userdata" \
    HERMES_DESKTOP_IGNORE_EXISTING=1 \
    HERMES_DESKTOP_REMOTE_URL="http://127.0.0.1:$port" \
    HERMES_DESKTOP_REMOTE_TOKEN="$token" \
    HERMES_DESKTOP_SKIP_QUIT_CONFIRM=1 \
    "$app" "${app_args[@]}" >>"$desktop_log" 2>&1 &
  local desktop_pid=$!
  printf '%s\n' "$desktop_pid" > "$run/desktop.pid"
  unset token HERMES_DASHBOARD_SESSION_TOKEN HERMES_DESKTOP_REMOTE_TOKEN

  wait "$desktop_pid" || true
  if hermes_desktop_pid_alive "$backend_pid" && hermes_desktop_environ_has "$backend_pid" HERMES_HOME "$backend_home"; then
    kill "$backend_pid" 2>/dev/null || true
    wait "$backend_pid" 2>/dev/null || true
  fi
  rm -f "$run/backend.pid" "$run/desktop.pid" "$run/port"
  hermes_desktop_log "$launcher_log" "Hermes Desktop beendet. Backend dieser Installation gestoppt."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  hermes_desktop_main "$@"
fi
