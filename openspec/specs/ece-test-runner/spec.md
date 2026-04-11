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
The `test-step` function SHALL be implemented in pure ECE and SHALL capture output from `browser-step` without any CL-level patching. Because `browser-step` uses `call/cc` to suspend and resume across test steps, the capture mechanism SHALL remain correct across continuation boundaries. `parameterize` on `current-output-port` is NOT a valid approach — `dynamic-wind` restores the old (now-closed) port when a captured continuation is re-invoked in a later `test-step`, routing output to a stale destination. Implementations SHOULD override the global `display` and `newline` procedures, gated by a `*in-test-step?*` flag, to append to a mutable buffer. The flag SHALL be reset even if `browser-step` raises, so a failing test does not corrupt the output of subsequent tests or the final report.

#### Scenario: Integration test captures output
- **WHEN** an integration test calls `(test-step "1")`
- **THEN** `test-step` SHALL call `browser-step` with the input, capture all `display`/`newline` output into a string buffer using a continuation-safe mechanism, and return the captured string

#### Scenario: Initial step with no input
- **WHEN** an integration test calls `(test-step #f)`
- **THEN** `browser-step` SHALL start the game and `test-step` SHALL return the welcome screen output

#### Scenario: Output capture survives continuation re-invocation
- **WHEN** a second `test-step` call resumes a `call/cc` continuation captured by a prior call
- **THEN** output written after the resume SHALL be captured into the current `test-step`'s buffer, not routed to a stale port from the prior step

#### Scenario: Flag is reset on test error
- **WHEN** `browser-step` raises an exception inside `test-step`
- **THEN** the in-test-step flag SHALL be reset to `#f` before the exception propagates, so subsequent `display`/`newline` calls (including the final test summary) reach stdout normally

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
