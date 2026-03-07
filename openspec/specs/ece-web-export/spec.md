## ADDED Requirements

### Requirement: Build produces standalone HTML file
The build process SHALL produce a single `dist/index.html` file that contains all JavaScript (JSCL runtime + compiled game) inlined. Opening this file in a browser SHALL start the game with no server required.

#### Scenario: Build and open
- **WHEN** `sbcl --load web-export.lisp` is run
- **THEN** `dist/index.html` SHALL be produced and opening it in a browser SHALL display the game start screen

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
Game output from `display` and `newline` SHALL be buffered and rendered to the DOM as text after each interaction step.

#### Scenario: Game text appears in browser
- **WHEN** the game displays room descriptions and choices
- **THEN** the text SHALL appear in the browser and numbered choices SHALL become clickable buttons
