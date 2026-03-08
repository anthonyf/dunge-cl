## ADDED Requirements

### Requirement: Test harness provides assertion functions
The test harness SHALL provide `assert-equal`, `assert-true`, `assert-false`, and `assert-output-contains` functions that record failures without aborting the test.

#### Scenario: Assertion passes
- **WHEN** `(assert-equal 3 3)` is called
- **THEN** no failure SHALL be recorded

#### Scenario: Assertion fails
- **WHEN** `(assert-equal 3 5)` is called
- **THEN** a failure SHALL be recorded with a message describing expected vs actual

#### Scenario: Output assertion
- **WHEN** `(assert-output-contains "Welcome" "Welcome to Dunge!")` is called
- **THEN** no failure SHALL be recorded

### Requirement: Tests are registered and run by name
The test harness SHALL provide `define-test` to register named tests and `run-tests` to execute all registered tests, reporting pass/fail counts.

#### Scenario: Run tests and report
- **WHEN** 3 tests are registered and `run-tests` is called
- **THEN** all 3 tests SHALL execute and the runner SHALL print a summary with pass/fail counts

#### Scenario: Test failure does not abort run
- **WHEN** a test contains a failing assertion
- **THEN** the test SHALL be marked as failed but subsequent tests SHALL still run

### Requirement: Integration tests drive game via call/cc step
Integration tests SHALL use the `browser-step`/`browser-read-line` call/cc pattern to feed inputs and collect outputs without any UI.

#### Scenario: Script a game flow
- **WHEN** `(test-step nil)` is called followed by `(test-step "1")`
- **THEN** the game SHALL start, process the choice, and return accumulated output text

### Requirement: Tests run deterministically
Tests SHALL be able to seed the PRNG via `(random-seed!)` for deterministic results, and `with-fresh-state` SHALL reset all game state between tests.

#### Scenario: Seeded combat produces consistent results
- **WHEN** `(random-seed! 42)` is called before a combat resolution
- **THEN** the same damage values SHALL result every time

### Requirement: CLI runner exits with appropriate code
`run-tests.lisp` SHALL exit with code 0 when all tests pass and code 1 when any test fails.

#### Scenario: All tests pass
- **WHEN** `sbcl --non-interactive --load run-tests.lisp` is run and all tests pass
- **THEN** the exit code SHALL be 0

#### Scenario: Some tests fail
- **WHEN** `sbcl --non-interactive --load run-tests.lisp` is run and some tests fail
- **THEN** the exit code SHALL be 1 and failure details SHALL be printed
