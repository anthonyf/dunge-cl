## Why

The old CL test files were deleted with the engine port to ECE. There are currently zero tests. All game logic lives in ECE .scm files shared by two UIs (terminal and browser). A test framework that runs at the ECE level can verify game logic independent of either UI, and the same call/cc machinery used for the browser can drive headless integration tests.

## What Changes

- Add an ECE test harness (`tests/test-harness.scm`) with assertion functions, test registration, and a runner
- Add ECE unit tests for core game systems: combat resolution, dice, items, room rendering
- Add ECE integration tests that use the browser-step/call/cc pattern to script game flows headlessly (character creation, room navigation, combat encounters)
- Add a CL test runner script (`run-tests.lisp`) that loads ECE + game + tests and reports results
- Delete the stale `tests/web/` directory (old CL engine tests)
- Add a Playwright smoke test that builds dist/index.html and verifies the game starts in a browser

## Capabilities

### New Capabilities

- `ece-test-harness`: ECE-native test framework with assertions, test registration, deterministic PRNG seeding, state reset, and both unit and integration test support
- `ece-test-runner`: CL-side script to load and run ECE tests from the command line

### Modified Capabilities

(none)

## Impact

- `tests/web/` — delete entirely (stale old-engine tests)
- `tests/test-harness.scm` — new ECE test framework
- `tests/unit/` — new unit test .scm files
- `tests/integration/` — new integration test .scm files
- `run-tests.lisp` — new CL runner script
- `game/` .scm files — no changes
