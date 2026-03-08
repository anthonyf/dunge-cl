## ADDED Requirements

### Requirement: Rooms are functions registered by name
`define-room` SHALL register a named function in the room registry. Entering a room SHALL execute that function.

#### Scenario: Define and enter a room
- **WHEN** `(define-room my-room "Title" (text "Hello"))` is evaluated
- **THEN** a function SHALL be stored in `*rooms*` under the key `my-room`

#### Scenario: Room function executes on entry
- **WHEN** the game navigates to `my-room`
- **THEN** the room's title SHALL be displayed followed by the function body executing

### Requirement: text macro displays formatted output
`(text arg1 arg2 ...)` SHALL concatenate all arguments as strings and display them followed by a newline. Arguments SHALL be evaluated at call time (no thunks).

#### Scenario: Text with player data
- **WHEN** `(text "HP: " (character-hp *player*))` is called and player HP is 6
- **THEN** the output SHALL contain "HP: 6" followed by a newline

### Requirement: choose macro presents numbered menu
`choose` SHALL display a numbered list of options, read player input, and execute the selected option's action.

#### Scenario: Two-option menu
- **WHEN** `(choose ("Go north" (goto 'north)) ("Go south" (goto 'south)))` is called
- **THEN** the output SHALL display "1. Go north" and "2. Go south", and the system SHALL wait for input

#### Scenario: Invalid input retries
- **WHEN** the player enters "5" for a 2-option menu
- **THEN** the system SHALL display an error and re-prompt

### Requirement: ask function handles text input with validation
`ask` SHALL display a prompt, read text input, validate it, and call an action function on success.

#### Scenario: Valid input
- **WHEN** `(ask "Name?" non-empty-string? handler)` is called and the player enters "Alice"
- **THEN** `handler` SHALL be called with "Alice"

#### Scenario: Invalid input retries
- **WHEN** the player enters an empty string for a non-empty-string? validation
- **THEN** the system SHALL display an error and re-prompt

### Requirement: goto navigates to another room
`(goto 'room-name)` SHALL set the current room so the game loop enters that room on the next iteration.

#### Scenario: Navigate between rooms
- **WHEN** `(goto 'town-square)` is called inside a room function
- **THEN** `*current-room*` SHALL be set to `town-square`

### Requirement: Game loop executes room functions in sequence
The game loop SHALL repeatedly look up the current room, display its title, execute its function, and loop until `*current-room*` is nil.

#### Scenario: Room chain
- **WHEN** room A calls `(goto 'B)` and room B calls `(goto 'C)`
- **THEN** the game loop SHALL execute A, then B, then C in sequence

### Requirement: No element types or renderer
The engine SHALL NOT use tagged-list element types or a render dispatcher. Room functions SHALL call display, choose, ask, and goto directly.

#### Scenario: No intermediary
- **WHEN** a room is defined
- **THEN** no intermediate data structure (tagged lists) SHALL be created for the room body
