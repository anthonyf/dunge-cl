## 1. Engine Cleanup

- [x] 1.1 Remove `*rooms*`, `*current-room*`, `get-room`, `goto` from engine.scm
- [x] 1.2 Remove `define-room` macro from engine.scm
- [x] 1.3 Remove `game-loop` and `start-game` from engine.scm

## 2. Content Migration

- [x] 2.1 Convert all `define-room` forms in content.scm to plain `define` functions with title as first `text` call
- [x] 2.2 Replace all `(goto 'room-name)` with direct function calls `(room-name)` in content.scm

## 3. Entry Points

- [x] 3.1 Update browser-boot.scm: `(start-game 'start)` → `(start)`
- [x] 3.2 Update main.scm: `(start-game 'start)` → `(start)`

## 4. Test Updates

- [x] 4.1 Remove `*current-room*` reset from `with-fresh-state` in test-harness.scm
- [x] 4.2 Update integration tests to check output text instead of `*current-room*` assertions
- [x] 4.3 Run all tests and verify they pass
