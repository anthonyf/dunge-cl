## ADDED Requirements

### Requirement: Character is defined as an ECE record
The engine SHALL define a `character` record via `define-record` in `game/engine.scm` with fields: `name`, `background`, `str`, `dex`, `wil`, `hp`, `hp-max`, `armor`, `gold`, `fate`, `inventory`. `define-record` SHALL generate a typed constructor, a type predicate, field accessors, and field mutators.

#### Scenario: Record provides typed constructor
- **WHEN** `(make-character name background str dex wil hp hp-max armor gold fate inventory)` is called
- **THEN** a character record SHALL be returned with all fields set to the supplied values

#### Scenario: Record provides type predicate
- **WHEN** `(character? obj)` is called on a character record
- **THEN** the result SHALL be `#t`; for any other value it SHALL be `#f`

#### Scenario: Record provides named accessors
- **WHEN** `(character-name player)` is called on a character record
- **THEN** the character's `name` field SHALL be returned; analogous accessors SHALL exist for every field

#### Scenario: Record provides mutators
- **WHEN** `(set-character-hp! player 3)` is called
- **THEN** `(character-hp player)` SHALL return 3; analogous mutators SHALL exist for every field

### Requirement: Global *player* holds the active character
The engine SHALL maintain a `*player*` global variable holding the current character record. The engine SHALL provide `(init-player!)`, which resets `*player*` to a fresh character record with all fields set to `#f` and an empty inventory list.

#### Scenario: Player is #f before initialization
- **WHEN** the engine source is loaded but `init-player!` has not yet been called
- **THEN** `*player*` SHALL be `#f`

#### Scenario: init-player! creates a blank character
- **WHEN** `(init-player!)` is called
- **THEN** `*player*` SHALL be set to a character record whose fields are all `#f` except `inventory`, which SHALL be the empty list `'()`

#### Scenario: init-player! is called at load time in the web build and tests
- **WHEN** `browser-boot.scm` loads (either under `ece-build` for the web target or under `tests/run-all.scm`)
- **THEN** `(init-player!)` SHALL be called so that `*player*` is non-`#f` before any room function executes

