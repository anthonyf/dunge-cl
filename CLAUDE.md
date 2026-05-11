# Dunge — Text Adventure Engine in ECE

See also: [README.org](README.org) | [DESIGN.md](DESIGN.md) — full game design document (Cairn rules, oracle system, dungeon generation)

## Quick Reference

```bash
# First clone: git clone --recurse-submodules (ECE lives at vendor/ece/)
make ece       # First time: build the vendored ECE toolchain (slow)
make run       # Terminal game: vendor/ece/bin/ece game/main.scm
make test      # Run all tests
make build     # Web build (produces dist/)
make serve     # Live browser dev server via vendor/ece/bin/ece-serve
make ece-clean # Clean the vendored ECE build
make clean     # Remove dist/

# Serve web build from remote VPS (run from local machine)
ssh -L 8080:localhost:8080 user@your-vps "python3 -m http.server 8080 --directory /home/dev/git/dunge-cl/dist/"
# Then open http://localhost:8080
```

ECE is vendored as a git submodule at `vendor/ece/`, pinned to a specific commit. Dunge's Makefile builds ECE by running plain `make` in `vendor/ece/`, then invokes the resulting in-tree `vendor/ece/bin/ece`, `vendor/ece/bin/ece-build`, and `vendor/ece/bin/ece-serve` — it does not use any globally-installed ECE. Build-time prerequisites for the submodule build: SBCL, qlot, binaryen (`wasm-as` ≥ 129).

## Architecture

**ECE toolchain:** ECE is vendored as a git submodule at `vendor/ece/`, pinned to a specific commit. The Makefile builds ECE in-place via `make ece`, which does exactly one thing inside the submodule: `make -C vendor/ece`. ECE's own Makefile creates `vendor/ece/bin/ece`, dispatcher symlinks, and staged `share/ece/` assets. `make run`/`make test`/`make build`/`make serve` invoke those in-tree tools by absolute path. No globally-installed `ece` is consulted. The submodule pointer is the single source of truth for "which ECE version does Dunge build against" across local dev, CI, and historical checkouts. CI caches the built ECE binary keyed on the submodule SHA.

**Pure ECE (Scheme dialect):** All game code lives in `game/*.scm` plus `browser-boot.scm`. No Common Lisp, no ASDF, no qlot, no JSCL.

**Source files** load in order (via `game/main.scm` for terminal play, `web/main.scm` for `ece-serve`, or baked into the web bundle by `ece-build`):

1. `game/engine.scm` — player record, display helpers (`text`, `p`, `fmt`, `lines`), `make-choice`, `choose` macro, `ask`
2. `game/dice.scm` — dice rolling (`roll-die`, `roll-dice`, `roll-d20`)
3. `game/items.scm` — item records (item, weapon, stackable-item, healing-herb), `item-display-name`, `usable?`, `consume-item`
4. `game/combat.scm` — Cairn combat system (enemy/encounter records, attack resolution, saves, heal/flee, encounter state machine, `combat-choices`, `run-combat`)
5. `game/bestiary.scm` — enemy data and `make-enemy-from-bestiary`
6. `game/content.scm` — backgrounds, character creation flow, town rooms, test combat encounter
7. `game/main.scm` — terminal entrypoint: loads files, calls `(init-player!)`, calls `(start)`

`browser-boot.scm` is loaded by the web build, `web/main.scm`, and the test runner (not by `game/main.scm`). It provides:
- `*top-continuation*` / `*resume-continuation*` — suspend/resume for browser I/O
- `browser-step` — called by JS to step the game
- `browser-read-line` — continuation-capturing replacement for `read-line`
- Overrides `read-line` → `browser-read-line` and calls `(init-player!)` at load
- Registers `window.browserStep` via ECE's FFI (wrapped in `guard` so CLI loads don't fail)

**UI flow:** The game is a set of mutually-recursive Scheme procedures that use `display`/`newline` for output and `read-line` (or `read-choice`, `ask`) for input. In the terminal, `read-line` reads from stdin. In the browser and tests, `read-line` is replaced with `browser-read-line`, which captures a continuation and yields back to `browser-step`. The next `browser-step` call resumes the continuation with the user's input.

**Item system:** `define-record` gives each item type its own struct (item, weapon, stackable-item, healing-herb). `item-display-name` dispatches via `cond` + type predicates. `usable?` returns `#t` for weapons and healing herbs. `consume-item` decrements stackable quantities and removes exhausted items from the inventory.

**Combat system:** `run-combat` drives a full encounter to completion. `setup-encounter` creates an `encounter` record, `combat-choices` builds the choice list from `*player*` inventory (weapons → attack, herbs → heal, unarmed d4 fallback, flee always available), and `update-encounter-state` determines the resulting state after each round with priority: victory > death > incapacitated > fled > active. `resolve-attack` rolls the damage die, subtracts armor, overflows from HP to STR, and triggers a STR save on critical damage.

**Tests:** `tests/run-all.scm` loads ECE's `ece-unit.scm`, loads all game files plus `browser-boot.scm`, defines `test-step` (buffer-based output capture — `parameterize` on `current-output-port` doesn't survive `call/cc` across multiple `test-step` calls, so we override `display`/`newline` globally when `*in-test-step?*` is true) and `with-fresh-state`, loads each test file, and calls `run-tests`. Unit tests use `ece-unit` API (`test`, `assert-true`, `assert-equal`, `assert-false`).

**Web build:** `scripts/build-web.sh` runs `ece-build --target web --standalone` on the game files and `browser-boot.scm`, producing `dist/{app.ecec, app.js, ece-runtime.js, ece-bootstrap.js, index.html}`. The script then replaces `ece-build`'s generic `index.html` with `web/index.html` (game-specific CSS, JS renderer, choice/prompt DOM, keyboard nav) and stamps in a build version. `web/index.html` also supports `ece-serve` by loading raw `runtime.wasm`/`bootstrap.ecec` plus `/__ece_dev/artifacts/app.ecec` when the standalone base64 bundles are absent.

**ECE app/dev server flow:** Upstream ECE creates app-local browser skeletons with `vendor/ece/bin/ece init web DIR`. Dunge's checked-in app surface is `web/`: `web/main.scm` is the `ece-serve` entrypoint, `web/index.html` is the custom host page, and `make web-dev-assets` copies ignored runtime files (`web/ece-runtime.js`, `web/runtime.wasm`, `web/bootstrap.ecec`) from the vendored ECE build. `make serve PORT=8080` runs `cd web && vendor/ece/bin/ece-serve main.scm --port 8080`. In Emacs, load `vendor/ece/emacs/geiser-ece.el`, enable `geiser-ece-dev-mode`, then use `geiser-ece-dev-start`, `geiser-ece-dev-connect`, or `geiser-ece-dev-connect-repl` against the printed/local session.

## Rules

- Always use the in-tree `vendor/ece/bin/ece*` tools via `make` targets — never invoke a globally-installed `ece`, and never `apt install` / `brew install` ECE as a substitute for updating the submodule
- Never push directly to main — always create a PR, even for documentation-only changes
- Always use `--squash` when merging PRs (GitHub auto-deletes remote branches on merge)
- Always run both `make test` AND `make build` after changes — tests run under the ECE CLI interpreter, while the web build runs under the ECE WASM runtime, and bugs can surface in only one of them
- When asked to clean up or remove code, ONLY touch what was explicitly requested — do not proactively delete functions, variables, or other code
- Before committing, verify `git diff --cached` includes only intended changes — do not bundle unrelated staged files into feature commits
- Always enter plan mode before writing code — produce a written plan and wait for approval before implementing

## Conventions

- Every `.scm` file uses standard Scheme booleans (`#t`, `#f`) — not CL `t`/`nil`
- `game/main.scm` is the terminal entrypoint; the web build, `ece-serve`, and tests do NOT load it
- `web/main.scm` is the browser-dev entrypoint for `ece-serve`; run it from `web/` so its relative `(load "../game/...")` forms and static root line up
- `browser-boot.scm` is loaded by the web build, `web/main.scm`, and the test runner, never by `game/main.scm`
- Background equipment uses thunks (lambdas) to create fresh item instances per playthrough
- String interpolation via ECE reader: `"Hello $name"` expands to `(string-append "Hello " (write-to-string name))`
- For manual concatenation with mixed types, use `(fmt ...)` (defined in `game/engine.scm`) rather than `string-append` + `write-to-string`

## Bumping ECE

ECE is pinned via the `vendor/ece/` submodule. Update it with:

```bash
cd vendor/ece
git fetch origin
git checkout <new-sha>
cd ../..
make ece          # rebuild the submodule
make test         # verify
make build        # verify browser packaging
git add vendor/ece
git commit -m "Bump ECE to <new-sha>"
```

Do not update ECE by editing `~/git/ece/` or by running `make install` in a separate checkout — Dunge ignores anything outside `vendor/ece/`.

## ECE Web Build Gotchas

- **Authoring `.scm` files via shell heredoc in zsh corrupts `!` in symbols.** Zsh history expansion runs before heredoc quoting takes effect, so `cat > foo.scm << 'EOF' ... (js-set! ...) ... EOF` silently inserts a literal `\` before `!`, producing `js-set\!` on disk. Symptom: at bundle load, the unknown symbol dispatches to a null compiled-proc and `ref.cast (ref $compiled-proc)` fails with "illegal cast" at a location that looks unrelated to the symbol. Diagnose with `od -c file.scm | grep "\\\\"`. Workaround: author `.scm` files via the Write/Edit tools (or disable zsh histexpand), not heredocs.
- **FFI callbacks receive arguments as `js-ref` handles, not scheme strings.** Unwrap with `(js-ref->string ref)` before using, and check for JS `null` with `(js-null? ref)`. The `browser-boot.scm` FFI wrapper does this before calling `browser-step`.
- **`(init-player!)` must be called at load time for the web build.** In terminal mode, `game/main.scm` does this; in the web build and tests, `browser-boot.scm` does it instead. Otherwise, `*player*` is `#f` and any `character-*` accessor triggers an "illegal cast" in WASM (or a clearer "hash-ref: not of type" error in CLI).
- **`read-line` must be overridden to `browser-read-line`** so the game's ask/choose/read-choice flow captures continuations instead of reading from stdin. `browser-boot.scm` does this unconditionally — don't load `browser-boot.scm` from terminal-mode code.
- **Output capture via `parameterize` on `current-output-port` does NOT survive `call/cc` across multiple test-step calls.** When the captured continuation is re-invoked in a later `test-step`, the dynamic-wind mechanism restores the old (now-closed) port. Use a mutable buffer + a `*in-test-step?*` flag to override `display`/`newline` globally during the step. See `tests/run-all.scm`.
- **`ece-unit.scm` lives at `vendor/ece/src/ece-unit.scm`** in the vendored submodule. `tests/run-all.scm` locates it via the `ECE_UNIT_PATH` env var, which the Makefile sets to the in-tree source path. (`make install` would copy it to `share/ece/` but we don't run `make install` on the submodule — we use the binaries in-place.)
- **Return values from FFI callbacks are NOT marshalled** — `callback(procHandle)` in ECE's glue.js returns the raw `call_ece_proc` result without running it through `_eceToJs`, so what you see in JS is an internal handle integer. Don't rely on the return value; communicate via side effects (display → buffer).
