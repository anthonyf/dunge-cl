## Why

Character data is currently scattered across `*state*` as individual hash table keys (`state-set! 'character 'name`, `state-set! 'character 'str`, etc.). ECE now supports `define-record`, which provides typed constructors, predicates, named accessors, and mutators. Replacing the state bag with a `*player*` record makes character data structured, self-documenting, and easier to work with. Since `*state*` holds nothing besides character data, it can be removed entirely.

## What Changes

- Define a `character` record with fields: name, background, str, dex, wil, hp, hp-max, armor, gold, fate, inventory
- Replace `*state*` global with `*player*` global holding a character record
- Replace all `(state-get 'character 'field)` calls with `(character-field *player*)` accessors
- Replace all `(state-set! 'character 'field val)` calls with `(set-character-field! *player* val)` mutators
- Replace `(state-ref 'character 'field)` thunks with `(player-ref 'field)` or direct accessor lambdas
- **BREAKING**: Remove `*state*`, `state-get`, `state-set!`, `state-ref` from engine.scm
- Remove temporary flags (`stats-rolled`, `hp-rolled`, `equipped`) — use record field presence or a different guard pattern

## Capabilities

### New Capabilities
- `player-record`: Character data as an ECE record with typed constructor, named accessors, and mutators

### Modified Capabilities
- `ece-game-state`: **BREAKING** — `*state*` system removed entirely, replaced by `*player*` record

## Impact

- `game/engine.scm` — Remove state system, add player record definition and `*player*` global
- `game/content.scm` — Update all ~40 state-get/state-set!/state-ref calls to use record accessors/mutators
