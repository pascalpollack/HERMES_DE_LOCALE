#!/usr/bin/env bash
# Install Hermes Desktop for the current user. No root, no PATH change,
# no write under ~/.hermes.
#
# Usage:
#   werkzeug/hermes-desktop-installieren.sh /path/to/Hermes-0.17.6-linux-x86_64.AppImage
#
# Layout (XDG, overridable with HERMES_DESKTOP_DATA_DIR):
#   $XDG_DATA_HOME/hermes-desktop/Hermes.AppImage
#   $XDG_DATA_HOME/hermes-desktop/bin/hermes-desktop
#   $XDG_DATA_HOME/hermes-desktop/backend-home/   fresh, not a copy of ~/.hermes
#   $XDG_DATA_HOME/hermes-desktop/desktop-home/   fresh Electron HERMES_HOME
#   $XDG_DATA_HOME/hermes-desktop/userdata/
#   $XDG_DATA_HOME/applications/hermes-desktop.desktop
#     Name=Hermes Desktop

set -euo pipefail

APPIMAGE="${1:?Pfad zur AppImage}"
if [[ ! -f "$APPIMAGE" ]]; then
  echo "AppImage nicht gefunden: $APPIMAGE" >&2
  exit 2
fi

REAL_HOME="${HOME}"
DATA="${HERMES_DESKTOP_DATA_DIR:-${XDG_DATA_HOME:-$REAL_HOME/.local/share}/hermes-desktop}"
DATA="$(mkdir -p "$DATA" && readlink -f "$DATA")"
for bad in "$REAL_HOME/.hermes" "/home/pascal/.hermes"; do
  if [[ "$DATA" == "$bad" || "$DATA" == "$bad"/* ]]; then
    echo "Installationsverzeichnis liegt in $bad. Abgelehnt." >&2
    exit 2
  fi
done

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
LAUNCHER_SRC="$ROOT/werkzeug/hermes-desktop-starten.sh"
ICON_SRC="$ROOT/installer/hermes-desktop-icon.png"
APPS="${XDG_DATA_HOME:-$REAL_HOME/.local/share}/applications"

mkdir -p "$DATA/bin" "$DATA/backend-home" "$DATA/desktop-home" "$DATA/userdata" \
  "$DATA/logs" "$DATA/run" "$DATA/icons" "$APPS"

install -m 0755 "$APPIMAGE" "$DATA/Hermes.AppImage"
install -m 0755 "$LAUNCHER_SRC" "$DATA/bin/hermes-desktop"
if [[ -f "$ICON_SRC" ]]; then
  install -m 0644 "$ICON_SRC" "$DATA/icons/hermes-desktop.png"
  mkdir -p "${XDG_DATA_HOME:-$REAL_HOME/.local/share}/icons"
  install -m 0644 "$ICON_SRC" "${XDG_DATA_HOME:-$REAL_HOME/.local/share}/icons/hermes-desktop.png"
fi

note=$'Dieses Verzeichnis gehört nur zu Hermes Desktop.\nEs ist neu angelegt. Es ist nicht ~/.hermes und übernimmt keine bestehende Konfiguration, keine Sitzungen und keine Anmeldung.\n'
printf '%s' "$note" > "$DATA/backend-home/LESE-MICH.txt"
printf '%s' "$note" > "$DATA/desktop-home/LESE-MICH.txt"

cat > "$APPS/hermes-desktop.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Hermes Desktop
GenericName=Hermes Desktop
Comment=Grafische Hermes-Oberfläche. Eigenes Datenverzeichnis, das bestehende CLI bleibt unverändert.
Exec=$DATA/bin/hermes-desktop
Icon=hermes-desktop
Terminal=false
Categories=Development;Utility;
StartupNotify=true
StartupWMClass=Hermes
EOF

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APPS" >/dev/null 2>&1 || true
fi

echo "Installiert: $DATA"
echo "Starter: $APPS/hermes-desktop.desktop"
echo "Name: Hermes Desktop"
echo "Logs bei einem Startfehler: $DATA/logs/launcher.log"
