#!/usr/bin/env bash
# Spielt den deutschen Locale-Patch in einen Hermes-Agent-Quellbaum ein.
# Baut die App nicht, installiert kein Backend und schreibt nicht nach ~/.hermes.
#
#   installer/Deutsch_installieren.sh /pfad/zum/hermes-agent
#
# Der Baum muss Git sein, Desktop 0.17.6, und der Patch muss sauber passen.
# Ein fertig installiertes Programm (Windows oder Linux) wird hiermit nicht geändert.

set -euo pipefail

hier="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
patch="$(cd "$hier/.." && pwd)/0001-hermes-desktop-german-locale.patch"
ziel="${1:?Pfad zum hermes-agent-Quellbaum}"

if [[ ! -f "$patch" ]]; then
  echo "Patch fehlt: $patch" >&2
  exit 2
fi
if [[ ! -f "$ziel/apps/desktop/package.json" ]]; then
  echo "Kein Desktop-Quellbaum: $ziel" >&2
  exit 2
fi
if ! git -C "$ziel" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Der Zielpfad ist kein Git-Arbeitsbaum. Es wird nichts kopiert." >&2
  exit 2
fi

version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["version"])' "$ziel/apps/desktop/package.json")"
if [[ "$version" != "0.17.6" ]]; then
  echo "Desktop-Version ist $version. Dieses Sprachpaket gilt für 0.17.6." >&2
  exit 2
fi

if git -C "$ziel" apply --check "$patch" 2>/dev/null; then
  git -C "$ziel" apply "$patch"
  echo "Deutsche Locale eingespielt. Es wurde nicht gebaut."
  exit 0
fi

if git -C "$ziel" apply -R --check "$patch" 2>/dev/null; then
  echo "Der Patch ist schon eingespielt. Nichts geändert."
  exit 0
fi

echo "Der Patch passt nicht auf diesen Baum. Nichts geändert." >&2
echo "Geprüft wurde Desktop 0.17.6, Commit 6159bf4d87a32de72869e0b479606ddd2b9977a1." >&2
exit 2
