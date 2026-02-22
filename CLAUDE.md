# Dunge — Text Adventure Engine in Common Lisp

See also: [README.org](README.org) | [DESIGN.md](DESIGN.md) — full game design document (Cairn rules, oracle system, dungeon generation)

## Quick Reference

```bash
make run       # Terminal REPL
make build     # Web build (produces dist/)
make test      # Run tests
make test-web  # Web test build + Playwright
make test-all  # Run both test and test-web
make clean     # Remove ASDF cache, .fasl files, dist/, test-results/

# Serve web build from remote VPS (run from local machine)
ssh -L 8080:localhost:8080 user@your-vps "python3 -m http.server 8080 --directory /home/dev/git/dunge-cl/dist/"
# Then open http://localhost:8080
```

## Architecture

**Single package:** All source files share the `dunge` package, defined in `packages.lisp` using standard `defpackage`. No UIOP dependency in source. The package shadows `room`, `char-name`, and `item` from CL.

**Source files** load in order (src/):
1. `packages.lisp` — `defpackage` for `dunge` and `dunge-user`
2. `utils.lisp` — string utilities (trim-whitespace, validate-non-empty-string)
3. `data-store.lisp` — nested hash table storage (*data-store*, lookup, ref)
4. `dice.lisp` — dice rolling (roll-dice, roll-d20)
5. `serialize.lisp` — generic `serialize` + hash-table `deserialize` dispatch
6. `text-layout.lisp` — text formatting (`nl`, `text` macro)
7. `engine.lisp` — game loop, generic functions, context classes
8. `room.lisp` — room system (room, exit, gate, group, p, prompt, set-lookup elements)
9. `item.lisp` — item system (item, stackable, weapon, consumable, healing-herb) + item serialize/deserialize
10. `character.lisp` — combatant base class, player-character, *player* + player serialize/deserialize
11. `character-creation.lisp` — background data, character creation room sequence
12. `combat.lisp` — enemy, encounter, attack resolution, combat choices (weapons/heal/flee)
13. `bestiary.lisp` — enemy data table (`*bestiary*`) and `make-enemy` lookup
14. `container.lisp` — container element (make-container)
15. `main.lisp` — game content (room definitions, combat encounters)

**Key pattern:** Two UI contexts share the same engine:
- `print-context` — terminal REPL (synchronous read-line loop)
- `browser-context` — web UI (event-driven DOM rendering)

**Engine dispatch:** Generic functions `perform`, `menu`, `out`, `execute-action` dispatch on context type. Rooms are declarative trees of elements (p, exit, gate, group, prompt) that `perform` walks. `group` bundles multiple elements into one — use it wherever a single element is expected but you need several (e.g. gate branches, combat-encounter outcomes). Single-element cases need no wrapping. Bare `choice` objects are also valid DSL elements (perform returns them as a single-item choice list).

**Vignette navigation:** `set-vignette` replaces the current room (goto). `push-vignette`/`pop-vignette` provide stack-based sub-room navigation (gosub/return). Choice constructors: `(goto-choice label vignette)`, `(gosub-choice label vignette)`, `(return-choice label)`.

**Container system:** `(make-container title description open-label contents)` creates an openable container as a room element. It renders a description and a gosub choice that navigates into a dynamically-created room showing the contents, with a "Back" button to return. Example:

```lisp
(make-container "Storage Chest" "An old chest sits in the corner." "Open the chest"
  (list (p "Inside you find:") (p "  - A rusty key")))
```

**Data store:** Global `*data-store*` with nested hash tables. Access via `(lookup key1 key2 ...)` and `(setf (lookup ...) value)`.

**Item system:** Mixin-based via CLOS multiple inheritance. `weapon` mixin adds `damage-die` slot. `consumable` mixin marks items as usable via `consume` generic. `stackable` mixin adds quantity tracking. Concrete classes combine mixins: `weapon-item` (weapon + item), `healing-herb` (consumable + stackable + item). Constructors: `(weapon name :damage-die N)`, `(healing-herb :quantity N)`, `(make-item name)`.

**Combat system:** Uses a state machine via the `combat-encounter` room element. The encounter tracks an explicit `:state` slot (`:active`, `:victory`, `:death`, `:incapacitated`, `:fled`). `combat-encounter` handles the full lifecycle: setup, stats display, combat choices (derived from `*player*` inventory), log draining, cleanup, and outcome rendering. Room definitions are purely declarative — only enemy spec, intro text, and outcome elements per state:

```lisp
(make-room 'test-combat "Combat!"
  (combat-encounter
    :enemy (make-enemy "Goblin")
    :intro (p "A goblin leaps out of the shadows!")
    :victory (group (p "Victory!") (exit "Continue" 'next-room))
    :death (group (p "You died.") (exit "Restart" 'town))
    :incapacitated (group (p "You fall unconscious.") (exit "Wake up" 'town))
    :fled (group (p "You escape.") (exit "Continue" 'town))))
```

`combat-choices` builds the choice list from `*player*` inventory — each weapon becomes an attack choice, consumables become use choices, unarmed d4 fallback if no weapons. Flee attempts a DEX save; failure means a parting blow. `resolve-attack` handles Cairn damage: roll weapon die, subtract armor, overflow from HP to STR, STR save on critical. `update-encounter-state` determines the resulting state after each round with priority: victory > death > incapacitated > fled > active.

## Rules

- Always use `qlot exec sbcl` — never invoke bare `sbcl`
- Never push directly to main — always create a PR, even for documentation-only changes
- Always use `--squash` when merging PRs (GitHub auto-deletes remote branches on merge)
- Clear ASDF cache (`rm -rf ~/.cache/common-lisp/`) when package definitions change
- Always run both SBCL tests and web build after changes — tests may pass but JSCL runtime can still crash
- When asked to clean up or remove code, ONLY touch what was explicitly requested — do not proactively delete functions, variables, or other code
- Before committing, verify `git diff --cached` includes only intended changes — do not bundle unrelated staged files (e.g. lockfiles) into feature commits
- Always enter plan mode before writing code — produce a written plan and wait for approval before implementing
- When changing package definitions or exports, check for symbol conflicts and run tests immediately

## Conventions

- Single `dunge` package — all src/ files use `(in-package #:dunge)`
- Package defined in `src/packages.lisp` using standard `defpackage` (no UIOP)
- New exported symbols must be added to the `:export` list in `packages.lisp`
- No changes to src/ files for web compatibility — patches go in web-export.lisp
- main.lisp should be the last file to load.
- Background equipment uses thunks (lambdas) to create fresh item instances per playthrough

## JSCL Web Export Gotchas

- JSCL `oget` is in the `JSCL` package — code in the `dunge` package must use `jscl::oget`
- JSCL strings are char arrays, not JS strings — use `jscl::jsstring` for DOM APIs, `jscl::clstring` to convert back
- JSCL doesn't support `~{~A~}` format directive — use dolist+princ instead
- `#j:` reader syntax works in cross-compilation context
- `uiop:symbol-call` needed for JSCL functions since the package doesn't exist at read time
- New CLOS accessor setf methods need explicit `(defun (setf accessor) ...)` patches in web-export.lisp
- **EQL specializers across files crash JSCL** — `defmethod` with `(eql :keyword)` specializers works within a single compilation unit, but crashes at runtime (`push-new-class-direct-methods`) when the `defgeneric` and `defmethod` are in different files. Use hash-table dispatch instead (see `define-deserializer` in serialize.lisp).
- **`jscl::js-null-p` is not a callable function** — it's only a type predicate name in JSCL's type table. Use `(eq val #j:null)` to check for JavaScript null.
- **JSCL errors can be silent** — CL errors thrown during boot/load may not surface as JS page errors. Wrap suspect code in `handler-case` with `jscl::oget #j:console "log"` calls for debugging.
- `defvar` with `make-hash-table` works across JSCL compilation units; `setf gethash` in later files executes correctly at runtime
- **Gensyms don't survive JSCL cross-compilation** — two references to the same gensym become different JS objects. Use string keys (compared by `equal`) instead of gensyms for hash table keys in cross-compiled code.
- **`defvar` used in macros needs `eval-when`** — wrap with `(eval-when (:compile-toplevel :load-toplevel :execute) ...)` so the variable exists at macro-expansion time during JSCL cross-compilation
