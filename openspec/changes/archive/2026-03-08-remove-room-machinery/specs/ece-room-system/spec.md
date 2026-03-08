## REMOVED Requirements

### Requirement: Rooms are defined with define-room macro
**Reason**: Rooms are now plain `define` functions. No macro or registry needed.
**Migration**: Replace `(define-room name "Title" body...)` with `(define (name) (text "Title") (text "") body...)`.

### Requirement: Room elements include combat-encounter type
**Reason**: Combat is handled by `run-combat` function called directly from room functions. No element dispatch needed.
**Migration**: Room functions call `(run-combat ...)` directly and branch on the returned outcome symbol.

### Requirement: Exit elements produce navigation choices
**Reason**: Navigation is handled by the `choose` macro with direct function calls. No exit element type needed.
**Migration**: Use `(choose ("label" (room-fn)))` instead of `(exit "label" 'room-name)`.

### Requirement: Gate elements conditionally render content
**Reason**: Room functions use normal Scheme `if`/`cond`/`when` for conditional logic. No gate element needed.
**Migration**: Use standard conditionals in room function bodies.

## MODIFIED Requirements

### Requirement: Rooms render title and body text
Room functions SHALL display their title using `text` at the top of their body, then execute the remaining body expressions.

#### Scenario: Room displays title and text elements
- **WHEN** a room function with `(text "Town Square")` and `(text "You are in the town square.")` is called
- **THEN** the output SHALL show "Town Square" followed by "You are in the town square."

### Requirement: Text elements display content
A `text` call SHALL display its arguments concatenated together followed by a newline.

#### Scenario: Text with multiple arguments
- **WHEN** `(text "Hello " name "!")` is evaluated where name is "Aragorn"
- **THEN** the output SHALL display "Hello Aragorn!"

### Requirement: Prompt elements collect text input
The `ask` function SHALL display a question, read text input from the player, validate it, and execute an action with the valid input.

#### Scenario: Prompt with valid input
- **WHEN** `(ask "What is your name?" non-empty-string? callback)` is called and the player enters "Aragorn"
- **THEN** the callback SHALL be called with "Aragorn"

#### Scenario: Prompt with invalid input retries
- **WHEN** `ask` with a non-empty-string validator receives an empty string
- **THEN** the engine SHALL display an error and re-prompt until valid input is given

## ADDED Requirements

### Requirement: Rooms are plain functions
Rooms SHALL be defined as plain Scheme functions using `define`. Each room function SHALL display its title and content, then transfer control to the next room via a direct function call in tail position.

#### Scenario: Define and call a room
- **WHEN** `(define (my-room) (text "My Title") (text "Hello"))` is defined and `(my-room)` is called
- **THEN** the output SHALL display "My Title" followed by "Hello"

#### Scenario: Room navigation via direct call
- **WHEN** a room contains `(choose ("Go north" (library)))`
- **THEN** selecting "Go north" SHALL call the `library` function directly in tail position
