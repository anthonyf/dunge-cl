## Why

The live web-build footer currently shows `v 0f7fa7723296ad4cbb910e7ab71f2e9e8d98490e · 2026-04-10T23:22:07-04:00` — the full 40-char commit SHA and an ISO 8601 timestamp with the committer's local timezone offset. This doesn't match the format example in the `ece-web-build` spec (`v abc1234 · 2026-04-09 12:00 UTC`), is inconsistent with what local `make build` produces, and leaks the committer's timezone on every deploy. The implementation drifted from the spec during the drop-cl-pure-ece migration; this change brings it back in line.

## What Changes

- `scripts/build-web.sh` normalizes `COMMIT_SHA` (from CI's `${{ github.sha }}`, which is 40 chars) to a 7-character short SHA before embedding, so CI builds and local builds are consistent.
- `scripts/build-web.sh` parses `BUILD_TIME` (from CI's `${{ github.event.head_commit.timestamp }}`, an ISO 8601 string with local TZ offset) and reformats it to `YYYY-MM-DD HH:MM UTC`. GNU `date -u -d` handles this on Linux/CI; a BSD `date -j -f` fallback (with sed-based colon stripping) handles macOS local overrides. A passthrough fallback ensures unknown formats never break the build.
- No behavior change for `make build` with no env vars set — that path still uses `date -u +...` and `git rev-parse HEAD`, just with explicit 7-char truncation.

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `ece-web-build`: tighten the "Build version stamping" requirement to mandate a 7-char SHA and `YYYY-MM-DD HH:MM UTC` timestamp regardless of which environment variable supplies the value. The current spec only specifies the fallback behavior; it's silent on what the env-var inputs should be normalized to, which is how the implementation drifted.

## Impact

- Single script change: `scripts/build-web.sh` (~15 lines touched).
- Spec update: `openspec/specs/ece-web-build/spec.md` — one requirement modified, one new scenario added.
- Live site footer format changes on next deploy (cosmetic, no breaking changes for users).
- No changes to `game/**`, CI workflows, tests, or the build pipeline itself.
- Removes a minor info-leak (committer timezone visible in the footer).
