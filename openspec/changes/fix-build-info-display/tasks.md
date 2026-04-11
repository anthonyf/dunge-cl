## 1. Edit build script

- [x] 1.1 Replace the `SHA=` / `TIME=` block in `scripts/build-web.sh` (lines 33-34) with: (a) read `COMMIT_SHA` or `git rev-parse HEAD` into `RAW_SHA`, slice to 7 chars via `${RAW_SHA:0:7}`; (b) if `BUILD_TIME` is set, try GNU `date -u -d`, then BSD `date -u -j -f '%Y-%m-%dT%H:%M:%S%z'` with sed-normalized colon-offset, then passthrough; if unset, `date -u +'%Y-%m-%d %H:%M UTC'`

## 2. Local verification

- [x] 2.1 `make clean && make build`, then `grep build-version dist/index.html` — confirm 7-char SHA and `YYYY-MM-DD HH:MM UTC` timestamp
- [x] 2.2 Simulate CI on macOS: `COMMIT_SHA=0f7fa7723296ad4cbb910e7ab71f2e9e8d98490e BUILD_TIME="2026-04-10T23:22:07-04:00" make build`, then `grep build-version dist/index.html` — confirm exactly `v 0f7fa77 · 2026-04-11 03:22 UTC` (exercises the BSD fallback path on macOS)
- [x] 2.3 Passthrough smoke test: `BUILD_TIME="not-a-timestamp" make build` — confirm build succeeds and the raw string appears in the footer
- [x] 2.4 Regression check: `make test` still shows 36 ran, 142 passed, 0 failed

## 3. Commit and PR

- [ ] 3.1 Create branch `fix-build-info-display`, commit the script change with a concise message
- [ ] 3.2 Push and open PR via `gh pr create`, reference this openspec change in the body
- [ ] 3.3 Wait for CI (`gh run watch`) — build-and-test job green
- [ ] 3.4 Squash-merge the PR

## 4. Deploy verification

- [ ] 4.1 After merge, wait for the deploy workflow to finish (`gh run list --branch main --limit 3`)
- [ ] 4.2 Reload the live site and confirm the footer shows `v <7-char> · YYYY-MM-DD HH:MM UTC` — the committer TZ no longer leaks

## 5. Archive the openspec change

- [ ] 5.1 `/opsx:archive fix-build-info-display` — move to `openspec/changes/archive/YYYY-MM-DD-fix-build-info-display/`, sync the spec delta into `openspec/specs/ece-web-build/spec.md`
