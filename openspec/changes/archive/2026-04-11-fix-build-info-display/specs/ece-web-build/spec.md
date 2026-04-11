## MODIFIED Requirements

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
