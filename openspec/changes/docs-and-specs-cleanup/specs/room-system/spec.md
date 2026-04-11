## REMOVED Requirements

### Requirement: Rooms are functions registered by name
**Reason**: The `define-room` macro and `*rooms*` registry were removed in PR #31 (2026-03-08 remove-room-machinery). Rooms are now plain Scheme functions that call each other directly in tail position — there is no named registry and no lookup step. The canonical behavior is documented in `ece-room-system/spec.md` under "Rooms are plain functions."

**Migration**: See `openspec/specs/ece-room-system/spec.md`. There is no `define-room` or `*rooms*` in `game/*.scm`.

### Requirement: text macro displays formatted output
**Reason**: `text` is no longer a macro — it is a plain function defined in `game/engine.scm` that takes any number of arguments and calls `display` + `newline`. The behavior (concatenate args, print a line) is the same, but the requirement's framing as a "macro" is incorrect. The function form is documented in `ece-room-system/spec.md` under "Text elements display content."

**Migration**: See `openspec/specs/ece-room-system/spec.md`. `text` is a function, not a macro.

### Requirement: choose macro presents numbered menu
**Reason**: The `choose` helper still exists, but the spec requirement belongs in `ece-choice-system/spec.md` (or its successor), not in a `room-system` capability that no longer exists. This requirement is a shadow of the current choice system, and keeping it here misleads readers into thinking there is a standalone room-system capability.

**Migration**: See `openspec/specs/ece-choice-system/spec.md` for the current `choose` / `make-choice` behavior.

### Requirement: ask function handles text input with validation
**Reason**: Shadow requirement — the current `ask` function is documented in `ece-room-system/spec.md` under "Prompt elements collect text input" with the same WHEN/THEN scenarios.

**Migration**: See `openspec/specs/ece-room-system/spec.md`.

### Requirement: goto navigates to another room
**Reason**: `goto` no longer exists — it was removed in PR #31 along with `define-room` and `*rooms*`. Rooms navigate by calling each other directly (e.g., `(library)` instead of `(goto 'library)`). `grep -r 'goto' game/` returns no matches for the navigation helper.

**Migration**: See `openspec/specs/ece-room-system/spec.md` scenario "Room navigation via direct call." To move from one room to another, call the target room function directly in tail position.

### Requirement: Game loop executes room functions in sequence
**Reason**: There is no explicit game loop — rooms call each other directly in tail position via ECE's TCO. The `*current-room*` variable referenced in the spec does not exist. The replacement model (direct calls, tail recursion) is documented in `ece-game-loop/spec.md` and `ece-room-system/spec.md`.

**Migration**: See `openspec/specs/ece-room-system/spec.md` and `openspec/specs/ece-game-loop/spec.md`.

### Requirement: No element types or renderer
**Reason**: This was a negative requirement asserting the absence of tagged-list element types. It is still true, but the assertion belongs in `ece-room-system/spec.md` (which already covers the "rooms are plain functions" model) rather than in a shadow capability.

**Migration**: See `openspec/specs/ece-room-system/spec.md`.
