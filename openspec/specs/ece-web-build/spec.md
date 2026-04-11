## ADDED Requirements

### Requirement: Web build uses ece-build
The web build SHALL use `ece-build --target web --standalone` to compile game .scm files and `browser-boot.scm` into a WASM-based web application. The JSCL-based `web-export.lisp` SHALL be deleted.

#### Scenario: Build produces playable web app
- **WHEN** a user runs `make build`
- **THEN** `dist/` SHALL contain a playable web application that can be opened in a browser

#### Scenario: JSCL infrastructure removed
- **WHEN** the migration is complete
- **THEN** `web-export.lisp`, `vendor/jscl/`, and `.gitmodules` SHALL NOT exist

### Requirement: Custom game template
The build SHALL use a custom `web/index.html` template that includes the game-specific CSS (dark theme, choice buttons, prompt inputs, fade-in animations) and JS renderer (output parsing, choice/prompt rendering, keyboard navigation). The template SHALL load ece-build's generated JS files (`ece-runtime.js`, `ece-bootstrap.js`, `app.js`).

#### Scenario: Custom CSS applied
- **WHEN** the game is opened in a browser
- **THEN** it SHALL display with the dark theme, styled choice buttons, and prompt inputs matching the current game design

#### Scenario: JS renderer parses output
- **WHEN** game output contains numbered choice lines (e.g., "  1. Go north")
- **THEN** the renderer SHALL parse them into clickable buttons

### Requirement: Build version stamping
The build SHALL embed a git SHA and timestamp into the HTML page. The build script SHALL read `COMMIT_SHA` and `BUILD_TIME` environment variables (for CI) or fall back to `git rev-parse --short HEAD` and current UTC time.

#### Scenario: Version displayed
- **WHEN** a user views the built page
- **THEN** a version string (e.g., "v abc1234 . 2026-04-09 12:00 UTC") SHALL appear at the bottom

#### Scenario: CI provides version
- **WHEN** `COMMIT_SHA` and `BUILD_TIME` environment variables are set
- **THEN** the build script SHALL use those values instead of running git commands

### Requirement: Build script
A `scripts/build-web.sh` script SHALL orchestrate the web build: run `ece-build`, copy the custom template to `dist/`, and inject version information.

#### Scenario: Build script is executable
- **WHEN** a user runs `scripts/build-web.sh`
- **THEN** it SHALL produce the complete `dist/` output

### Requirement: CI workflows use ECE
Both `.github/workflows/ci.yml` and `deploy.yml` SHALL install ECE (via `git clone` + `make install`) instead of SBCL. Tests SHALL run via `ece tests/run-all.scm`. Web build SHALL run via `scripts/build-web.sh`.

#### Scenario: CI installs ECE
- **WHEN** a CI workflow runs
- **THEN** it SHALL clone the ECE repo and run `make install` to produce `ece` and `ece-build` binaries

#### Scenario: Deploy workflow builds with ECE
- **WHEN** a push to main triggers the deploy workflow
- **THEN** it SHALL run tests with `ece`, build with `scripts/build-web.sh`, and deploy `dist/` to gh-pages
