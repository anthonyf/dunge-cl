## 1. Cleanup

- [x] 1.1 Delete `tests/web/` directory (stale old-engine tests)

## 2. Test Harness

- [x] 2.1 Create `tests/test-harness.scm`: `string-contains?`, assertion functions (`assert-equal`, `assert-true`, `assert-false`, `assert-output-contains`), `define-test`, `run-tests`, `with-fresh-state`, `test-step`
- [x] 2.2 Create `run-tests.lisp`: load ECE + game files + browser-boot.scm, patch display/newline to output buffer, install browser-read-line as read-line, load test files, run tests, exit with appropriate code

## 3. Unit Tests

- [x] 3.1 Create `tests/unit/test-dice.scm`: test `roll-die` range, `roll-dice` count, deterministic results with seeded PRNG
- [x] 3.2 Create `tests/unit/test-items.scm`: test item creation, `item-display-name` for regular and stackable items, `consume-item!`
- [x] 3.3 Create `tests/unit/test-combat.scm`: test `resolve-attack` damage calculation, armor reduction, STR spillover, critical save, `resolve-heal`, ability saves with seeded PRNG

## 4. Integration Tests

- [x] 4.1 Create `tests/integration/test-char-creation.scm`: script character creation flow (start → name prompt → background selection → stat rolling → equipment → summary)
- [x] 4.2 Create `tests/integration/test-navigation.scm`: script town navigation (town-square → adventure-board → back)

## 5. Verification

- [x] 5.1 Run full test suite (`sbcl --non-interactive --load run-tests.lisp`), verify all tests pass
