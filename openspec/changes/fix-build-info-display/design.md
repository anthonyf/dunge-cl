## Context

`scripts/build-web.sh` has this block today (lines 33-34):

```bash
SHA="${COMMIT_SHA:-$(git rev-parse --short HEAD)}"
TIME="${BUILD_TIME:-$(date -u +'%Y-%m-%d %H:%M UTC')}"
```

The fallback path does the right thing (short SHA, UTC-formatted timestamp). The CI env-var path passes both values through verbatim:

- `${{ github.sha }}` is the full 40-char commit hash.
- `${{ github.event.head_commit.timestamp }}` is an ISO 8601 string with the committer's local TZ offset, e.g. `2026-04-10T23:22:07-04:00`.

Result on the live site as of commit `0f7fa77`:

```
v 0f7fa7723296ad4cbb910e7ab71f2e9e8d98490e · 2026-04-10T23:22:07-04:00
```

Expected (and what `ece-web-build/spec.md` uses as an example):

```
v 0f7fa77 · 2026-04-11 03:22 UTC
```

The script runs on both Linux (CI) and macOS (local dev). Linux ships GNU coreutils (`date -u -d`); macOS ships BSD `date` (`date -u -j -f`). Their input-parsing syntax is different, so any solution must handle both.

## Goals / Non-Goals

**Goals:**
- Normalize the embedded SHA to exactly 7 characters regardless of input source.
- Normalize the embedded timestamp to `YYYY-MM-DD HH:MM UTC` regardless of input source.
- Build continues to work on both Linux (CI) and macOS (local dev).
- Unknown/malformed `BUILD_TIME` values never break the build — they fall through to a passthrough that preserves the raw string.
- Tighten the `ece-web-build` spec so a future agent can't make the same drift without failing spec review.

**Non-Goals:**
- Changing the sed-based template replacement mechanism (the `BUILD_VERSION` placeholder substitution).
- Changing the overall shape of `build-web.sh`.
- Removing the env-var contract with CI; `COMMIT_SHA` and `BUILD_TIME` stay as the CI interface.
- Supporting formats other than ISO 8601 in `BUILD_TIME`. The passthrough handles the long tail without committing to parse them.

## Decisions

### 1. Always truncate to 7 chars, regardless of source

Rather than branching on where the SHA came from, read `COMMIT_SHA` (or fall through to `git rev-parse HEAD`) into `RAW_SHA`, then unconditionally slice `${RAW_SHA:0:7}`. This is symmetric, has no branches, and is bash-native (the script's shebang is `#!/bin/bash`).

**Alternative considered:** Use `git rev-parse --short=7` to let git do the truncation. Rejected because it requires a git invocation for the env-var path, which is wasted work and only works when `COMMIT_SHA` happens to be a valid git ref in the current checkout. String slicing is simpler.

### 2. Three-tiered timestamp parsing: GNU date → BSD date → passthrough

GNU `date -u -d` natively parses ISO 8601 with a colon-offset like `-04:00`. BSD `date -j -f '%z'` does not — it requires `-0400` (no colon). So the approach is:

1. Try GNU `date -u -d` first. Works on Linux/CI, fails silently on macOS (no `-d` flag).
2. Fall back to BSD `date -u -j -f '%Y-%m-%dT%H:%M:%S%z'` after pre-processing `BUILD_TIME` to strip the colon from the timezone offset via sed. Works on macOS, fails silently on Linux (no `-j` flag).
3. If both fail, pass the raw `BUILD_TIME` through to the version string. The build still succeeds; the footer just shows whatever the caller supplied.

**Alternative considered:** Use only GNU date and let macOS users install coreutils. Rejected — macOS is the primary dev environment for this project, and asking devs to `brew install coreutils` for a cosmetic footer is a bad trade.

**Alternative considered:** Write a tiny awk/sed parser for ISO 8601 and do the UTC conversion ourselves. Rejected — `date` already knows how to do timezone arithmetic correctly, and reinventing it for leap years, DST transitions, etc., is a mistake.

**Alternative considered:** Use Python or a node script. Rejected — adds a dependency on interpreter availability for a 3-line conversion.

### 3. Sed normalization for the colon-offset

BSD `date` needs `-0400`, CI sends `-04:00`. The sed expression:

```
s/([+-][0-9]{2}):([0-9]{2})$/\1\2/
```

...strips the colon from any trailing `±HH:MM` offset while leaving already-normalized `±HHMM` inputs alone. Verified on this macOS box:

- `2026-04-10T23:22:07-04:00` → `2026-04-10T23:22:07-0400` → parses cleanly
- `2026-04-10T23:22:07-0400` → unchanged → parses cleanly
- `2026-04-10T23:22:07+05:30` → `2026-04-10T23:22:07+0530` → parses cleanly

Trailing `Z` (UTC shorthand) is intentionally not normalized. BSD `date` can't parse `Z` either, but this isn't a concern because GitHub doesn't emit `Z` for `head_commit.timestamp` in practice; if it ever does, the passthrough catches it.

### 4. Spec tightening rather than spec preservation

The existing `ece-web-build` spec says:

> The build script SHALL read `COMMIT_SHA` and `BUILD_TIME` environment variables (for CI) or fall back to `git rev-parse --short HEAD` and current UTC time.

This is silent on what the env-var inputs should be normalized to — which is why the drift happened. The spec delta in this change replaces that requirement with two explicit constraints: a 7-char SHA and `YYYY-MM-DD HH:MM UTC` format, regardless of source. A new scenario ("CI-provided version info is normalized") locks it down.

## Risks / Trade-offs

- **[GNU date on the CI runner rejects GitHub's exact format]** → Extremely unlikely (colon-offset ISO 8601 is standard and `date -u -d` handles it), but if it happens the BSD path can't help (there's no `date -j` on Linux) and we'd fall to passthrough. The live site would show the raw ISO string until a follow-up patch, but the build wouldn't fail.
- **[BSD date sed normalization breaks some exotic offset format]** → Only the `[+-]HH:MM` colon form is handled. Any other format (`Z`, offset names, fractional seconds, etc.) falls through to passthrough. Acceptable: the passthrough is the safety net.
- **[The BSD branch is dead code in CI]** → True, but it costs nothing and it's the only way the macOS local path works. Keeping it documented and tested on macOS is worth it.
- **[Spec tightening could reject a valid future change]** → If a future change wants to use a different SHA length (e.g., 8 chars because of collisions) or a different timestamp format, the spec delta becomes an obstacle. Mitigation: that's the point of a spec. A future change should file its own proposal that modifies the spec again.

## Migration Plan

1. Merge the PR.
2. Deploy workflow runs automatically on push to main.
3. Verify the live-site footer shows the new format.
4. If anything is wrong, revert the PR — no data migration, no schema changes, nothing stateful to roll back.
