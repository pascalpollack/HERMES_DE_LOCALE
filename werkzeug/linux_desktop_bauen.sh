#!/usr/bin/env bash
# Baut Hermes Desktop 0.17.6 plus den deutschen Patch aus diesem Repo.
# Upstream wird nach OUT geklont und nicht in dieses Repo kopiert.
#
# Benutzung:
#   werkzeug/linux_desktop_bauen.sh /tmp/hermes-desktop-build
#
# Erwartet Node ^22.22.0 || ^24.11.0 || >=26, npm <11.10 || >=11.17,
# und die üblichen Compilerwerkzeuge (python3, make, g++).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-/tmp/hermes-desktop-build}"
COMMIT="6159bf4d87a32de72869e0b479606ddd2b9977a1"
PATCH="$ROOT/0001-hermes-desktop-german-locale.patch"
URL="https://github.com/NousResearch/hermes-agent.git"

mkdir -p "$OUT"
if [[ ! -d "$OUT/hermes-agent/.git" ]]; then
  git clone --filter=blob:none "$URL" "$OUT/hermes-agent"
fi

git -C "$OUT/hermes-agent" cat-file -t "$COMMIT" >/dev/null
git -C "$OUT/hermes-agent" worktree add --detach "$OUT/build" "$COMMIT"

cd "$OUT/build"
test "$(git rev-parse HEAD)" = "$COMMIT"
python3 - << 'PY'
import json
p = json.load(open("apps/desktop/package.json"))
assert p["version"] == "0.17.6", p["version"]
assert p["devDependencies"]["electron"] == "40.10.2"
assert p["devDependencies"]["electron-builder"] == "26.15.3"
print("desktop", p["version"], "electron", p["devDependencies"]["electron"])
PY

git apply --check "$PATCH"
git apply "$PATCH"

npm ci --workspace=apps/desktop --include-workspace-root --no-audit --no-fund
cd apps/desktop
npx tsc --noEmit
npx vitest run src/i18n
NODE_OPTIONS=--max-old-space-size=6144 npm run build
NODE_OPTIONS=--max-old-space-size=8192 node scripts/run-electron-builder.mjs --linux AppImage deb

echo "Pakete:"
ls -lh release/Hermes-0.17.6-linux-x86_64.AppImage release/Hermes-0.17.6-linux-amd64.deb release/linux-unpacked/Hermes
sha256sum release/Hermes-0.17.6-linux-x86_64.AppImage release/Hermes-0.17.6-linux-amd64.deb release/linux-unpacked/Hermes
