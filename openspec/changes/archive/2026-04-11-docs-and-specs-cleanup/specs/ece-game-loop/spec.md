## MODIFIED Requirements

### Requirement: ECE CLI starts the game
The `ece` CLI SHALL load `game/main.scm`, which in turn loads all game `.scm` files in dependency order, calls `(init-player!)`, and calls `(start)` to begin the game at the starting room. There SHALL NOT be a Common Lisp bootstrap layer — `make run` invokes `vendor/ece/bin/ece game/main.scm` directly.

#### Scenario: Starting the ECE game from the CLI
- **WHEN** a user runs `vendor/ece/bin/ece game/main.scm` (or `make run`, which invokes the same command)
- **THEN** ECE SHALL load the game scripts and call `(start)`, which begins the game at the starting room

#### Scenario: No CL bootstrap is used
- **WHEN** the game is started via `make run`
- **THEN** no Common Lisp file (`src/ece-bootstrap.lisp`, `dunge.asd`, etc.) SHALL be loaded; the entire load sequence SHALL run under the ECE interpreter
