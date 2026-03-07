## Why

The ECE engine now has full feature parity for the game's core systems: rooms, choices, character creation, items, combat, and bestiary. The old CL engine code (17 source files) is dead weight — it's not used by the ECE game path and creates confusion about which code is canonical. Time to delete it and simplify dunge.asd to only bootstrap ECE.

## What Changes

- **BREAKING**: Delete all old CL engine source files (packages, utils, data-store, dice, serialize, text-layout, engine, room, item, character, character-creation, combat, bestiary, container, overflow, character-sheet, inventory, main)
- **BREAKING**: Delete old CL engine tests (tests/data-store.lisp, tests/item.lisp, tests/room.lisp, tests/main.lisp)
- Simplify `dunge.asd` to only load `ece-bootstrap.lisp` (the thin CL bootstrap that starts the ECE game)
- Remove `alexandria` dependency from dunge.asd (only used by old engine)
- Keep `ece` dependency (needed by bootstrap)

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

(none — this is a deletion, not a behavior change; ECE specs remain accurate)

## Impact

- `src/` reduced from 19 files to 1 (`ece-bootstrap.lisp`)
- `tests/` CL tests removed (old engine tests for data-store, item, room)
- `dunge.asd` simplified to single-component system
- `web-export.lisp` references old engine — needs review (may already be broken)
- Game is launched exclusively via `(dunge/ece-bootstrap:start)`
