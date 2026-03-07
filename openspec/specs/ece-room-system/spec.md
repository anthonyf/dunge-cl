## ADDED Requirements

### Requirement: Rooms are defined with define-room macro
The engine SHALL provide a `define-room` macro that registers a room by name with a title and body elements. Rooms SHALL be stored in a global registry accessible by name.

#### Scenario: Define and retrieve a room
- **WHEN** `(define-room my-room "My Title" (text "Hello"))` is evaluated
- **THEN** the room SHALL be retrievable by the symbol `my-room` and contain the title "My Title"

### Requirement: Rooms render title and body text
When a room is rendered, the engine SHALL display the room title followed by a newline, then evaluate each body element in order.

#### Scenario: Room displays title and text elements
- **WHEN** a room with title "Town Square" and body `(text "You are in the town square.")` is rendered
- **THEN** the output SHALL show "Town Square" followed by "You are in the town square."

### Requirement: Text elements display content
A `text` element SHALL display its arguments concatenated together followed by a newline.

#### Scenario: Text with multiple arguments
- **WHEN** `(text "Hello " name "!")` is evaluated where name is "Aragorn"
- **THEN** the output SHALL display "Hello Aragorn!"

### Requirement: Exit elements produce navigation choices
An `exit` element SHALL produce a choice that, when selected, navigates to the specified room.

#### Scenario: Exit creates a navigable choice
- **WHEN** a room contains `(exit "Go north" 'library)`
- **THEN** a choice labeled "Go north" SHALL appear and selecting it SHALL navigate to the room named `library`

### Requirement: Gate elements conditionally render content
A `gate` element SHALL evaluate a condition and render either its then-branch or else-branch elements.

#### Scenario: Gate with true condition
- **WHEN** a gate's condition evaluates to true
- **THEN** the then-branch elements SHALL be rendered and the else-branch SHALL be skipped

#### Scenario: Gate with false condition
- **WHEN** a gate's condition evaluates to false
- **THEN** the else-branch elements SHALL be rendered (if provided) and the then-branch SHALL be skipped

### Requirement: Prompt elements collect text input
A prompt element SHALL display a question, read text input from the player, validate it, and execute an action with the valid input.

#### Scenario: Prompt with valid input
- **WHEN** a prompt asks "What is your name?" with a non-empty-string validator and the player enters "Aragorn"
- **THEN** the action function SHALL be called with "Aragorn"

#### Scenario: Prompt with invalid input retries
- **WHEN** a prompt with a non-empty-string validator receives an empty string
- **THEN** the engine SHALL display an error and re-prompt until valid input is given

### Requirement: Room elements include combat-encounter type
The engine's `render-element` SHALL dispatch on a `'combat-encounter` element type. This element runs a combat state machine: sets up the encounter on first visit, shows combat choices when active, and renders outcome elements (victory/death/incapacitated/fled) on terminal states.

#### Scenario: Combat encounter renders intro then choices
- **WHEN** a room with a `combat-encounter` element is entered for the first time
- **THEN** the intro text SHALL be displayed, a first-round DEX save SHALL occur, and combat choices SHALL be returned

#### Scenario: Combat encounter renders victory
- **WHEN** the encounter state becomes `'victory`
- **THEN** the victory elements SHALL be rendered and the encounter SHALL be cleared
