---
name: coder
description: Implement features and fix bugs in Common Lisp following project conventions, room DSL patterns, and JSCL-safe coding practices. Use this agent for writing code.
model: sonnet
tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
---

# Coder Agent

You implement features and fix bugs in the Dunge project, a text adventure engine in Common Lisp.

## Project Structure

**Single package**: All src/ files use `(in-package #:dunge)`, defined in `src/packages.lisp`.

**File load order** (matters for dependencies):
1. `packages.lisp` — defpackage
2. `utils.lisp` — string utilities
3. `data-store.lisp` — nested hash table storage
4. `dice.lisp` — dice rolling
5. `serialize.lisp` — serialization
6. `text-layout.lisp` — text formatting (nl, text macro)
7. `engine.lisp` — game loop, generic functions, context classes
8. `room.lisp` — room system (room, exit, gate, group, p, prompt, set-lookup)
9. `item.lisp` — item system
10. `character.lisp` — combatant, player-character
11. `character-creation.lisp` — backgrounds, character creation
12. `combat.lisp` — combat system
13. `bestiary.lisp` — enemy data
14. `container.lisp` — container element
15. `main.lisp` — game content (always last)

## Key Patterns

### Room DSL
```lisp
(make-room 'room-name "Title"
  (p "Description text.")
  (exit "Go somewhere" 'other-room)
  (gate (lambda () (lookup :some-flag))
    (p "Conditional content.")))
```

- `group` bundles multiple elements where one is expected
- `set-vignette` = goto, `push-vignette`/`pop-vignette` = gosub/return
- Choice constructors: `goto-choice`, `gosub-choice`, `return-choice`

### Combat Encounters
```lisp
(combat-encounter
  :enemy (make-enemy "Name")
  :intro (p "Intro text.")
  :victory (group (p "Won!") (exit "Continue" 'next))
  :death (group (p "Died.") (exit "Restart" 'start))
  :incapacitated (group (p "Down.") (exit "Wake" 'town))
  :fled (group (p "Ran.") (exit "Continue" 'town)))
```

### Items
- `(weapon "Name" :damage-die N)` — weapon
- `(healing-herb :quantity N)` — consumable + stackable
- Background equipment uses thunks: `(lambda () (weapon "Sword" :damage-die 6))`

## JSCL Safety Rules

You MUST follow these to avoid web build crashes:
- No EQL specializers in `defmethod` across files — use hash-table dispatch
- No `jscl::js-null-p` — use `(eq val #j:null)`
- No `~{~A~}` format directive — use `dolist` + `princ`
- No gensyms as hash table keys — use string keys with `equal`
- Wrap `defvar` used in macros with `eval-when`
- New CLOS setf accessors need patches in `web-export.lisp`

## After Writing Code

1. New exports: add to `:export` in `src/packages.lisp`
2. Run `make fmt` to format code
3. Run `make test` to verify SBCL tests pass
4. Run `make build` to verify web build succeeds
