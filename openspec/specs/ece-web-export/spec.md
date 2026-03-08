### Requirement: Build produces standalone HTML file
The build process SHALL produce a single `dist/index.html` file that contains all JavaScript (JSCL runtime + compiled game) inlined. Opening this file in a browser SHALL start the game with no server required. The build SHALL use JSCL package `:jscl-xc` and the new `bootstrap(output-directory, prefix)` API.

#### Scenario: Build and open
- **WHEN** `sbcl --load web-export.lisp` is run
- **THEN** `dist/index.html` SHALL be produced and opening it in a browser SHALL display the game start screen

#### Scenario: JSCL bootstrap with new API
- **WHEN** the build bootstraps JSCL
- **THEN** it SHALL call `(jscl-xc:bootstrap output-dir "jscl")` with the correct output directory

### Requirement: Game files pre-parsed at build time
The build process SHALL read all .scm files (prelude + game/) using ECE's custom readtable at build time and serialize them as CL data for JSCL compilation. The browser SHALL NOT need ECE's reader or custom readtable.

#### Scenario: Custom syntax works in browser
- **WHEN** game code uses ECE's `{}` hash table syntax or quasiquote
- **THEN** it SHALL work correctly because it was parsed at build time by SBCL

### Requirement: Browser I/O uses call/cc
The browser SHALL use ECE's `call/cc` to suspend the game loop at `read-line` calls, yield to the browser event loop, and resume when the user provides input. The same game loop code SHALL work in both terminal and browser modes.

#### Scenario: Choice selection via continuation
- **WHEN** the game displays choices and the user clicks a button
- **THEN** the stored continuation SHALL be resumed with the user's selection and the game SHALL continue

#### Scenario: Text prompt via continuation
- **WHEN** the game displays a text prompt (e.g., "What is your name?")
- **THEN** a text input SHALL appear and submitting it SHALL resume the continuation with the entered text

### Requirement: Output rendered to DOM
Game output from `display` and `newline` SHALL be buffered and rendered to the DOM as text after each interaction step. The JS renderer SHALL NOT treat an empty output string as "no output" — only `null`, `undefined`, or the explicit `'WAITING'` sentinel SHALL cause the renderer to skip rendering.

#### Scenario: Game text appears in browser
- **WHEN** the game displays room descriptions and choices
- **THEN** the text SHALL appear in the browser and numbered choices SHALL become clickable buttons

#### Scenario: Empty output buffer does not cause blank screen
- **WHEN** `browserStep` returns an empty string
- **THEN** the renderer SHALL proceed with rendering (showing an empty page with no controls) rather than bailing out

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

### Requirement: ECE source filtered at form level
The build process SHALL read ECE source as CL forms using SBCL's reader (with ECE's readtable) and filter by form type/name. The build SHALL NOT use text-based line scanning or parenthesis counting.

#### Scenario: Form-level filtering handles character literals
- **WHEN** ECE source contains `#"` or other CL character literals inside forms
- **THEN** the filter SHALL correctly identify form boundaries because it uses CL's reader, not text parsing

#### Scenario: Only I/O functions are filtered
- **WHEN** ECE source contains `handler-case` or `eval-when` forms
- **THEN** they SHALL be kept in the compiled output because JSCL supports them

### Requirement: handler-case and eval-when pass through to JSCL
ECE functions that use `handler-case` (e.g., `ece-try-eval`, `ece-string->number`) SHALL be compiled by JSCL directly without being stripped and replaced by patches.

#### Scenario: ece-try-eval uses handler-case in browser
- **WHEN** ECE code calls `ece-try-eval` in the browser
- **THEN** it SHALL use the original `handler-case`-based implementation compiled by JSCL
