#!/bin/bash
# build-web.sh — Build dunge for the browser via ece-build.
#
# Usage: scripts/build-web.sh
#
# Env vars:
#   COMMIT_SHA  — override git SHA in version stamp (for CI)
#   BUILD_TIME  — override timestamp in version stamp (for CI)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "=== Dunge Web Build (ECE) ==="

# 1. Compile .scm sources into dist/ via ece-build
echo "Running ece-build..."
ece-build --target web --standalone -o dist/ \
  game/engine.scm \
  game/dice.scm \
  game/items.scm \
  game/combat.scm \
  game/bestiary.scm \
  game/content.scm \
  browser-boot.scm

# 2. Replace the default template with the custom game template
echo "Installing custom HTML template..."
cp web/index.html dist/index.html

# 3. Inject build version
SHA="${COMMIT_SHA:-$(git rev-parse --short HEAD)}"
TIME="${BUILD_TIME:-$(date -u +'%Y-%m-%d %H:%M UTC')}"
VERSION_STR="v ${SHA} &middot; ${TIME}"
echo "Build version: ${VERSION_STR}"

# Escape `&` and `|` for sed replacement (& is sed-special meaning "matched text")
VERSION_ESCAPED="$(printf '%s' "${VERSION_STR}" | sed -e 's/[&|]/\\&/g')"

# Use sed with an in-place backup for cross-platform compatibility (macOS + Linux)
sed -i.bak "s|BUILD_VERSION|${VERSION_ESCAPED}|g" dist/index.html
rm -f dist/index.html.bak

echo "=== Build complete: dist/index.html ==="
