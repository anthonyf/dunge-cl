## 1. Fix parameter shadowing

- [x] 1.1 Rename `enemy-name` parameter to `name` in `run-combat` function signature (game/combat.scm line 289)
- [x] 1.2 Update the reference to `enemy-name` on line 292 (`make-enemy-from-bestiary enemy-name`) to use the new parameter name

## 2. Verify

- [x] 2.1 Run `make test` to confirm no regressions
- [x] 2.2 Run `make build` to confirm web build succeeds
