## ADDED Requirements

### Requirement: Tests run via pure ECE
All tests SHALL run via `ece tests/run-all.scm` with no SBCL dependency. The runner SHALL load game files, define test helpers, load test files, run tests, and exit with code 0 on success or 1 on failure.

#### Scenario: All tests pass
- **WHEN** a user runs `ece tests/run-all.scm`
- **THEN** all unit and integration tests SHALL execute and the process SHALL exit with code 0 if all pass

#### Scenario: Test failure exits non-zero
- **WHEN** any test fails
- **THEN** the process SHALL exit with code 1

#### Scenario: Make test target
- **WHEN** a user runs `make test`
- **THEN** the Makefile SHALL invoke `ece tests/run-all.scm`

### Requirement: Tests use ece-unit.scm API
Test files SHALL use ECE's built-in `ece-unit.scm` test API: `(test "name" (lambda () ...))` for registration, `assert-true`, `assert-equal`, `assert-false`, and `assert-error` for assertions. The custom `tests/test-harness.scm` SHALL be deleted.

#### Scenario: Test registration
- **WHEN** a test file registers a test
- **THEN** it SHALL use `(test "name" (lambda () body))` syntax

#### Scenario: Assertions
- **WHEN** a test checks a condition
- **THEN** it SHALL use `assert-true`, `assert-equal`, `assert-false`, or `assert-error` from ece-unit.scm

### Requirement: test-step implemented in pure ECE
The `test-step` function SHALL be implemented in pure ECE using `parameterize` and `open-output-string` to capture output from `browser-step`. It SHALL NOT depend on any CL-level patching.

#### Scenario: Integration test captures output
- **WHEN** an integration test calls `(test-step "1")`
- **THEN** `test-step` SHALL call `browser-step` with the input, capture all `display`/`newline` output via `parameterize` on `current-output-port`, and return the captured string

#### Scenario: Initial step with no input
- **WHEN** an integration test calls `(test-step #f)`
- **THEN** `browser-step` SHALL start the game and `test-step` SHALL return the welcome screen output

### Requirement: with-fresh-state resets game globals
The `with-fresh-state` macro SHALL reset `*player*` (via `init-player!`), `*current-encounter*`, `*resume-continuation*`, and `*top-continuation*` to `#f` before executing the test body.

#### Scenario: State isolation between tests
- **WHEN** two integration tests run sequentially
- **THEN** each test SHALL start with fresh game state regardless of what the previous test did

### Requirement: CL test runner removed
The CL-based test runner (`run-tests.lisp`) and custom test harness (`tests/test-harness.scm`) SHALL be deleted.

#### Scenario: No CL test files remain
- **WHEN** the migration is complete
- **THEN** `run-tests.lisp` and `tests/test-harness.scm` SHALL NOT exist
