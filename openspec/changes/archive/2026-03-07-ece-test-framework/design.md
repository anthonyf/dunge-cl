## Context

All game logic is in ECE .scm files. Two UIs exist: terminal (SBCL, synchronous read-line) and browser (JSCL, call/cc suspension at read-line). The browser's `browser-step`/`browser-read-line` pattern already provides a "feed input, get output" interface that can drive headless testing without any DOM.

## Goals / Non-Goals

**Goals:**
- ECE-native test harness that runs in SBCL (fast, no browser needed)
- Unit tests for isolated game functions (combat math, dice, items)
- Integration tests that script full game flows via the call/cc step pattern
- Deterministic tests (seeded PRNG, state reset between tests)
- Simple CLI runner: `sbcl --load run-tests.lisp`
- Delete stale old-engine web tests

**Non-Goals:**
- Full Playwright browser test suite (just one smoke test to verify the build works)
- Test coverage metrics
- Mocking framework

## Decisions

### ECE-native test harness

The test harness is written in ECE (.scm) so tests can directly call game functions. It provides:

- `define-test`: registers a named test thunk
- `assert-equal`, `assert-true`, `assert-false`: basic assertions that record failures
- `assert-output-contains`: checks if the output buffer contains a substring
- `run-tests`: executes all registered tests, reports pass/fail counts
- `with-fresh-state`: macro that resets `*player*`, `*current-room*`, `*current-encounter*`, `*resume-continuation*` before a test

```scheme
(define-test "resolve-attack deals damage through armor"
  (with-fresh-state
    (random-seed! 42)
    ;; ... test body ...
    (assert-equal 3 (enemy-hp enemy))))
```

### Two test styles

**Unit tests** call game functions directly:

```scheme
(define-test "roll-die returns value in range"
  (random-seed! 100)
  (let ((result (roll-die 6)))
    (assert-true (>= result 1))
    (assert-true (<= result 6))))
```

**Integration tests** use the browser-step pattern to script game flows:

```scheme
(define-test "character creation flow"
  (with-fresh-state
    (random-seed! 42)
    (let ((out (test-step nil)))           ;; start game
      (assert-output-contains "Welcome" out)
      (let ((out (test-step "1")))          ;; Continue
        (assert-output-contains "name" out)
        (let ((out (test-step "TestHero"))) ;; enter name
          (assert-output-contains "TestHero" out))))))
```

Integration tests reuse `browser-boot.scm`'s call/cc machinery. The test runner patches `display`/`newline` to write to an output buffer (same as the browser patches), loads `browser-boot.scm`, and installs `browser-read-line` as `read-line`.

### test-step function

```scheme
(define *test-output* "")

(define (test-step input)
  "Feed input to the game, return accumulated output."
  (set *test-output* "")
  (browser-step input)
  *test-output*)
```

This is the same as what JS does when calling `browserStep()`, minus the JSCL string conversion.

### State reset

Each test needs clean state. `with-fresh-state` resets:
- `(init-player!)` — fresh player record
- `(set *current-room* nil)` — no active room
- `(set *current-encounter* nil)` — no active combat
- `(set *resume-continuation* nil)` — clear call/cc state
- `(set *top-continuation* nil)` — clear call/cc state

For integration tests, `browser-step` re-enters via `(start-game 'start)` when `*resume-continuation*` is nil, so resetting continuations effectively restarts the game.

### CL runner script

`run-tests.lisp` loads ECE, loads all game files (same as main.scm but without `start-game`), loads `browser-boot.scm`, patches I/O to buffer mode, loads test files, and runs them. Exit code reflects pass/fail.

```bash
sbcl --non-interactive --load run-tests.lisp
# Exit 0 = all pass, Exit 1 = failures
```

### String search utility

ECE doesn't have `string-contains?`. The test harness defines it:

```scheme
(define (string-contains? haystack needle)
  "Return #t if needle appears anywhere in haystack."
  (let ((hlen (string-length haystack))
        (nlen (string-length needle)))
    (if (> nlen hlen) nil
        (let loop ((i 0))
          (cond
            ((> (+ i nlen) hlen) nil)
            ((equal? (substring haystack i (+ i nlen)) needle) t)
            (else (loop (+ i 1))))))))
```

### Playwright smoke test

One minimal Playwright test that builds dist/index.html, opens it, calls `browserStep(null)`, and asserts the output contains "Welcome". This verifies the full JSCL build pipeline works. Not a game logic test — just "does it start?"

### File organization

```
tests/
  test-harness.scm          — framework (assertions, runner, utilities)
  unit/
    test-dice.scm            — dice rolling tests
    test-combat.scm          — combat resolution tests
    test-items.scm           — item system tests
  integration/
    test-char-creation.scm   — character creation flow
    test-navigation.scm      — room navigation
  browser/
    smoke.spec.js            — Playwright smoke test
run-tests.lisp               — CL runner script
```

## Risks / Trade-offs

- **Integration test brittleness**: Tests that assert on output text will break if room descriptions change. Mitigation: keep integration tests focused on flow (room transitions, state changes) rather than exact wording where possible. Use `assert-output-contains` with short distinctive phrases.
- **Combat test determinism**: Seeded PRNG makes tests reproducible, but the seed-to-outcome mapping depends on how many random calls occur. If game code adds a new `random` call before the tested one, seeds shift. Mitigation: seed immediately before the operation under test.
- **No `string-contains?` in ECE**: Need to add it as a test utility. Could later move to ECE prelude if useful elsewhere.
