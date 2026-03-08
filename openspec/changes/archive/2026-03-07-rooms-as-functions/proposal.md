## Why

The current room system uses an intermediate data structure (tagged lists of elements like `text`, `exit`, `gate`, `dynamic`, `prompt`, `combat-encounter`) that gets interpreted by a renderer (`render-element` dispatcher). This was inherited from the old CL engine where rooms were static data. In ECE, rooms should just be functions — entering a room executes its body. This eliminates the entire element/renderer layer, removes the need for `player-ref` thunks and `callable?` checks, and makes rooms simpler to write and reason about.

## What Changes

- **BREAKING**: `define-room` changes from building a hash-table data structure to defining a function
- Remove all element types (`text`, `exit`, `gate`, `dynamic`, `prompt`, `combat-encounter` tagged lists)
- Remove the `render-element` / `render-elements` dispatcher (≈80 lines)
- Remove `player-ref`, `callable?`, `make-text-element`, `make-exit-element`, `make-gate-element`, `make-prompt-element`
- Replace `text` macro with a simple display+newline wrapper (no thunks)
- Replace `exit`/`gate`/`dynamic` elements with direct code (`choose`, `if`/`when`, inline)
- Simplify `game-loop` — rooms handle their own I/O flow
- Rewrite all room definitions in `content.scm` to use the function-based approach
- Rewrite `combat-encounter` from an element type to a function call
- Update integration tests to match new room behavior

## Capabilities

### New Capabilities
- `room-system`: Room definition, navigation, choice menus, prompt handling, and game loop

### Modified Capabilities
_None — no existing specs to modify_

## Impact

- `game/engine.scm` — Major rewrite: remove element system, simplify game loop
- `game/content.scm` — Rewrite all room definitions as function bodies
- `game/combat.scm` — Adapt combat encounter from element type to function-based flow
- `tests/integration/test-char-creation.scm` — May need step count adjustments
- `tests/integration/test-navigation.scm` — May need step count adjustments
- `browser-boot.scm` — No changes expected (call/cc pattern is orthogonal)
