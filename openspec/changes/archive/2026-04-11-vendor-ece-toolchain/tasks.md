## 1. Add ECE as a submodule

- [x] 1.1 Determine the initial pin SHA (use the current `~/git/ece/` HEAD, or the commit the user last `make install`'d — verify with `ece --version` / `git -C ~/git/ece rev-parse HEAD`)
- [x] 1.2 `git submodule add https://github.com/anthonyf/ece.git vendor/ece`
- [x] 1.3 `cd vendor/ece && git checkout <pin SHA>` if HEAD isn't already there; `cd ../.. && git add vendor/ece .gitmodules`
- [x] 1.4 Verify `.gitmodules` was created with the correct URL and path
- [x] 1.5 Confirm `git submodule status` shows the pin

## 2. Build ECE from the submodule

- [x] 2.1 Ensure SBCL, qlot, and binaryen (wasm-as) are installed locally
- [x] 2.2 `cd vendor/ece && qlot install && make` — verify `vendor/ece/bin/ece` and `vendor/ece/bin/ece-build` exist and run
- [x] 2.3 Verify `vendor/ece/bin/ece --version` (or an equivalent smoke test) matches the pinned SHA
- [x] 2.4 Verify `vendor/ece/src/ece-unit.scm` exists (needed by the test runner) — original plan expected `share/ece/ece-unit.scm`, but `share/` is only populated by `make install`, which is not run on the submodule. The Makefile points `ECE_UNIT_PATH` at the in-tree source path instead.

## 3. Rewrite Makefile

- [x] 3.1 Add `ECE_DIR`, `ECE`, `ECE_BUILD` path variables pointing at `vendor/ece/`
- [x] 3.2 Add `ece` target that builds the submodule via `$(MAKE) -C $(ECE_DIR)`
- [x] 3.3 Add the submodule-initialized guard to the ECE build recipe (clear error message, non-zero exit)
- [x] 3.4 Change `run`, `test`, `build` to depend on the in-tree ECE binary and invoke it by path
- [x] 3.5 Add optional `ece-clean` target forwarding to `$(MAKE) -C $(ECE_DIR) clean`
- [x] 3.6 Verify `make test` from a fresh state triggers ECE build then runs tests
- [x] 3.7 Verify `make test` from a built state skips ECE rebuild
- [x] 3.8 Verify `make build` produces `dist/` with the same contents as today

## 4. Update build-web.sh to accept ECE_BIN

- [x] 4.1 Change `scripts/build-web.sh` to invoke `${ECE_BIN:-ece-build}` instead of hardcoded `ece-build`
- [x] 4.2 Verify the script still works standalone (no ECE_BIN set) for anyone with a global ece-build
- [x] 4.3 Verify the script works when invoked by `make build` with `ECE_BIN` pointing at the submodule

## 5. Tests: path resolution for ece-unit.scm

- [x] 5.1 Check how `tests/run-all.scm` locates `ece-unit.scm` (hardcoded path or `ECE_UNIT_PATH` env var — see archived change doc)
- [x] 5.2 If hardcoded to `~/.local/share/ece/`, either: pass `ECE_UNIT_PATH=$(ECE_DIR)/src/ece-unit.scm` from the Makefile, OR update `run-all.scm` to probe `vendor/ece/src/` first
- [x] 5.3 Verify `make test` locates and loads `ece-unit.scm` from the submodule path, not from `~/.local/`

## 6. Update CI workflows

- [x] 6.1 `.github/workflows/ci.yml` — change `actions/checkout` to `submodules: recursive`
- [x] 6.2 Remove inline `git clone ece` / `qlot install` / `make install` steps (replaced by submodule)
- [x] 6.3 Add "Compute ECE submodule SHA" step that exports the submodule HEAD SHA to `$GITHUB_OUTPUT`
- [x] 6.4 Add `actions/cache@v4` step caching `vendor/ece/bin`, `vendor/ece/share`, `vendor/ece/.qlot`, `vendor/ece/.fasl-cache`, keyed on OS + submodule SHA
- [x] 6.5 Keep SBCL + qlot + binaryen install steps (still needed on cache miss), but add a comment explaining they exist to build ECE, not Dunge
- [x] 6.6 Replace direct `ece tests/run-all.scm` / `scripts/build-web.sh` invocations with `make test` / `make build`
- [x] 6.7 Mirror all changes in `.github/workflows/deploy.yml` (keep `COMMIT_SHA` / `BUILD_TIME` env vars)
- [ ] 6.8 Open a test PR to confirm: cache cold → ECE builds, tests pass, build succeeds; re-run → cache hot, ECE build skipped

## 7. Delete stale CL-era files

- [x] 7.1 `git rm setup-vps.sh`
- [x] 7.2 Remove the `make-room` indent rule from `.dir-locals.el`; if the file becomes empty, delete it
- [x] 7.3 Verify nothing else in the repo references `setup-vps.sh` (grep)

## 8. Rewrite README.org

- [x] 8.1 Update the one-line description to drop "Scheme on Common Lisp" framing
- [x] 8.2 Rewrite the Dependencies section to list: ECE (as submodule), SBCL + qlot + binaryen (build-time, to build the submodule), Make, Node + Playwright (web tests)
- [x] 8.3 Remove references to JSCL and `vendor/jscl/`
- [x] 8.4 Rewrite Quick Start: `git clone --recurse-submodules`, `make ece` (first time), `make run` / `make test` / `make build`
- [x] 8.5 Remove `make fmt`, `make setup` from the Makefile target list; they don't exist anymore
- [x] 8.6 Remove the "Remove ASDF cache, .fasl files" language from `make clean`
- [x] 8.7 Add a short note on the submodule model and how to bump ECE

## 9. Update CLAUDE.md

- [x] 9.1 Add an "ECE toolchain" subsection under Architecture describing: submodule at `vendor/ece/`, Makefile builds in-tree, `make ece` target, single source of truth
- [x] 9.2 Add a "Bumping ECE" subsection under Rules or Conventions: `cd vendor/ece && git fetch && git checkout <sha> && cd ../.. && make ece && make test && git add vendor/ece && git commit`
- [x] 9.3 Remove any stale references to "install ECE globally" or "`ece` on `$PATH`" in existing CLAUDE.md sections
- [x] 9.4 Add a rule: "Do not `apt install` or otherwise install ECE globally when working on Dunge — it must build from the submodule"

## 10. Full verification

- [ ] 10.1 Fresh-clone simulation: in a scratch directory, `git clone --recurse-submodules <dunge>`, `make test`, confirm ECE builds and tests pass
- [x] 10.2 Fresh-clone without submodules: `git clone <dunge>` (no `--recurse-submodules`), `make test`, confirm the Makefile's submodule guard fires with a clear error
- [x] 10.3 `make build` produces `dist/` identical (modulo version stamp) to a pre-change build
- [x] 10.4 `make run` starts the game in the terminal
- [ ] 10.5 CI workflow run on the change PR: first run populates cache, second run hits cache
- [x] 10.6 Confirm `setup-vps.sh` is gone and nothing references it
- [ ] 10.7 Confirm the README quick-start instructions actually work when followed verbatim
