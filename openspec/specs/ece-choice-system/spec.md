## ADDED Requirements

### Requirement: Choices are displayed as a numbered menu
The engine SHALL display available choices as a numbered list and read the player's selection by number.

#### Scenario: Display and select from choices
- **WHEN** three choices are available with labels "Go north", "Go south", "Look around"
- **THEN** the engine SHALL display them numbered 1-3 and accept a number 1-3 as input

### Requirement: Invalid choice input is rejected
The engine SHALL reject input that is not a valid choice number and re-prompt.

#### Scenario: Non-numeric input
- **WHEN** the player enters "abc" at a choice prompt
- **THEN** the engine SHALL display an error and re-prompt

#### Scenario: Out-of-range input
- **WHEN** the player enters "5" but only 3 choices exist
- **THEN** the engine SHALL display an error and re-prompt

### Requirement: Choices support guard conditions
Choices MAY have a guard condition. Choices whose guard evaluates to false SHALL be filtered out before display.

#### Scenario: Guarded choice visible when condition is true
- **WHEN** a choice has a guard that evaluates to true
- **THEN** the choice SHALL appear in the menu

#### Scenario: Guarded choice hidden when condition is false
- **WHEN** a choice has a guard that evaluates to false
- **THEN** the choice SHALL NOT appear in the menu

### Requirement: Choice actions are executed on selection
When a player selects a choice, its action thunk SHALL be called.

#### Scenario: Choice action navigates to room
- **WHEN** a choice with action `(lambda () (goto 'library))` is selected
- **THEN** the game SHALL navigate to the room named `library`
