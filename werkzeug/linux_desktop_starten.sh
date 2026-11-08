#!/usr/bin/env bash
# Start the already-built Hermes Desktop 0.17.6 against an independently
# running `hermes serve`. Does not install, does not change PATH, does not
# spawn the CLI, and does not pass --no-sandbox.
#
# The desktop process gets its own empty HERMES_HOME under the probe
# directory. That is not the backend's home and must not be ~/.hermes.
#
# Usage:
#   HERMES_DESKTOP_REMOTE_URL=http://127.0.0.1:9127 \
#   HERMES_DESKTOP_REMOTE_TOKEN='synthetic-token' \
#   werkzeug/linux_desktop_starten.sh /home/pascal/hermes-desktop-probe \
#     /path/to/Hermes-0.17.6-linux-x86_64.AppImage
#
# Start the backend first, on its own empty home, with werkzeug/linux_cli_probe_serve.sh.

set -euo pipefail

PROBE="${1:?probe directory (must not be ~/.hermes)}"
APP="${2:?path to the AppImage or unpacked Hermes binary}"

if [[ ! -e "$APP" ]]; then
  echo "App nicht gefunden: $APP" >&2
  exit 2
fi

URL="${HERMES_DESKTOP_REMOTE_URL:-}"
TOKEN="${HERMES_DESKTOP_REMOTE_TOKEN:-}"
if [[ -z "$URL" || -z "$TOKEN" ]]; then
  echo "HERMES_DESKTOP_REMOTE_URL und HERMES_DESKTOP_REMOTE_TOKEN sind beide nötig." >&2
  echo "Ohne die beiden startet Desktop 0.17.6 ein lokales Backend. Das ist hier abgelehnt." >&2
  exit 2
fi

PROBE="$(readlink -f "$PROBE")"
REAL_HOME="${HOME}"
FORBIDDEN=("$REAL_HOME/.hermes" "/home/pascal/.hermes")
for bad in "${FORBIDDEN[@]}"; do
  if [[ "$PROBE" == "$bad" || "$PROBE" == "$bad"/* ]]; then
    echo "Probe-Verzeichnis liegt in $bad. Abgelehnt." >&2
    exit 2
  fi
done

mkdir -p "$PROBE/unixhome" "$PROBE/desktop-home" "$PROBE/userdata" "$PROBE/xdg"

echo "User-Namespace-Prüfung (kein --no-sandbox):"
if [[ -L /proc/self/ns/user ]] && unshare --user true; then
  echo "  unshare --user true  -> ok. Das Paket startet mit der normalen Electron-Sandbox."
else
  echo "  unshare --user true  -> fehlgeschlagen." >&2
  echo "  Es wird trotzdem ohne --no-sandbox gestartet. Schlägt das Fenster sofort fehl," >&2
  echo "  ist das die Sandbox-Sperre (auf Debian 13 oft AppArmor kernel.apparmor_restrict_unprivileged_userns)." >&2
  echo "  Nächster Kandidat ist das deb, dessen postinst chrome-sandbox nur dann setuid setzt." >&2
  echo "  Das braucht root und ist hier nicht als Debian-13-Erfolg belegt." >&2
fi
if [[ -r /proc/sys/kernel/apparmor_restrict_unprivileged_userns ]]; then
  echo "  apparmor_restrict_unprivileged_userns=$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns)"
fi

# PATH bleibt der des Aufrufers. HERMES_DESKTOP_HERMES wird nicht gesetzt.
# IGNORE_EXISTING verhindert, dass ein Fehlschlag der Remote-Auflösung die
# vorhandene CLI an ein Home hängt. Die Remote-Auflösung liegt vor dem
# lokalen Spawn; ein erreichbares URL+Token-Paar startet kein hermes serve.
exec env -u HERMES_DESKTOP_HERMES \
  HOME="$PROBE/unixhome" \
  XDG_CONFIG_HOME="$PROBE/xdg" \
  HERMES_HOME="$PROBE/desktop-home" \
  HERMES_DESKTOP_USER_DATA_DIR="$PROBE/userdata" \
  HERMES_DESKTOP_IGNORE_EXISTING=1 \
  HERMES_DESKTOP_REMOTE_URL="$URL" \
  HERMES_DESKTOP_REMOTE_TOKEN="$TOKEN" \
  HERMES_DESKTOP_SKIP_QUIT_CONFIRM=1 \
  "$APP" ${HERMES_APPIMAGE_EXTRACT:+--appimage-extract-and-run}
