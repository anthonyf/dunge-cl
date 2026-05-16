## 1. Fix Scheme Booleans

- [x] 1.1 Replace `nil` with `#f` and `t` with `#t` in `game/engine.scm` (12 changes)
- [x] 1.2 Replace `nil` with `#f` and `t` with `#t` in `game/combat.scm` (22 changes)
- [x] 1.3 Replace `nil` with `#f` in `game/content.scm` and `game/items.scm` (2 changes)
- [x] 1.4 Replace `nil` with `#f` in `browser-boot.scm` (2 changes)
- [x] 1.5 Verify game runs: `ece game/main.scm` starts without "Unbound variable" errors (also required adding `fmt`/`lines` definitions to `game/engine.scm` — pre-existing bug: these were undefined in the game code)

## 2. Port Test Infrastructure

- [x] 2.1 Create `tests/run-all.scm` — load game files, browser-boot, define `test-step` (buffer-based capture via display/newline override — parameterize+call/cc interaction breaks across test-step calls), define `with-fresh-state`, wire `read-line` to `browser-read-line`
- [x] 2.2 Port `tests/unit/test-dice.scm` — `define-test` → `test` + lambda, `assert` → `assert-true`
- [x] 2.3 Port `tests/unit/test-items.scm` — same API changes
- [x] 2.4 Port `tests/unit/test-combat.scm` — same API changes, fix `nil`→`#f` and `t`→`#t` (~15 changes)
- [x] 2.5 Port `tests/integration/test-char-creation.scm` — fix `nil`→`#f`, update API
- [x] 2.6 Port `tests/integration/test-navigation.scm` — fix `nil`→`#f`, update API
- [x] 2.7 Verify all tests pass: `ece tests/run-all.scm` exits 0 (36 tests, 142 assertions, 0 failures)

## 3. Update Makefile and Terminal Runner

- [x] 3.1 Replace Makefile with ECE-based targets: `run` (`ece game/main.scm`), `test` (`ece tests/run-all.scm`), `build` (`scripts/build-web.sh`), `clean` (`rm -rf dist/`)
- [x] 3.2 Remove `fmt`, `check-fmt`, `setup` targets and `LISP_FILES`/`ROOT_DIR` variables
- [x] 3.3 Verify `make run` and `make test` work

## 4. Web Build

- [x] 4.1 Update `browser-boot.scm` — add FFI export of `browser-step` to `window.browserStep` via `js-callback`, wrapped in `guard` for CLI safety. Also added `read-line` → `browser-read-line` override and `(init-player!)` call (previously done by `game/main.scm` in terminal mode). Worked around ECE 0.1.0 `js-set!` WASM cast bug by using `js-call` on a pre-defined `_setWindowProp` helper.
- [x] 4.2 Create `web/index.html` — port CSS and JS renderer from `web-export.lisp`, load ece-build's JS files, override ECE.io for output buffering, use `window.browserStep` for game stepping. Pre-installs `window._setWindowProp` helper before ECE bundle loads (js-set! workaround).
- [x] 4.3 Create `scripts/build-web.sh` — run `ece-build --target web --standalone`, copy custom template, inject version stamp (escapes `&` for sed replacement).
- [x] 4.4 Verify web build: `make build` produces playable `dist/index.html` — verified via Node.js WASM harness: welcome screen → continue → name prompt → name entry all work.

## 5. Update CI Workflows

- [x] 5.1 Update `.github/workflows/ci.yml` — install ECE via `git clone` + `make install`, run `ece tests/run-all.scm`, run `scripts/build-web.sh`
- [x] 5.2 Update `.github/workflows/deploy.yml` — same ECE install, pass `COMMIT_SHA`/`BUILD_TIME` env vars to build script

## 6. Delete CL Infrastructure

- [x] 6.1 Remove JSCL submodule: `git submodule deinit vendor/jscl && git rm vendor/jscl`, delete `.gitmodules`
- [x] 6.2 Delete CL files: `dunge.asd`, `qlfile`, `qlfile.lock`, `src/ece-bootstrap.lisp`, `web-export.lisp`, `run-tests.lisp`
- [x] 6.3 Delete CL-specific scripts: `scripts/cl-indent.el`, `scripts/pre-commit`
- [x] 6.4 Delete old test harness: `tests/test-harness.scm`
- [x] 6.5 Clean up stale files: `dunge.fasl`, `room.fasl`
- [x] 6.6 Verify `make test && make build` still work after deletion (36 tests pass, web build boots and runs correctly)

## 7. Update Documentation

- [x] 7.1 Update the development notes — remove CL-specific rules, formatting section, JSCL gotchas; update architecture, quick reference, conventions for pure ECE. Added ECE web build gotchas section covering the `js-set!` bug, FFI js-ref unwrapping, `init-player!` placement, `read-line` override, parameterize+call/cc pitfall, and `ece-unit.scm` path.
