## ADDED Requirements

### Requirement: Game content vertically centered in viewport
The game container SHALL be vertically centered in the browser viewport when content is shorter than the viewport height. When content exceeds the viewport height, the page SHALL scroll naturally from the top.

#### Scenario: Short content centered
- **WHEN** a game step renders text and choices that fit within the viewport
- **THEN** the game container SHALL be vertically centered in the viewport

#### Scenario: Long content scrolls from top
- **WHEN** a game step renders content taller than the viewport
- **THEN** the page SHALL scroll naturally and content SHALL start from the top

### Requirement: Content fade-in on step change
When new game content renders after a step, the output and controls SHALL fade in with a subtle CSS animation (approximately 150ms). The transition SHALL provide visual feedback that content has changed without feeling sluggish.

#### Scenario: New step fades in
- **WHEN** a game step renders new content replacing the previous content
- **THEN** the new text and controls SHALL fade in over approximately 150ms
