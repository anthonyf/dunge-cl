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
