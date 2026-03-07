## MODIFIED Requirements

### Requirement: Room elements include combat-encounter type
The engine's `render-element` SHALL dispatch on a `'combat-encounter` element type. This element runs a combat state machine: sets up the encounter on first visit, shows combat choices when active, and renders outcome elements (victory/death/incapacitated/fled) on terminal states.

#### Scenario: Combat encounter renders intro then choices
- **WHEN** a room with a `combat-encounter` element is entered for the first time
- **THEN** the intro text SHALL be displayed, a first-round DEX save SHALL occur, and combat choices SHALL be returned

#### Scenario: Combat encounter renders victory
- **WHEN** the encounter state becomes `'victory`
- **THEN** the victory elements SHALL be rendered and the encounter SHALL be cleared
