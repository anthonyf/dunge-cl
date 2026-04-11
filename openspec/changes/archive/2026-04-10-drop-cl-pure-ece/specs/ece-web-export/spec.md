## MODIFIED Requirements

### Requirement: Build produces standalone HTML file
The build process SHALL produce a `dist/` directory containing `index.html` and supporting JS/WASM files. Opening `index.html` in a browser SHALL start the game with no server required (standalone mode uses base64-encoded assets loaded via `<script src>`). The build SHALL use `ece-build --target web --standalone` with the ECE WASM runtime.

#### Scenario: Build and open
- **WHEN** `scripts/build-web.sh` is run
- **THEN** `dist/index.html` SHALL be produced and opening it in a browser SHALL display the game start screen

### Requirement: Game files pre-parsed at build time
The build process SHALL compile all .scm files into `.ecec` bytecode bundles using `ece-build`. The browser SHALL load pre-compiled bytecode, not raw .scm source.

#### Scenario: Bytecode bundles used
- **WHEN** the web build compiles game files
- **THEN** `ece-build` SHALL produce `app.ecec` bytecode and package it as base64 in `app.js`

### Requirement: Browser I/O uses call/cc
The browser SHALL use ECE's `call/cc` to suspend the game loop at `read-line` calls, yield to the browser event loop, and resume when the user provides input. The `browser-step` function SHALL be exported to JavaScript via ECE's FFI `js-callback` mechanism. The same game loop code SHALL work in both terminal and browser modes.

#### Scenario: browser-step exported via FFI
- **WHEN** `browser-boot.scm` loads in the browser
- **THEN** `browser-step` SHALL be registered on `window.browserStep` via `js-callback`

#### Scenario: Choice selection via continuation
- **WHEN** the game displays choices and the user clicks a button
- **THEN** the stored continuation SHALL be resumed with the user's selection and the game SHALL continue

#### Scenario: Text prompt via continuation
- **WHEN** the game displays a text prompt (e.g., "What is your name?")
- **THEN** a text input SHALL appear and submitting it SHALL resume the continuation with the entered text

#### Scenario: FFI export skipped in CLI mode
- **WHEN** `browser-boot.scm` loads under the `ece` CLI (not in browser)
- **THEN** the FFI export SHALL be silently skipped via `guard` without error

### Requirement: Output rendered to DOM
Game output from `display` and `newline` SHALL be buffered by overriding `ECE.io` handlers in JavaScript and rendered to the DOM as styled HTML after each interaction step. The JS renderer SHALL parse output to extract choices and prompts.

#### Scenario: Game text appears in browser
- **WHEN** the game displays room descriptions and choices
- **THEN** the text SHALL appear in the browser and numbered choices SHALL become clickable buttons

### Requirement: Deploy produces clean gh-pages
The deploy workflow SHALL NOT preserve files from previous deployments. Each deploy SHALL completely replace the gh-pages content with the current `dist/` output.

#### Scenario: Stale files removed on deploy
- **WHEN** a new deploy runs after old JSCL-based files exist on gh-pages
- **THEN** the old files SHALL be removed and only the new ECE WASM build output SHALL remain

## REMOVED Requirements

### Requirement: JSCL bootstrap with new API
**Reason**: JSCL is replaced by ECE's WASM runtime. No more JSCL bootstrap step.
**Migration**: `ece-build --target web` handles compilation to WASM bytecode.

### Requirement: ECE source filtered at form level
**Reason**: The form-level CL reader/filter was specific to the JSCL build pipeline. `ece-build` compiles .scm files directly.
**Migration**: No migration needed — `ece-build` handles compilation natively.

### Requirement: handler-case and eval-when pass through to JSCL
**Reason**: JSCL is removed. ECE compiles directly to WASM bytecode.
**Migration**: No migration needed — ECE natively supports `handler-case` and `eval-when`.

### Requirement: Browser boot errors are surfaced
**Reason**: The JSCL-specific error surfacing mechanism is replaced by standard WASM error handling. ECE's WASM runtime throws JS errors on runtime failures.
**Migration**: Standard browser error handling (try/catch in boot sequence) replaces JSCL-specific `console.error` patches.
