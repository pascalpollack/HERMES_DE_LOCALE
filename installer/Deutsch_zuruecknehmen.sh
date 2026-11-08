#!/usr/bin/env bash
# Nimmt nur den deutschen Locale-Patch aus einem Hermes-Agent-Quellbaum zurück.
# Löscht keine Datenverzeichnisse und stellt kein installiertes Programm her.
#
#   installer/Deutsch_zuruecknehmen.sh /pfad/zum/hermes-agent

set -euo pipefail

hier="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
patch="$(cd "$hier/.." && pwd -P)/0001-hermes-desktop-german-locale.patch"
ziel="${1:?Pfad zum hermes-agent-Quellbaum}"

if [[ ! -f "$patch" || ! -f "$ziel/apps/desktop/package.json" ]]; then
  echo "Patch oder Desktop-Quellbaum fehlt." >&2
  exit 2
fi
if ! git -C "$ziel" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Der Zielpfad ist kein Git-Arbeitsbaum. Es wurde nichts geändert." >&2
  exit 2
fi

version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$ziel/apps/desktop/package.json" | head -n 1)"
if [[ -z "$version" ]]; then
  echo "Versionsfeld in apps/desktop/package.json nicht lesbar. Nichts geändert." >&2
  exit 2
fi
if [[ "$version" != "0.17.6" ]]; then
  echo "Desktop-Version ist $version. Zurückgenommen wird nur ein 0.17.6-Baum." >&2
  exit 2
fi

if git -C "$ziel" apply -R --check "$patch" 2>/dev/null; then
  git -C "$ziel" apply -R "$patch"
  echo "Deutscher Patch zurückgenommen. Kein Datenverzeichnis wurde gelöscht."
  exit 0
fi

echo "Der Baum trägt diesen Patch nicht mehr unverändert. Nichts geändert." >&2
exit 2
