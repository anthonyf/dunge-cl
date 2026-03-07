## ADDED Requirements

### Requirement: Game state is stored in a global hash table
The engine SHALL maintain a global `*state*` hash table for all game state.

#### Scenario: State is initially empty
- **WHEN** the game starts
- **THEN** `*state*` SHALL be an empty hash table

### Requirement: Nested state access via helper functions
The engine SHALL provide `state-get` and `state-set!` functions that support nested key access into `*state*`.

#### Scenario: Set and get a top-level value
- **WHEN** `(state-set! 'player-name "Aragorn")` is called
- **THEN** `(state-get 'player-name)` SHALL return "Aragorn"

#### Scenario: Set and get a nested value
- **WHEN** `(state-set! 'character 'name "Aragorn")` is called
- **THEN** `(state-get 'character 'name)` SHALL return "Aragorn"

#### Scenario: Get missing key returns nil
- **WHEN** `(state-get 'nonexistent)` is called on a key that has not been set
- **THEN** the result SHALL be nil

### Requirement: State-ref creates lazy lookup closures
The engine SHALL provide a `state-ref` function that returns a zero-argument closure. When called, the closure SHALL return the current value at the given keys.

#### Scenario: state-ref returns current value at call time
- **WHEN** `(define ref (state-ref 'character 'name))` then `(state-set! 'character 'name "Boromir")` then `(ref)`
- **THEN** the result SHALL be "Boromir"
