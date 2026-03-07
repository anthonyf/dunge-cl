## ADDED Requirements

### Requirement: Game loop renders rooms and processes input
The engine SHALL provide a game loop that renders the current room, presents choices or prompts to the player, reads input, executes the selected action, and repeats.

#### Scenario: Normal room with choices
- **WHEN** the current room produces a list of choices
- **THEN** the engine SHALL display the choices as a numbered menu, read the player's selection, execute the choice action, and continue the loop

#### Scenario: Room with prompt instead of choices
- **WHEN** a room body produces a prompt
- **THEN** the engine SHALL display the prompt question, read and validate input, execute the prompt action, and continue the loop

### Requirement: Navigation via goto
The engine SHALL provide a `goto` function that sets the next room to be rendered by the game loop.

#### Scenario: goto changes current room
- **WHEN** `(goto 'library)` is called within a choice action
- **THEN** the game loop SHALL render the room named `library` on the next iteration

### Requirement: CL bootstrap starts the ECE game
A CL function SHALL load and evaluate the ECE game scripts, starting the game loop.

#### Scenario: Starting the ECE game from CL
- **WHEN** the bootstrap function is called from the CL REPL
- **THEN** ECE SHALL load the game scripts and begin the game loop at the starting room

### Requirement: Dice rolling
The engine SHALL provide `(roll-die sides)` returning a random integer from 1 to sides, and `(roll-dice n sides)` returning a list of n such rolls.

#### Scenario: roll-die returns value in range
- **WHEN** `(roll-die 6)` is called
- **THEN** the result SHALL be an integer between 1 and 6 inclusive

#### Scenario: roll-dice returns correct number of rolls
- **WHEN** `(roll-dice 3 6)` is called
- **THEN** the result SHALL be a list of 3 integers each between 1 and 6 inclusive
