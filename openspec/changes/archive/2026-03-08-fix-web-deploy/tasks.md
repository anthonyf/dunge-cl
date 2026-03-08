## 1. Fix blank screen rendering

- [x] 1.1 Fix the falsy empty-string check in `*js-renderer*` — change `if (!output || output === 'WAITING') return;` to `if (output === null || output === undefined || output === 'WAITING') return;`
- [x] 1.2 Add `console.log` in the JS `step()` function to log the raw `browserStep` return value before calling `renderStep`
- [x] 1.3 Wrap the ECE boot sequence in `*browser-boot-source*` with a `handler-case` that catches errors and logs them to `console.error`

## 2. Clean up deploy pipeline

- [x] 2.1 Remove `keep_files: true` from `.github/workflows/deploy.yml`

## 3. Add build version display

- [x] 3.1 Add version injection to `web-export.lisp` — read `COMMIT_SHA` and `BUILD_TIME` from environment variables (falling back to `git rev-parse --short HEAD` and current time), inject into the HTML template as a small muted footer element
- [x] 3.2 Set `COMMIT_SHA` and `BUILD_TIME` environment variables in `.github/workflows/deploy.yml` before the build step

## 4. Verify

- [x] 4.1 Run `make build` locally and verify `dist/index.html` contains the version footer and the renderer fix
