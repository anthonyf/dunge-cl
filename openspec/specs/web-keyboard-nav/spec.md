### Requirement: Arrow key navigation between choice buttons
The browser UI SHALL support arrow key navigation between choice buttons. `ArrowDown` and `ArrowRight` SHALL move focus to the next button; `ArrowUp` and `ArrowLeft` SHALL move focus to the previous button. Navigation SHALL wrap around (last to first, first to last).

#### Scenario: Navigate down through choices
- **WHEN** a choice button is focused and the user presses ArrowDown
- **THEN** the next choice button SHALL receive focus, or the first button if the last was focused

#### Scenario: Navigate up through choices
- **WHEN** a choice button is focused and the user presses ArrowUp
- **THEN** the previous choice button SHALL receive focus, or the last button if the first was focused

### Requirement: Enter and Space activate focused button
The browser UI SHALL activate the focused choice button when the user presses Enter or Space. This SHALL trigger the same action as clicking the button.

#### Scenario: Press Enter on focused choice
- **WHEN** a choice button is focused and the user presses Enter
- **THEN** the game SHALL advance as if the user clicked that button

#### Scenario: Press Space on focused choice
- **WHEN** a choice button is focused and the user presses Space
- **THEN** the game SHALL advance as if the user clicked that button

### Requirement: Number key shortcuts for choices
The browser UI SHALL support pressing number keys 1-9 to directly activate the corresponding choice, regardless of which element is focused. Number key shortcuts SHALL NOT activate when a text input is focused.

#### Scenario: Press number key to select choice
- **WHEN** three choices are displayed and the user presses the "2" key
- **THEN** the second choice SHALL be activated

#### Scenario: Number keys ignored during text input
- **WHEN** a text prompt input is focused and the user presses "1"
- **THEN** the character "1" SHALL be typed into the input and no choice SHALL be activated

### Requirement: Auto-focus first choice after render
After each game step renders choice buttons, the first choice button SHALL automatically receive focus. This SHALL allow keyboard users to immediately begin navigating without tabbing.

#### Scenario: First button focused on render
- **WHEN** a new game step renders with choice buttons
- **THEN** the first choice button SHALL have focus

#### Scenario: Text input focused on prompt render
- **WHEN** a new game step renders with a text prompt
- **THEN** the text input SHALL have focus (existing behavior preserved)

### Requirement: Visual focus indicator on buttons
Focused choice buttons SHALL display a visible focus indicator distinguishable from the hover state. The focus indicator SHALL use the accent color (#e94560) for consistency with the existing prompt input focus style.

#### Scenario: Focused button visually distinct
- **WHEN** a choice button receives focus via keyboard navigation
- **THEN** the button SHALL display a visible border or glow effect using the accent color
