# Dunge Development Guide

This guide collects the project architecture, development workflow, and ECE
runtime gotchas that used to live in agent-specific notes.

## Quick Reference

```bash
# First clone: git clone --recurse-submodules (ECE lives at vendor/ece/)
make ece       # first time: build the vendored ECE toolchain
make run       # terminal game: vendor/ece/bin/ece game/main.scm
make test      # run all ECE tests
make build     # web build, producing dist/
make serve     # live browser dev server on http://127.0.0.1:8080
make ece-clean # clean the vendored ECE build
make clean     # remove dist/
```

`make run`, `make test`, `make build`, and `make serve` all depend on the
in-tree ECE tools and will build the submodule on first use when needed.

## ECE Toolchain

ECE is vendored as a git submodule at `vendor/ece/`, pinned to a specific
commit. The Makefile builds ECE in place via `make ece`, which delegates to
ECE's own Makefile with `make -C vendor/ece`.

The resulting tools are invoked from the repository:

- `vendor/ece/bin/ece`
- `vendor/ece/bin/ece-build`
- `vendor/ece/bin/ece-serve`

Dunge does not use a globally installed `ece` for normal development, tests,
or builds. The submodule pointer is the source of truth for the ECE version
used by local development, CI, and historical checkouts. CI caches the built
ECE output keyed on the submodule SHA.

Build-time prerequisites for rebuilding the ECE submodule are SBCL, qlot, and
binaryen (`wasm-as` >= 129). Once `vendor/ece/bin/ece` exists, everyday Dunge
commands do not invoke those tools directly.

## Source Layout

All game code is ECE Scheme in `game/*.scm` plus `browser-boot.scm`. Common
Lisp, ASDF, qlot, and other ECE implementation details are confined to the
vendored ECE submodule.

Source files load in this order via `game/main.scm` for terminal play,
`web/main.scm` for `ece-serve`, or `scripts/build-web.sh` for standalone web
builds:

1. `game/engine.scm` - player record, display helpers, choices, prompts
2. `game/dice.scm` - dice rolling
3. `game/items.scm` - item records and inventory helpers
4. `game/combat.scm` - Cairn combat system
5. `game/bestiary.scm` - enemy data
6. `game/content.scm` - backgrounds, character creation, town rooms
7. `game/main.scm` - terminal entrypoint only
8. `browser-boot.scm` - browser/test continuation bridge

`browser-boot.scm` is loaded by the web build, `web/main.scm`, and the test
runner. It is not loaded by `game/main.scm`.

## Browser Flow

The game is written as mutually recursive Scheme procedures that use
`display`/`newline` for output and `read-line` through helpers such as
`read-choice` and `ask` for input.

In terminal mode, `read-line` reads from stdin. In browser and test mode,
`browser-boot.scm` replaces `read-line` with `browser-read-line`, which
captures a continuation and yields back to `browser-step`. The next
`browser-step` call resumes that continuation with the user's input.

`browser-boot.scm` provides:

- `*top-continuation*` and `*resume-continuation*`
- `browser-step`
- `browser-read-line`
- load-time `read-line` override
- load-time `(init-player!)`
- guarded browser FFI registration for `window.browserStep`

## Web Build And Dev Server

`scripts/build-web.sh` runs `ece-build --target web --standalone` on the game
files and `browser-boot.scm`, producing:

- `dist/app.ecec`
- `dist/app.js`
- `dist/ece-runtime.js`
- `dist/ece-bootstrap.js`
- `dist/index.html`

The script then replaces the generic ECE `index.html` with `web/index.html`
and stamps in a build version.

For live browser development, `make serve PORT=8080` runs `ece-serve` from the
`web/` directory. `web/main.scm` is the browser-dev entrypoint; it loads the
game files and `../browser-boot.scm`. `make web-dev-assets` copies the ignored
runtime assets needed by `ece-serve` into `web/`.

## Tests

`tests/run-all.scm` loads ECE's `ece-unit.scm`, loads the game files plus
`browser-boot.scm`, defines integration helpers, loads each test file, and
calls `run-tests`.

`make test` sets `ECE_UNIT_PATH=vendor/ece/src/ece-unit.scm`, so the test
runner does not need a globally installed ECE share directory.

The test helper `test-step` captures output with a mutable buffer and an
`*in-test-step?*` flag. Do not replace this with `parameterize` on
`current-output-port`: captured continuations can be resumed in later steps,
and `dynamic-wind` would restore a stale port.

## Project Conventions

- Use Scheme booleans `#t` and `#f`, not Common Lisp `t` or `nil`.
- `game/main.scm` is the terminal entrypoint; web builds, `ece-serve`, and
  tests do not load it.
- `web/main.scm` is the `ece-serve` entrypoint. Run it from `web/` so its
  relative load paths and static root line up.
- `browser-boot.scm` is loaded by the web build, `web/main.scm`, and tests,
  never by terminal-mode code.
- Background equipment uses thunks so each playthrough receives fresh item
  records.
- Use `fmt` or ECE string interpolation for mixed-type strings rather than
  manual `string-append` plus `write-to-string`.

## Verification

After game logic, build, or browser changes, run:

```bash
make test
make build
```

Use `npm run test:web` when browser behavior changed and Playwright is
available.

Before committing, check:

```bash
git diff --check
git diff --cached --check
git status
```

## Bumping ECE

ECE is pinned via the `vendor/ece/` submodule. Update it with:

```bash
cd vendor/ece
git fetch origin
git checkout <new-sha>
cd ../..
make ece
make test
make build
make serve        # optional live browser smoke check
git add vendor/ece
git commit -m "Bump ECE to <new-sha>"
```

Do not update ECE by editing another checkout such as `~/git/ece/`, and do not
use `make install` in a separate checkout as a substitute for updating the
submodule. Dunge ignores anything outside `vendor/ece/` during normal builds.

## ECE Web Build Gotchas

### Zsh heredocs can corrupt Scheme symbols

Authoring `.scm` files through a zsh heredoc can corrupt `!` in symbols.
History expansion runs before heredoc quoting takes effect, so a heredoc that
contains `(js-set! ...)` can write `js-set\!` to disk.

Symptom: at bundle load, the unknown symbol dispatches to a null compiled proc
and WebAssembly reports an illegal `ref.cast` at a location that looks
unrelated to the symbol.

Diagnose with:

```bash
od -c file.scm | grep "\\\\"
```

Workaround: use an editor or patch tool for `.scm` edits, or disable zsh
history expansion.

### FFI callbacks receive JS refs

ECE FFI callbacks receive arguments as `js-ref` handles, not Scheme strings.
Unwrap with `(js-ref->string ref)` before using values as strings, and check
for JS `null` with `(js-null? ref)`.

### Initialize the player in browser/test mode

`(init-player!)` must run at load time for browser builds and tests. Terminal
mode does this in `game/main.scm`; browser and test mode do it in
`browser-boot.scm`.

If `*player*` remains `#f`, `character-*` accessors can fail as an illegal cast
in WebAssembly or as a clearer hash/type error in the CLI.

### Override read-line in browser/test mode

Browser and test mode must override `read-line` with `browser-read-line` so the
game's prompt flow captures continuations instead of reading from stdin.
`browser-boot.scm` handles this. Do not load it from terminal-mode code.

### FFI callback return values are internal handles

Return values from ECE FFI callbacks are not marshalled through `_eceToJs`.
JavaScript sees an internal handle integer. Do not rely on callback return
values; communicate through side effects such as display output captured by the
browser renderer.
