## Why

The current engine still carries unnecessary indirection from the previous architecture: rooms register in a `*rooms*` hash table, `goto` sets `*current-room*`, and `game-loop` trampolines between them. Since ECE has tail-call optimization, rooms can simply be functions that call each other directly — no registry, no global state, no trampoline needed.

## What Changes

- **BREAKING**: Remove `define-room` macro — rooms become plain `define` functions
- **BREAKING**: Remove `goto` function — rooms call each other directly as tail calls
- **BREAKING**: Remove `*rooms*` hash table and `get-room` lookup
- **BREAKING**: Remove `*current-room*` global state
- **BREAKING**: Remove `game-loop` and `start-game` — entry point is just calling the first room function
- Room titles move into the room function body as `text` calls
- `choose` macro actions call room functions directly instead of `(goto 'room-name)`
- Integration tests check output text instead of `*current-room*`

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `ece-room-system`: Rooms are plain functions instead of macro-registered entries in a hash table
- `ece-game-loop`: No trampoline loop — rooms call each other via TCO; `goto`, `start-game`, `game-loop` removed

## Impact

- `game/engine.scm` — Remove room registry, goto, game-loop, start-game, define-room macro
- `game/content.scm` — Convert all `define-room` to `define`, replace `(goto 'name)` with `(name)`
- `game/browser-boot.scm` — `(start-game 'start)` becomes `(start)`
- `game/main.scm` — Same entry point change
- `tests/integration/` — Remove `*current-room*` assertions, check output text
- `tests/test-harness.scm` — Remove `*current-room*` from `with-fresh-state`
