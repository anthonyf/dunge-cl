## 1. Record Definition

- [x] 1.1 Add `define-record character name background str dex wil hp hp-max armor gold fate inventory` to engine.scm
- [x] 1.2 Add `(define *player* nil)` global to engine.scm
- [x] 1.3 Add `player-ref` function that returns a lazy lookup thunk for a field name
- [x] 1.4 Add `init-player!` helper that creates a blank character with nil fields and empty inventory

## 2. Remove State System

- [x] 2.1 Remove `*state*`, `state-get`, `state-set!`, `state-ref` from engine.scm

## 3. Update Content

- [x] 3.1 Replace `state-set!` calls with record mutators in character creation rooms (character-info, choose-background, roll-stats, roll-hp, equipment, fate-points)
- [x] 3.2 Replace `state-get` calls with record accessors in content display (character-summary, equipment display, stat display)
- [x] 3.3 Replace `state-ref` calls with `player-ref` in text elements
- [x] 3.4 Replace temporary flag checks (`stats-rolled`, `hp-rolled`, `equipped`) with nil-field checks
- [x] 3.5 Call `init-player!` at game start (in start room or game bootstrap)

## 4. Verify

- [x] 4.1 Test full playthrough: character creation through town navigation
