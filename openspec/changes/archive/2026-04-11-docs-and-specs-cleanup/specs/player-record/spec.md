## REMOVED Requirements

### Requirement: Character data is defined as an ECE record
**Reason**: The `character` record and its accessors are still real and load-bearing — the requirement is not wrong, but it lives in the wrong capability. `player-record` was created as a standalone capability early in the ECE migration; since then `ece-character-creation` has grown to cover backgrounds, starting equipment, and character-summary display, which all ultimately produce and consume the same record. Keeping two capabilities lets them drift (the two current specs already disagree on accessor conventions). This change folds the requirement into `ece-character-creation` under "Character is defined as an ECE record."

**Migration**: See `openspec/specs/ece-character-creation/spec.md`.

### Requirement: Global *player* holds the active character
**Reason**: Same reason as above — the `*player*` global and `init-player!` are real, but belong in the same capability that owns character creation. This change moves the requirement into `ece-character-creation`.

**Migration**: See `openspec/specs/ece-character-creation/spec.md`.

### Requirement: player-ref creates lazy lookup closures for text display
**Reason**: `player-ref` was removed in the archived change `2026-03-07-rooms-as-functions` when rooms stopped being data structures and became plain functions. Rooms no longer build strings ahead of time; they call `character-*` accessors on `*player*` at display time, so the lazy-thunk pattern is obsolete. The function does not exist in `game/engine.scm` and `grep -r player-ref game/ tests/` returns no matches.

**Migration**: None. Code that used to do `(player-ref 'name)` and invoke the resulting thunk later should call `(character-name *player*)` directly at the point of use. See `openspec/specs/ece-room-system/spec.md` for the "rooms are plain functions" model.
