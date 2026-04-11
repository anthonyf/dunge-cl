## Context

The dunge text adventure game completed its migration from CL game logic to ECE (Scheme-based language) in a prior change. The game is 826 lines of pure ECE across 7 .scm files. However, all infrastructure remains in Common Lisp:

- **Terminal runner**: `qlot exec sbcl` → ASDF load → `ece:evaluate` bootstrap
- **Test runner**: `run-tests.lisp` (81 lines) — patches ECE display/newline at CL level, bridges `test-step` primitive
- **Web build**: `web-export.lisp` (573 lines) — loads JSCL, cross-compiles ECE to JS, generates standalone HTML with custom CSS/JS renderer
- **Dependencies**: qlot (qlfile/qlfile.lock), JSCL submodule (vendor/jscl/), ASDF system (dunge.asd)

ECE 0.1.0 now provides native replacements: `ece` CLI runs .scm files directly, `ece-build` produces web/test-page builds targeting WASM, and `ece-test` runs test suites with `ece-unit.scm` (output capture via R7RS `parameterize`/`open-output-string`).

The game .scm files use CL-isms (`nil` for false, `t` for true) that worked because they ran inside SBCL's CL environment. These must become standard Scheme (`#f`, `#t`) to run under the `ece` CLI.

## Goals / Non-Goals

**Goals:**
- Game runs directly via `ece game/main.scm` with zero CL dependency
- Tests run via `ece tests/run-all.scm` using ECE's `ece-unit.scm` framework
- Web build produces a playable standalone page via `ece-build --target web`
- All CL infrastructure files are deleted
- CI workflows use ECE toolchain

**Non-Goals:**
- Rewriting game logic — only symbol fixes (`nil`→`#f`, `t`→`#t`) in existing .scm files
- Adding new game features or tests
- Playwright web tests (deferred — test infrastructure exists but no test files yet)
- ECE formatter/linter to replace `make fmt` (no equivalent exists yet)
- Preserving backward compatibility with the CL-based workflow

## Decisions

### 1. Replace nil/t with #f/#t (not define compatibility aliases)

Replace all ~65 occurrences directly rather than adding `(define nil #f)` `(define t #t)` compatibility shims.

**Rationale:** Shims add runtime overhead and mask non-standard usage. Direct replacement is mechanical (all uses are boolean, none are empty-list) and produces idiomatic Scheme. The change is backward-compatible with the CL runner during transition since CL maps `#f`→NIL and `#t`→T.

### 2. Single test runner file (tests/run-all.scm) rather than ece-test auto-discovery

Create `tests/run-all.scm` that loads game files, defines helpers, loads test files, and runs tests — invoked as `ece tests/run-all.scm`.

**Alternative considered:** Use `ece-test tests/` with auto-discovery. Rejected because `ece-test` expects each file to be self-contained (loads and runs independently), but our test files depend on game files being pre-loaded and shared helpers (`test-step`, `with-fresh-state`). Making each test file self-contained would mean reloading all game files per test file, which is slow and fragile.

### 3. Pure ECE test-step via parameterize + open-output-string

Replace the CL-bridged `test-step` (which patches display/newline at CL level) with:

```scheme
(define (test-step input)
  (let ((port (open-output-string)))
    (parameterize ((current-output-port port))
      (browser-step input))
    (get-output-string port)))
```

**Rationale:** ECE's R7RS `parameterize` + `current-output-port` provides the same output capture that `run-tests.lisp` achieved by patching CL functions. This is cleaner and doesn't require any host-language bridge.

### 4. Custom HTML template separate from ece-build output

Keep a custom `web/index.html` with the game's CSS and JS renderer. The build script runs `ece-build` then replaces the generated generic template.

**Alternative considered:** Modify ece-build to support custom templates. Rejected because ece-build is a general-purpose tool; game-specific UI (choice buttons, keyboard nav, fade-in animations) doesn't belong in the SDK.

### 5. FFI callback for browser-step export

Use ECE's `js-callback` FFI to expose `browser-step` to JavaScript, wrapped in `guard` for CLI compatibility:

```scheme
(guard (e (#t #f))
  (js-set! (js-eval "window") "browserStep"
    (js-callback browser-step)))
```

**Rationale:** The `ffi.callback` mechanism in ECE's WASM runtime wraps Scheme procedures as callable JS functions. This is the idiomatic way to bridge Scheme→JS. The `guard` wrapper ensures this code is silently skipped in CLI mode where FFI functions aren't defined.

### 6. Version stamping via shell script post-processing

`scripts/build-web.sh` injects git SHA + timestamp via `sed` after `ece-build` completes, replacing a `BUILD_VERSION` placeholder in the custom template.

**Alternative considered:** Pass version info through ECE at build time. Rejected because `ece-build` has no mechanism for build-time variable injection, and post-processing is simpler.

## Risks / Trade-offs

**[call/cc in WASM for browser I/O]** → The game's browser interaction relies on `call/cc` to suspend/resume at `read-line`. ECE's WASM runtime supports continuations (assembler has `capture-continuation`, `do-continuation-winds`), and ECE's test suite includes call/cc tests. Mitigated by testing the web build early in implementation.

**[FFI API uncertainty]** → The exact Scheme-level FFI functions (`js-callback`, `js-set!`, `js-eval`) are defined in ECE's `browser-lib.scm` bootstrap but haven't been used in dunge before. Mitigated by verifying the API against ECE's own test suite and bootstrap code before implementing.

**[CI build time]** → Building ECE from source in CI requires SBCL + WASM toolchain, potentially adding minutes. Mitigated by caching the ECE install step. Long-term, pre-built ECE releases would eliminate this.

**[Web build size]** → Current JSCL build produces a 2.7MB single HTML file. ECE WASM standalone build produces ~7.5MB across multiple files. Trade-off accepted: WASM is the strategic direction, and assets compress well with gzip/brotli.

**[Integration test fidelity]** → `test-step` in pure ECE uses `parameterize` on `current-output-port`, which requires `display`/`newline` to respect the current output port. ECE's implementations do (standard R7RS behavior). If any game code uses low-level output primitives that bypass `current-output-port`, those tests would silently lose capture. Mitigated by running tests and comparing output against the CL runner before deleting it.

## Implementation Deltas

This section records where the merged implementation diverged from the design above. Preserved after archiving so future readers don't copy approaches that turned out to be wrong.

### 1. `test-step` uses a global display/newline override, not `parameterize`

**Design said:** "Pure ECE test-step via parameterize + open-output-string"

**What shipped:** A global override of `display` and `newline` gated by a `*in-test-step?*` flag, writing to a mutable `*test-output-buffer*`.

**Why it changed:** `parameterize` on `current-output-port` is implemented via `dynamic-wind`. When `browser-step` suspends via `call/cc` (inside `browser-read-line`) and is later resumed from a subsequent `test-step` call, `dynamic-wind` restores the dynamic extent from when the continuation was captured — including the `current-output-port` binding that pointed at the first step's (now abandoned) `open-output-string` port. All output after the resume routed to a stale port, so integration tests beyond the first step captured nothing. The first call works because nothing's been captured yet; the second call is where it breaks.

A mutable global buffer with direct `display`/`newline` overrides sidesteps the dynamic-wind path entirely — the continuation captures nothing output-related, so resumption does the right thing. The flag is reset in a `guard` so a failing test doesn't leave `*in-test-step?*` set to `#t` and swallow the final summary.

### 2. Browser FFI wrapper unwraps `js-ref` arguments

**Design said:**
```scheme
(guard (e (#t #f))
  (js-set! (js-eval "window") "browserStep"
    (js-callback browser-step)))
```

**What shipped:**
```scheme
(guard (e (#t #f))
  (js-set! (js-eval "window") "browserStep"
    (js-callback
      (lambda (js-input)
        (let ((input (if (js-null? js-input)
                         #f
                         (js-ref->string js-input))))
          (browser-step input))))))
```

**Why it changed:** FFI callbacks receive `js-ref` handles, not scheme strings. `js-callback` passes each JS argument through `%js-alloc` + `make-js-ref`, so the scheme procedure sees a `js-ref` value, not the unwrapped string. The browser-boot wrapper converts via `js-ref->string` (with a `js-null?` check for the initial `null` call).

**Historical note:** During implementation I initially believed `js-set!` had a WASM cast bug in ECE 0.1.0 — minimal test files built via `cat > foo.scm << 'EOF' ... (js-set! ...) ... EOF` consistently crashed the runtime with "illegal cast". This turned out to be a zsh heredoc quirk, not an ECE bug: history expansion runs before heredoc quoting, so `'EOF'` doesn't prevent zsh from inserting a literal `\` before `!`, producing `js-set\!` on disk. At bundle load, the unknown symbol looked up a null compiled-proc and the cast in `apply-primitive-procedure` failed (not in the `%js-set!` primitive at all). I cargo-culted a `js-call` → `_setWindowProp` workaround into `browser-boot.scm` and this design doc before the ECE maintainer traced the real cause. The workaround was reverted after the investigation — `js-set!` works correctly in ECE 0.1.0.

### 3. `browser-boot.scm` also calls `(init-player!)` and overrides `read-line`

**Design didn't mention it.** In terminal mode, `game/main.scm` loads the game files, calls `(init-player!)`, then calls `(start)`. The web build doesn't include `main.scm` (ece-build takes individual .scm files, not a loader), and tests use `with-fresh-state` per test. Without someone calling `init-player!` at load time, `*player*` is `#f` when `(start)` first runs, and `(character-name *player*)` triggers a hash-table cast error in WASM (or a clearer "hash-ref: not of type" in CLI).

Similarly, `read-line` defaults to stdin reading, which doesn't work in the browser. `browser-boot.scm` now does both at load time, so any consumer that loads `browser-boot.scm` (web build or test runner) gets the browser-friendly setup automatically.

### 4. Pre-existing `fmt`/`lines` breakage

**Not anticipated by the design at all.** The game extensively calls `(fmt ...)` and `(lines ...)`, but neither was defined anywhere — in ECE, in dunge, or in any deleted CL file. The old `qlot exec sbcl` runner was also broken at HEAD of `main` before this change started (same `Unbound variable: fmt` error). I added minimal `fmt`/`lines` definitions at the top of `game/engine.scm` (string-append with `write-to-string` coercion, and line-joined variant). Worth filing a separate issue to understand how the game was ever working.

### 5. `ECE_UNIT_PATH` env var for test runner portability

**Design didn't specify path resolution.** Hardcoding `~/.local/share/ece/ece-unit.scm` in `tests/run-all.scm` breaks for non-default ECE installs (Homebrew, Nix, custom `PREFIX`). Added an env var override so CI or users can point at a different location. Runtime probing of candidate paths was attempted but abandoned: ECE 0.1.0 surfaces `load` failures as CL-level conditions that escape scheme `guard`, so we can't fall through on missing files.
