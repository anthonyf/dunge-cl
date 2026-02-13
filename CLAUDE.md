# Dunge — Text Adventure Engine in Common Lisp

See also: [README.org](README.org) | [DESIGN.md](DESIGN.md) — full game design document (Cairn rules, oracle system, dungeon generation)

## Quick Reference

```bash
# Terminal REPL
qlot exec sbcl --eval '(asdf:load-system :dunge)' \
               --eval '(dunge:game-repl (dunge:room (quote start)))'

# Web build (produces dist/)
qlot exec sbcl --non-interactive --load web-export.lisp

# Run tests
qlot exec sbcl --eval '(asdf:test-system :dunge)' --quit

# Web test build + Playwright
qlot exec sbcl --non-interactive --eval '(push :web-test *features*)' --load web-export.lisp
npx playwright test

# Serve web build from remote VPS (run from local machine)
ssh -L 8080:localhost:8080 user@your-vps "python3 -m http.server 8080 --directory /home/dev/git/dunge-cl/dist/"
# Then open http://localhost:8080
```

## Architecture

**Source files** load in order (src/):
1. `utils.lisp` — string utilities (trim-whitespace, validate-non-empty-string)
2. `data-store.lisp` — nested hash table storage (*data-store*, lookup, ref)
3. `dice.lisp` — dice rolling (roll-dice, roll-d20)
4. `serialize.lisp` — generic `serialize` + hash-table `deserialize` dispatch
5. `text-layout.lisp` — text formatting (columns, text macro, nl, spaces)
6. `engine.lisp` — game loop, generic functions, context classes
7. `room.lisp` — room system (room, exit, gate, p, prompt, set-lookup elements)
8. `item.lisp` — item system (item, stackable, weapon, consumable, healing-herb) + item serialize/deserialize
9. `character.lisp` — combatant base class, player-character, *player* + player serialize/deserialize
10. `character-creation.lisp` — background data, character creation room sequence
11. `combat.lisp` — enemy, encounter, attack resolution, combat choices (weapons/heal/flee)
12. `main.lisp` — game content (room definitions, combat encounters)

**Key pattern:** Two UI contexts share the same engine:
- `print-context` — terminal REPL (synchronous read-line loop)
- `browser-context` — web UI (event-driven DOM rendering)

**Engine dispatch:** Generic functions `perform`, `menu`, `out`, `execute-action` dispatch on context type. Rooms are declarative trees of elements (p, exit, gate, prompt) that `perform` walks.

**Data store:** Global `*data-store*` with nested hash tables. Access via `(lookup key1 key2 ...)` and `(setf (lookup ...) value)`.

**Item system:** Mixin-based via CLOS multiple inheritance. `weapon` mixin adds `damage-die` slot. `consumable` mixin marks items as usable via `consume` generic. `stackable` mixin adds quantity tracking. Concrete classes combine mixins: `weapon-item` (weapon + item), `healing-herb` (consumable + stackable + item). Constructors: `(weapon name :damage-die N)`, `(healing-herb :quantity N)`, `(make-item name)`.

**Combat system:** Uses a state machine via the `combat-encounter` room element. The encounter tracks an explicit `:state` slot (`:active`, `:victory`, `:death`, `:incapacitated`, `:fled`). `combat-encounter` handles the full lifecycle: setup, stats display, combat choices (derived from `*player*` inventory), log draining, cleanup, and outcome rendering. Room definitions are purely declarative — only enemy spec, intro text, and outcome elements per state:

```lisp
(make-room 'test-combat "Combat!"
  (combat-encounter
    :enemy (make-goblin)
    :intro (list (p "A goblin leaps out of the shadows!"))
    :victory (list (p "Victory!") (exit "Continue" 'next-room))
    :death (list (p "You died.") (exit "Restart" 'town))
    :incapacitated (list (p "You fall unconscious.") (exit "Wake up" 'town))
    :fled (list (p "You escape.") (exit "Continue" 'town))))
```

`combat-choices` builds the choice list from `*player*` inventory — each weapon becomes an attack choice, consumables become use choices, unarmed d4 fallback if no weapons. Flee attempts a DEX save; failure means a parting blow. `resolve-attack` handles Cairn damage: roll weapon die, subtract armor, overflow from HP to STR, STR save on critical. `update-encounter-state` determines the resulting state after each round with priority: victory > death > incapacitated > fled > active.

## Rules

- Always use `qlot exec sbcl` — never invoke bare `sbcl`
- When asked to clean up or remove code, ONLY touch what was explicitly requested — do not proactively delete functions, variables, or other code
- Before committing, verify `git diff --cached` includes only intended changes — do not bundle unrelated staged files (e.g. lockfiles) into feature commits
- When asked to plan or design a feature, produce a written plan and wait for approval before implementing
- When changing package definitions or exports, check for symbol conflicts and run tests immediately

## Conventions

- All packages use `uiop:define-package` (not `defpackage`)
- Package per file: `dunge/utils`, `dunge/data-store`, `dunge/engine`, `dunge/room`, etc.
- Use `:mix` to import symbols from other packages (not `:import-from`)
- `dunge` package re-exports everything via `:mix-reexport`
- No changes to src/ files for web compatibility — patches go in web-export.lisp
- main.lisp should be the last file to load.
- Background equipment uses thunks (lambdas) to create fresh item instances per playthrough

## JSCL Web Export Gotchas

- JSCL `oget` is in the `JSCL` package — code in other packages must use `jscl::oget`
- JSCL strings are char arrays, not JS strings — use `jscl::jsstring` for DOM APIs, `jscl::clstring` to convert back
- `uiop:define-package` shim must create sub-packages matching SBCL's home-package structure (e.g. `UIOP/PACKAGE`, `UIOP/UTILITY`)
- Functions defined in browser-context.lisp are internal to `dunge/engine` — boot code must use qualified names
- JSCL doesn't support `~{~A~}` format directive — use dolist+princ instead
- `#j:` reader syntax works in cross-compilation context
- `uiop:symbol-call` needed for JSCL functions since the package doesn't exist at read time
- New CLOS accessor setf methods need explicit `(defun (setf accessor) ...)` patches in web-export.lisp
- **EQL specializers across files crash JSCL** — `defmethod` with `(eql :keyword)` specializers works within a single compilation unit, but crashes at runtime (`push-new-class-direct-methods`) when the `defgeneric` and `defmethod` are in different files. Use hash-table dispatch instead (see `define-deserializer` in serialize.lisp).
- **`jscl::js-null-p` is not a callable function** — it's only a type predicate name in JSCL's type table. Use `(eq val #j:null)` to check for JavaScript null.
- **JSCL errors can be silent** — CL errors thrown during boot/load may not surface as JS page errors. Wrap suspect code in `handler-case` with `jscl::oget #j:console "log"` calls for debugging.
