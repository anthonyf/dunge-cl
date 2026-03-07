## Context

The ECE engine now has full feature parity for the game's core systems. The old CL engine (17 source files in src/) is no longer used — the game runs exclusively via `ece-bootstrap.lisp`. The CL tests (tests/) test old engine code only. The web export (`web-export.lisp`) compiles the old CL source files to JS via JSCL and is incompatible with the ECE engine.

## Goals / Non-Goals

**Goals:**
- Delete all old CL engine source files from src/
- Delete old CL engine tests from tests/
- Simplify dunge.asd to only bootstrap ECE
- Leave web-export.lisp in place but broken (future work to rebuild for ECE)

**Non-Goals:**
- Porting the web export to ECE (separate change)
- Adding new ECE features (containers, vignette stack, etc.)
- Removing the JSCL submodule (still needed for future web export)

## Decisions

### Delete all CL source files except ece-bootstrap.lisp

Files to delete from src/:
- packages.lisp, utils.lisp, data-store.lisp, dice.lisp, serialize.lisp, text-layout.lisp
- engine.lisp, room.lisp, item.lisp, character.lisp, character-creation.lisp
- combat.lisp, bestiary.lisp, container.lisp, overflow.lisp
- character-sheet.lisp, inventory.lisp, main.lisp

Keep: `ece-bootstrap.lisp` (thin CL bootstrap that loads ECE game files).

**Rationale:** All game logic now lives in `game/*.scm`. The CL files are dead code.

### Delete old CL tests

Files to delete from tests/:
- main.lisp, data-store.lisp, item.lisp, room.lisp

Keep: `tests/web/` directory (web test framework, may be useful for future ECE web export).

**Rationale:** These tests test the old CL engine classes (data-store, item CLOS hierarchy, room system). They don't test ECE code.

### Simplify dunge.asd

Reduce components to just `ece-bootstrap`. Remove `alexandria` dependency (only used by old engine). Keep `ece` dependency. Remove the test system definition since the CL tests are being deleted.

### Leave web-export.lisp as-is

The web export is entirely built around the old CL engine (compiles all 17 CL source files + JSCL patches + browser context). It references `room-local`, `gosub-choice`, `*vignette-stack*`, `serialize`, and other CL-only concepts. It will be broken after this change.

**Rationale:** Rebuilding web export for ECE is a separate, substantial effort. Better to do it as its own change rather than blocking deletion of the old engine.

### Move ece-bootstrap.lisp package definition inline

Currently `packages.lisp` defines the `dunge` package which `ece-bootstrap.lisp` doesn't use (it defines its own `dunge/ece-bootstrap` package). No changes needed to ece-bootstrap.lisp — it's self-contained.

## Risks / Trade-offs

- **[web-export.lisp broken]** The web build will fail after this change. Acceptable — it needs a full rewrite for ECE anyway.
- **[No CL tests]** Removing tests reduces safety net. Mitigated: ECE code is tested via playthrough; future work can add ECE-level tests.
- **[Irreversible deletion]** Git history preserves all deleted files. Can always recover if needed.
