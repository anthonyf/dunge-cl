## Why

The GitHub Pages deployment has three problems:
1. **Blank screen at `/`** — the standalone `index.html` loads without JS errors but renders nothing. The JS renderer's `renderStep` bails early when `!output` is truthy, and an empty string `""` is falsy in JavaScript. If the ECE output buffer is empty (e.g., `ece-display` isn't writing to it correctly in the JSCL runtime), the game shows a blank page.
2. **Stale `/dev` content** — `keep_files: true` in the deploy workflow preserves old pre-ECE files (`dev/`, `dunge.js`, `jscl.js`, `test.html`, `tests.js`) that are never cleaned up.
3. **No way to verify which version is deployed** — there's no build version visible in the UI, making it hard to tell if a deploy actually updated the page.

## What Changes

- **Diagnose and fix the blank screen**: Add console logging to the JS renderer to surface what `browserStep` returns. Fix the falsy-empty-string check in `renderStep`. Investigate and fix why the output buffer may be empty at runtime.
- **Clean up gh-pages**: Remove `keep_files: true` from the deploy workflow so stale files are cleaned on each deploy.
- **Add build version**: Inject git commit SHA and build timestamp into the HTML at build time, displayed as a small version string in the UI.

## Capabilities

### New Capabilities

- `web-version-display`: Display build version (git SHA + timestamp) in the browser UI

### Modified Capabilities

- `ece-web-export`: Fix blank screen rendering and clean up deploy pipeline

## Impact

- `web-export.lisp` — add version injection into HTML template, add debug logging to JS renderer, fix empty-string rendering check
- `.github/workflows/deploy.yml` — remove `keep_files: true`, pass commit SHA to build
- No changes to game logic or ECE engine
