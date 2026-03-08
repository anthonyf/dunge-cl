## Context

The web build pipeline (`web-export.lisp`) produces a standalone `dist/index.html` with all JS inlined. The deploy workflow pushes `dist/` to `gh-pages` via `peaceiris/actions-gh-pages@v4`.

Three problems exist:
1. **Blank screen at `/`** — the deployed page renders nothing after a hard refresh. The JS renderer's `renderStep` has `if (!output || output === 'WAITING') return;` where an empty string `""` is falsy in JavaScript. Additionally, JSCL errors during boot can be silent (no console output), so a crash during ECE initialization could leave `*output-buffer*` empty.
2. **Stale files on gh-pages** — `keep_files: true` preserves old pre-ECE files (`dev/`, `dunge.js`, `jscl.js`, `test.html`, `tests.js`) that are never cleaned up.
3. **No version visibility** — no way to tell which build is deployed.

## Goals / Non-Goals

**Goals:**
- Fix the blank screen so the game renders correctly at `/`
- Remove stale files from gh-pages on each deploy
- Display a build identifier (git SHA + timestamp) in the browser UI

**Non-Goals:**
- Semantic versioning with manual major/minor/patch bumps — auto-deploys on every push to main make this impractical
- Changing game logic, ECE engine, or terminal REPL behavior
- Adding dev/staging deploy targets

## Decisions

### 1. Fix empty-string falsy check in JS renderer

**Decision:** Change `if (!output || output === 'WAITING') return;` to `if (output === null || output === undefined || output === 'WAITING') return;`

**Rationale:** The current check treats `""` as "no output" which is incorrect — an empty string is a valid (if unusual) output state. The check should only bail on `null`/`undefined` (no browserStep function yet) or the explicit `'WAITING'` sentinel.

### 2. Add console logging to browserStep for debugging

**Decision:** Add `console.log` calls around the `browserStep` call in the JS `step()` function to surface the raw output value. This helps diagnose whether the issue is in the ECE/JSCL runtime or the JS renderer.

**Rationale:** JSCL errors can be silent. Adding logging at the JS boundary makes it easy to see what `browserStep` actually returns, even when JSCL swallows errors.

### 3. Wrap ECE boot sequence in error handler

**Decision:** In `*browser-boot-source*`, wrap the boot sequence in a JSCL `handler-case` that catches `error` and logs to `console.error`. This surfaces any CL-level errors that JSCL would otherwise swallow.

**Alternative considered:** Using `try/catch` in the JS renderer — rejected because the error occurs inside JSCL's evaluation, not in the JS glue code.

### 4. Remove `keep_files: true` from deploy workflow

**Decision:** Delete the `keep_files: true` line from `.github/workflows/deploy.yml`.

**Rationale:** Each deploy should produce a clean gh-pages with only the current `dist/` contents. The `keep_files` option was likely set during initial setup to avoid clobbering a `dev/` directory that no longer exists. Removing it cleans up all stale files automatically.

### 5. Build version via git SHA + timestamp injected at build time

**Decision:** Pass `COMMIT_SHA` and `BUILD_TIME` into `web-export.lisp` via environment variables. Inject them into the HTML template as a small version string in the footer. In the deploy workflow, set these env vars from `${{ github.sha }}` and the current timestamp. For local builds, fall back to `git rev-parse --short HEAD` and current time.

**Alternative considered:** Auto-incrementing build number stored in a file — rejected because it requires committing a version file on each deploy, creating circular commits. Git SHA is already unique per deploy.

**Format:** `v <7-char-sha> · <YYYY-MM-DD HH:MM UTC>` displayed in small muted text at the bottom of the page.

## Risks / Trade-offs

- **Blank screen root cause may not be the falsy check alone** — the fix addresses the known JS-side issue, but if the root cause is a silent JSCL boot error, the error handler (Decision 3) and console logging (Decision 2) will surface it. If neither reveals an issue, the falsy-check fix alone should resolve it.
- **Removing `keep_files` is irreversible for old content** — any files currently on gh-pages that aren't in `dist/` will be deleted on next deploy. This is the desired behavior; the old files are stale.
- **Local builds won't match CI version format exactly** — local builds use `git rev-parse --short HEAD` while CI uses `${{ github.sha }}`. Both identify the commit; the format difference is cosmetic.
