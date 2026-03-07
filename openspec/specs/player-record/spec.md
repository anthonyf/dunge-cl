## ADDED Requirements

### Requirement: Character data is defined as an ECE record
The engine SHALL define a `character` record with fields: name, background, str, dex, wil, hp, hp-max, armor, gold, fate, inventory.

#### Scenario: Record provides typed constructor
- **WHEN** `(make-character name background str dex wil hp hp-max armor gold fate inventory)` is called
- **THEN** a character record SHALL be returned with all fields set

#### Scenario: Record provides type predicate
- **WHEN** `(character? obj)` is called on a character record
- **THEN** the result SHALL be true

#### Scenario: Record provides named accessors
- **WHEN** `(character-name player)` is called on a character record
- **THEN** the character's name SHALL be returned

#### Scenario: Record provides mutators
- **WHEN** `(set-character-hp! player 3)` is called
- **THEN** `(character-hp player)` SHALL return 3

### Requirement: Global *player* holds the active character
The engine SHALL maintain a `*player*` global variable holding the current character record.

#### Scenario: Player is nil before game start
- **WHEN** the engine loads
- **THEN** `*player*` SHALL be nil

#### Scenario: Player is initialized during character creation
- **WHEN** character creation begins
- **THEN** `*player*` SHALL be set to a character record with nil fields and empty inventory

### Requirement: player-ref creates lazy lookup closures for text display
The engine SHALL provide a `player-ref` function that takes a field name and returns a zero-argument closure. When called, the closure SHALL return the current value of that field from `*player*`.

#### Scenario: player-ref returns current value at call time
- **WHEN** `(define ref (player-ref 'name))` then `(set-character-name! *player* "Boromir")` then `(ref)`
- **THEN** the result SHALL be "Boromir"
