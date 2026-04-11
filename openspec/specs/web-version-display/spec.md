## ADDED Requirements

### Requirement: Build version displayed in browser UI
The web build SHALL display a version string containing the git commit SHA (7 characters) and build timestamp in the browser UI. The version SHALL appear as small, muted text at the bottom of the page.

#### Scenario: Version visible after deploy
- **WHEN** a user loads the deployed game page
- **THEN** a version string in the format `v <sha> · <YYYY-MM-DD HH:MM UTC>` SHALL be visible at the bottom of the page

#### Scenario: Version changes on each deploy
- **WHEN** a new commit is pushed and deployed
- **THEN** the displayed version string SHALL reflect the new commit SHA and build timestamp

### Requirement: Version injected at build time
The build process SHALL read `COMMIT_SHA` and `BUILD_TIME` from environment variables and inject them into the HTML template. For local builds, the process SHALL fall back to the first 7 characters of `git rev-parse HEAD` and a UTC timestamp produced by `date -u`.

#### Scenario: CI build sets version from environment
- **WHEN** the deploy workflow runs with `COMMIT_SHA` and `BUILD_TIME` environment variables set
- **THEN** the built `index.html` SHALL contain those values in the version display

#### Scenario: Local build without environment variables
- **WHEN** `scripts/build-web.sh` is run without `COMMIT_SHA` or `BUILD_TIME` set
- **THEN** the build SHALL use the first 7 characters of `git rev-parse HEAD` for the SHA (via `SHA="${RAW_SHA:0:7}"`) and `date -u +'%Y-%m-%d %H:%M UTC'` for the timestamp
