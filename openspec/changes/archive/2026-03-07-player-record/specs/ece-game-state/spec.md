## REMOVED Requirements

### Requirement: Game state is stored in a global hash table
**Reason**: Replaced by `*player*` character record. No other data was stored in `*state*`.
**Migration**: Replace `*state*` with `*player*` record. Use `character-*` accessors instead of `state-get`/`state-set!`.

### Requirement: Nested state access via helper functions
**Reason**: No longer needed — record accessors provide direct named field access.
**Migration**: Replace `(state-get 'character 'field)` with `(character-field *player*)`. Replace `(state-set! 'character 'field val)` with `(set-character-field! *player* val)`.

### Requirement: State-ref creates lazy lookup closures
**Reason**: Replaced by `player-ref` which provides the same lazy lookup pattern using record field access.
**Migration**: Replace `(state-ref 'character 'field)` with `(player-ref 'field)`.
