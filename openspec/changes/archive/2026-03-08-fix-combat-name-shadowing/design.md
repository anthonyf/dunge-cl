## Context

`define-record enemy` generates an accessor function `enemy-name`. The `run-combat` function has a parameter also called `enemy-name`, which shadows the accessor inside the function body. The string interpolation `$(enemy-name e)` on line 318 expands at read-time to `(enemy-name e)` — a function call that resolves to the parameter (a string) instead of the accessor, crashing with a TYPE-ERROR.

## Goals / Non-Goals

**Goals:**
- Fix the parameter shadowing so `run-combat` can display enemy stats correctly
- Maintain the same public API for `run-combat` (callers unaffected)

**Non-Goals:**
- Adding a linter or static check for accessor shadowing in ECE
- Changing the `define-record` macro or ECE's scoping rules

## Decisions

**Rename `enemy-name` parameter to `name`**: The parameter is only used on line 292 (`make-enemy-from-bestiary enemy-name`) and in the function signature. Renaming to `name` is concise and doesn't shadow any other accessor (the `character` record uses `character-name`, not `name`). Alternative considered: `en-name` — rejected as unnecessarily abbreviated.

## Risks / Trade-offs

- [Risk] Other parameters could shadow accessors elsewhere → Not addressing globally; this fix is scoped to the known crash site.
