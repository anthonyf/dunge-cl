## ADDED Requirements

### Requirement: Web build uses ece-build
The web build SHALL use `ece-build --target web --standalone` to compile game .scm files and `browser-boot.scm` into a WASM-based web application. The JSCL-based `web-export.lisp` SHALL be deleted.

#### Scenario: Build produces playable web app
- **WHEN** a user runs `make build`
- **THEN** `dist/` SHALL contain a playable web application that can be opened in a browser

#### Scenario: JSCL infrastructure removed
- **WHEN** the migration is complete
- **THEN** `web-export.lisp` and `vendor/jscl/` SHALL NOT exist (`.gitmodules` is now used to vendor ECE at `vendor/ece/`)

### Requirement: Custom game template
The build SHALL use a custom `web/index.html` template that includes the game-specific CSS (dark theme, choice buttons, prompt inputs, fade-in animations) and JS renderer (output parsing, choice/prompt rendering, keyboard navigation). The template SHALL load ece-build's generated JS files (`ece-runtime.js`, `ece-bootstrap.js`, `app.js`).

#### Scenario: Custom CSS applied
- **WHEN** the game is opened in a browser
- **THEN** it SHALL display with the dark theme, styled choice buttons, and prompt inputs matching the current game design

#### Scenario: JS renderer parses output
- **WHEN** game output contains numbered choice lines (e.g., "  1. Go north")
- **THEN** the renderer SHALL parse them into clickable buttons

### Requirement: Build version stamping
The build SHALL embed a short git SHA and a UTC timestamp into the HTML page. The SHA SHALL be exactly 7 characters long, and the timestamp SHALL be formatted as `YYYY-MM-DD HH:MM UTC`, regardless of whether they came from the `COMMIT_SHA` / `BUILD_TIME` environment variables (set by CI) or from the local fallbacks (`git rev-parse HEAD` truncated to 7 chars and `date -u +'%Y-%m-%d %H:%M UTC'`).

When `COMMIT_SHA` is a full-length (40-char) commit hash, the build script SHALL truncate it to 7 characters before embedding. When `BUILD_TIME` is an ISO 8601 timestamp with a non-UTC timezone offset, the build script SHALL parse it and reformat it to UTC before embedding. If `BUILD_TIME` cannot be parsed, the build script SHALL embed the raw value as a passthrough rather than fail the build.

#### Scenario: Version displayed
- **WHEN** a user views the built page
- **THEN** a version string of the form `v abc1234 · 2026-04-09 12:00 UTC` (7-char SHA, middle-dot separator, UTC-formatted timestamp) SHALL appear at the bottom

#### Scenario: CI provides version
- **WHEN** `COMMIT_SHA` and `BUILD_TIME` environment variables are set
- **THEN** the build script SHALL use those values instead of running git commands or reading the system clock

#### Scenario: CI-provided version info is normalized
- **WHEN** CI sets `COMMIT_SHA` to a 40-character full commit hash and `BUILD_TIME` to an ISO 8601 timestamp with a non-UTC timezone offset (e.g., `2026-04-10T23:22:07-04:00`)
- **THEN** the embedded version string SHALL show a 7-character SHA and a `YYYY-MM-DD HH:MM UTC` timestamp, with the timestamp converted from the input timezone to UTC

#### Scenario: Malformed BUILD_TIME falls through
- **WHEN** `BUILD_TIME` is set to a value the build script cannot parse
- **THEN** the build SHALL succeed and the raw `BUILD_TIME` value SHALL appear in the version string verbatim (no crash, no empty timestamp)

### Requirement: Build script
A `scripts/build-web.sh` script SHALL orchestrate the web build: run `ece-build`, copy the custom template to `dist/`, and inject version information.

#### Scenario: Build script is executable
- **WHEN** a user runs `scripts/build-web.sh`
- **THEN** it SHALL produce the complete `dist/` output

### Requirement: CI workflows use ECE

Both `.github/workflows/ci.yml` and `deploy.yml` SHALL obtain ECE from the `vendor/ece` git submodule instead of inline `git clone` + `make install`. Workflows SHALL check out the repository with `submodules: recursive`, cache the built ECE binaries via `actions/cache` keyed on the submodule commit SHA, and invoke `make test` / `make build` (which in turn use the submodule-built binaries) rather than calling `ece` / `ece-build` directly. SBCL, qlot, and binaryen install steps remain in the workflows because they are required when the cache misses and the submodule must be rebuilt, but the workflow SHALL annotate them as existing for the ECE submodule build, not for Dunge itself.

#### Scenario: CI uses the submodule
- **WHEN** a CI workflow runs
- **THEN** it SHALL check out the Dunge repository with `submodules: recursive` so `vendor/ece/` contains the pinned ECE source, and it SHALL NOT perform an inline `git clone https://github.com/anthonyf/ece.git` step

#### Scenario: CI caches built ECE between runs
- **WHEN** a CI workflow runs and the cache contains an entry matching the current `vendor/ece` submodule SHA
- **THEN** the workflow SHALL restore the cached `vendor/ece/bin/` and `vendor/ece/share/` directories and skip the ECE build step

#### Scenario: Deploy workflow builds with ECE
- **WHEN** a push to main triggers the deploy workflow
- **THEN** it SHALL run `make test`, run `make build` (with `COMMIT_SHA` / `BUILD_TIME` env vars passed through to `scripts/build-web.sh`), and deploy `dist/` to gh-pages
