## Why

The game logic is already 100% ECE (826 lines of .scm files). All remaining Common Lisp is infrastructure: ASDF system definition, qlot dependency management, test runner (`run-tests.lisp`), web build (`web-export.lisp`), JSCL submodule, and a thin bootstrap wrapper. ECE 0.1.0 now ships with `ece` (CLI runner), `ece-build` (web/test-page targets), and `ece-test` (test runner with `ece-unit.scm` framework) — providing native replacements for every piece of CL infrastructure. Removing the CL layer eliminates ~600 lines of build/test scaffolding, the JSCL submodule, and the qlot dependency chain.

## What Changes

- **BREAKING**: `make run` changes from `qlot exec sbcl` to `ece game/main.scm` — SBCL is no longer required
- **BREAKING**: `make test` changes from `sbcl --load run-tests.lisp` to `ece tests/run-all.scm`
- **BREAKING**: `make build` changes from `sbcl --load web-export.lisp` (JSCL) to `ece-build --target web` (WASM)
- Fix `nil` → `#f` and `t` → `#t` in all .scm files (~65 boolean occurrences) — ECE is Scheme-based and doesn't define CL symbols
- Port test files from custom `test-harness.scm` API to ECE's built-in `ece-unit.scm` API (`test`, `assert-true`, `assert-equal`)
- Replace CL-bridged `test-step` primitive with pure ECE implementation using `parameterize` + `open-output-string`
- Create custom `web/index.html` template preserving game CSS/JS renderer from `web-export.lisp`
- Update `browser-boot.scm` to export `browser-step` to JavaScript via ECE's FFI (`js-callback`)
- Update CI workflows to install ECE instead of SBCL
- Delete all CL infrastructure: `dunge.asd`, `qlfile`, `qlfile.lock`, `src/`, `web-export.lisp`, `run-tests.lisp`, `vendor/jscl/`, `.gitmodules`, `scripts/cl-indent.el`, `scripts/pre-commit`, `tests/test-harness.scm`
- Remove `fmt`, `check-fmt`, `setup` Makefile targets (CL-specific formatting)

## Capabilities

### New Capabilities

- `ece-cli-runner`: Terminal game execution via `ece game/main.scm` — direct ECE CLI replaces SBCL+ASDF bootstrap
- `ece-test-runner`: Pure ECE test infrastructure — `tests/run-all.scm` with ECE-native output capture replaces CL-bridged `run-tests.lisp`
- `ece-web-build`: WASM-based web build via `ece-build` with custom game template — replaces JSCL-based `web-export.lisp`

### Modified Capabilities

- `ece-web-export`: Web build mechanism changes from JSCL (JS) to ECE WASM runtime; `browser-boot.scm` adds FFI export of `browser-step`

## Impact

- **Runtime dependency**: SBCL + qlot + JSCL → ECE only
- **Web technology**: JavaScript (JSCL-compiled) → WebAssembly (ECE WASM runtime)
- **CI**: Workflows need ECE installation instead of SBCL
- **Build output**: Single monolithic `index.html` (2.7MB JSCL) → `index.html` + JS/WASM files (~7MB standalone)
- **Test API**: `define-test`/`assert` → `test`/`assert-true`/`assert-equal` (ece-unit.scm)
- **Removed files**: ~15 CL-specific files and directories
- **Developer setup**: No more `make setup` for pre-commit hooks, no more `make fmt` for CL indentation
