## REMOVED Requirements

### Requirement: Game loop renders rooms and processes input
**Reason**: No trampoline loop needed. Room functions call each other directly via TCO.
**Migration**: Room functions handle their own display and transfer control to the next room via direct function calls.

### Requirement: Navigation via goto
**Reason**: `goto` is replaced by direct function calls. `(goto 'library)` becomes `(library)`.
**Migration**: Replace all `(goto 'room-name)` with `(room-name)` in choose actions.

## MODIFIED Requirements

### Requirement: CL bootstrap starts the ECE game
A CL function SHALL load and evaluate the ECE game scripts, starting the game by calling the first room function directly.

#### Scenario: Starting the ECE game from CL
- **WHEN** the bootstrap function is called from the CL REPL
- **THEN** ECE SHALL load the game scripts and call `(start)` which begins the game at the starting room

### Requirement: Dice rolling
The engine SHALL provide `(roll-die sides)` returning a random integer from 1 to sides, and `(roll-dice n sides)` returning a list of n such rolls.

#### Scenario: roll-die returns value in range
- **WHEN** `(roll-die 6)` is called
- **THEN** the result SHALL be an integer between 1 and 6 inclusive

#### Scenario: roll-dice returns correct number of rolls
- **WHEN** `(roll-dice 3 6)` is called
- **THEN** the result SHALL be a list of 3 integers each between 1 and 6 inclusive
