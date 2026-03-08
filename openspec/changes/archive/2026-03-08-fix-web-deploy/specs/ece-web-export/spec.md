## MODIFIED Requirements

### Requirement: Output rendered to DOM
Game output from `display` and `newline` SHALL be buffered and rendered to the DOM as text after each interaction step. The JS renderer SHALL NOT treat an empty output string as "no output" — only `null`, `undefined`, or the explicit `'WAITING'` sentinel SHALL cause the renderer to skip rendering.

#### Scenario: Game text appears in browser
- **WHEN** the game displays room descriptions and choices
- **THEN** the text SHALL appear in the browser and numbered choices SHALL become clickable buttons

#### Scenario: Empty output buffer does not cause blank screen
- **WHEN** `browserStep` returns an empty string
- **THEN** the renderer SHALL proceed with rendering (showing an empty page with no controls) rather than bailing out

## ADDED Requirements

### Requirement: Browser boot errors are surfaced
The browser boot sequence SHALL catch and log CL-level errors to `console.error`. JSCL errors that would otherwise be silent SHALL be surfaced in the browser developer console.

#### Scenario: Boot error logged to console
- **WHEN** an error occurs during ECE initialization in the browser
- **THEN** the error message SHALL appear in the browser's developer console via `console.error`

### Requirement: Deploy produces clean gh-pages
The deploy workflow SHALL NOT preserve files from previous deployments. Each deploy SHALL completely replace the gh-pages content with the current `dist/` output.

#### Scenario: Stale files removed on deploy
- **WHEN** a new deploy runs after old pre-ECE files exist on gh-pages
- **THEN** the old files (e.g., `dev/`, `dunge.js`, `jscl.js`) SHALL be removed and only `index.html` SHALL remain

### Requirement: browserStep returns debug info to console
The JS `step()` function SHALL log the raw output from `browserStep` to the browser console for debugging purposes.

#### Scenario: Console shows browserStep output
- **WHEN** the game runs in the browser with developer tools open
- **THEN** each call to `step()` SHALL log the raw `browserStep` return value to the console
