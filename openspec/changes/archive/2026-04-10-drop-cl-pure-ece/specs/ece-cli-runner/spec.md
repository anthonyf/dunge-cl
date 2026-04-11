## ADDED Requirements

### Requirement: Game runs via ece CLI
The game SHALL be runnable via `ece game/main.scm` with no SBCL, qlot, or ASDF dependency. The `ece` CLI SHALL load and execute all game .scm files in dependency order as defined by `game/main.scm`.

#### Scenario: Terminal game starts
- **WHEN** a user runs `ece game/main.scm`
- **THEN** the game SHALL display the welcome screen and accept terminal input via `read-line`

#### Scenario: Make run target
- **WHEN** a user runs `make run`
- **THEN** the Makefile SHALL invoke `ece game/main.scm`

### Requirement: Game code uses standard Scheme booleans
All game .scm files SHALL use `#f` for false and `#t` for true. The CL-isms `nil` and `t` SHALL NOT appear as boolean values in any .scm file.

#### Scenario: No nil or t as booleans
- **WHEN** any .scm file under `game/`, `tests/`, or root is loaded by the `ece` CLI
- **THEN** no "Unbound variable: nil" or "Unbound variable: t" error SHALL occur

### Requirement: CL bootstrap removed
The CL bootstrap file (`src/ece-bootstrap.lisp`), ASDF system definition (`dunge.asd`), and qlot dependency files (`qlfile`, `qlfile.lock`) SHALL be deleted. The `src/` directory SHALL be removed.

#### Scenario: No CL files remain
- **WHEN** the migration is complete
- **THEN** the files `dunge.asd`, `qlfile`, `qlfile.lock`, `src/ece-bootstrap.lisp` SHALL NOT exist
