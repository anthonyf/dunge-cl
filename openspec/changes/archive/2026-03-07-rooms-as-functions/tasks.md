## 1. Engine Core

- [x] 1.1 Rewrite `define-room` macro to register a function instead of a data structure
- [x] 1.2 Rewrite `text` macro to `(begin (display (fmt ...)) (newline))` — no thunks
- [x] 1.3 Add `choose` macro: build choices, display numbered menu, read input, execute action
- [x] 1.4 Add `ask` function: display prompt, read-line, validate, retry or call action
- [x] 1.5 Simplify `game-loop` to a trampoline: display title, call room fn, loop
- [x] 1.6 Remove dead code: `render-element`, `render-elements`, `render-room`, `player-ref`, `callable?`, `make-*-element`, element macros (`exit`, `gate`, `dynamic`, `prompt`, `combat-encounter`)

## 2. Combat Adaptation

- [x] 2.1 Extract combat encounter logic from `render-element` into a standalone `run-combat` function that takes enemy name, intro thunk, and outcome handler
- [x] 2.2 Move `combat-choices` integration into `run-combat` (choice display + read-line loop inside the function)

## 3. Room Conversions

- [x] 3.1 Convert character creation rooms (`start`, `character-info`, `choose-background`, `roll-stats`, `roll-hp`, `equipment`, `fate-points`, `character-summary`)
- [x] 3.2 Convert town rooms (`town-square`, `adventure-board`, `blacksmith`)
- [x] 3.3 Convert combat rooms (`test-combat`, `test-combat-victory`, `test-combat-death`, `test-combat-incapacitated`, `test-combat-fled`)

## 4. Tests

- [x] 4.1 Update integration tests (`test-char-creation.scm`, `test-navigation.scm`) — adjust step sequences if needed
- [x] 4.2 Run full test suite, verify all 36 tests pass
