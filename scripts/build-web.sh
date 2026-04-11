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
#
# Normalize to a 7-char SHA and a `YYYY-MM-DD HH:MM UTC` timestamp regardless
# of whether values come from env vars (CI) or the local fallbacks. Without
# this, CI's ${{ github.sha }} (40 chars) and ${{ github.event.head_commit.timestamp }}
# (ISO 8601 with the committer's local TZ offset) leak into the footer.
RAW_SHA="${COMMIT_SHA:-$(git rev-parse HEAD)}"
SHA="${RAW_SHA:0:7}"

if [ -n "${BUILD_TIME:-}" ]; then
  # Tier 1: GNU date (Linux/CI). Parses colon-offset ISO 8601 directly.
  set +e
  TIME="$(date -u -d "${BUILD_TIME}" +'%Y-%m-%d %H:%M UTC' 2>/dev/null)"
  rc=$?
  set -e
  if [ $rc -ne 0 ] || [ -z "${TIME}" ]; then
    # Tier 2: BSD date (macOS). Needs `±HHMM`, so strip the colon from `±HH:MM`.
    BUILD_TIME_NORM="$(printf '%s' "${BUILD_TIME}" | sed -E 's/([+-][0-9]{2}):([0-9]{2})$/\1\2/')"
    set +e
    TIME="$(date -u -j -f '%Y-%m-%dT%H:%M:%S%z' "${BUILD_TIME_NORM}" +'%Y-%m-%d %H:%M UTC' 2>/dev/null)"
    rc=$?
    set -e
    if [ $rc -ne 0 ] || [ -z "${TIME}" ]; then
      # Tier 3: passthrough — preserve the raw string rather than fail the build.
      TIME="${BUILD_TIME}"
    fi
  fi
else
  TIME="$(date -u +'%Y-%m-%d %H:%M UTC')"
fi

VERSION_STR="v ${SHA} &middot; ${TIME}"
echo "Build version: ${VERSION_STR}"

# Escape `&` and `|` for sed replacement (& is sed-special meaning "matched text")
VERSION_ESCAPED="$(printf '%s' "${VERSION_STR}" | sed -e 's/[&|]/\\&/g')"

# Use sed with an in-place backup for cross-platform compatibility (macOS + Linux)
sed -i.bak "s|BUILD_VERSION|${VERSION_ESCAPED}|g" dist/index.html
rm -f dist/index.html.bak

echo "=== Build complete: dist/index.html ==="
