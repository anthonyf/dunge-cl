## MODIFIED Requirements

### Requirement: Version injected at build time
The build process SHALL read `COMMIT_SHA` and `BUILD_TIME` from environment variables and inject them into the HTML template. For local builds, the process SHALL fall back to the first 7 characters of `git rev-parse HEAD` and a UTC timestamp produced by `date -u`.

#### Scenario: CI build sets version from environment
- **WHEN** the deploy workflow runs with `COMMIT_SHA` and `BUILD_TIME` environment variables set
- **THEN** the built `index.html` SHALL contain those values in the version display

#### Scenario: Local build without environment variables
- **WHEN** `scripts/build-web.sh` is run without `COMMIT_SHA` or `BUILD_TIME` set
- **THEN** the build SHALL use the first 7 characters of `git rev-parse HEAD` for the SHA (via `SHA="${RAW_SHA:0:7}"`) and `date -u +'%Y-%m-%d %H:%M UTC'` for the timestamp
