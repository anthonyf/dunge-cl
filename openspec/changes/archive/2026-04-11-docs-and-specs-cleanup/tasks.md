## 1. Verify stale references against the code

- [x] 1.1 Confirm `qlfile`, `qlfile.lock`, `dunge.asd`, `src/ece-bootstrap.lisp`, `run-tests.lisp`, and `web-export.lisp` do not exist (`ls` each path; expect "not found")
- [x] 1.2 Confirm `define-room`, `*rooms*`, and `(goto ` (with a space, to avoid matching `goto` as a variable name inside strings) do not appear in any `.scm` file under `game/` or `tests/` (`grep -r` each term)
- [x] 1.3 Read `game/engine.scm` and record the exact `define-record character` field list; confirm it matches the list in this change's `ece-character-creation` delta (`name background str dex wil hp hp-max armor gold fate inventory`)
- [x] 1.4 Read `game/engine.scm` and locate `init-player!`; confirm it sets `*player*` to a character record with `#f` fields and an empty inventory list
- [x] 1.5 Confirm `player-ref` is absent from `game/` and `tests/` (`grep -r player-ref` should return no matches); this drives the decision to drop `player-ref` from the ece-character-creation delta rather than fold it in, since the function was deleted in archived change `2026-03-07-rooms-as-functions`
- [x] 1.6 Read `game/combat.scm` and record the current encounter record shape and the state-machine priority (`victory > death > incapacitated > fled > active`) so the DESIGN.md rewrite matches reality
- [x] 1.7 Read `game/bestiary.scm` and record the enemy `define-record` fields so the DESIGN.md line ~92 enemy-spec example can be ported from the plist form

## 2. Delete stale live specs

- [x] 2.1 Delete `openspec/specs/ece-integration/` (directory and its `spec.md`)
- [x] 2.2 Delete `openspec/specs/room-system/` (directory and its `spec.md`)
- [x] 2.3 Delete `openspec/specs/player-record/` (directory and its `spec.md`)
- [x] 2.4 Confirm `openspec list` no longer reports `ece-integration`, `room-system`, or `player-record` as active capabilities

## 3. Apply MODIFIED deltas to live specs

- [x] 3.1 Replace the first requirement in `openspec/specs/ece-game-loop/spec.md` ("CL bootstrap starts the ECE game") with the "ECE CLI starts the game" requirement from this change's delta; leave the dice-rolling requirements below it untouched
- [x] 3.2 Replace the "Local build without environment variables" scenario in `openspec/specs/web-version-display/spec.md` with the `scripts/build-web.sh` version from this change's delta; leave the surrounding requirement text and other scenarios intact

## 4. Absorb player-record requirements into ece-character-creation

- [x] 4.1 Add the "Character is defined as an ECE record" requirement (and its four scenarios) to `openspec/specs/ece-character-creation/spec.md`
- [x] 4.2 Add the "Global *player* holds the active character" requirement (and its three scenarios) to `openspec/specs/ece-character-creation/spec.md`
- [x] 4.3 Verify the merged spec reads coherently — backgrounds/equipment requirements should still be present alongside the new record and global `*player*` requirements

## 5. Rewrite DESIGN.md code blocks

- [x] 5.1 Replace the `lisp` enemy-spec example near DESIGN.md line ~92 with a Scheme `define-record` form matching `game/bestiary.scm`; update the surrounding prose if it still refers to plist syntax
- [x] 5.2 Rewrite DESIGN.md §Data Structures "Scene/Vignette" block (lines ~884–908): delete the `defclass vignette` block entirely, since the code has no vignette type. Replace with a brief note that rooms are plain Scheme functions and a cross-reference to `openspec/specs/ece-room-system/spec.md`
- [x] 5.3 Rewrite DESIGN.md §Data Structures "Choice" and "Condition Types" blocks (lines ~912–948): delete the `defclass choice` and `defclass *-condition` blocks. Replace with a brief description of the current `make-choice` helper and the guard-closure pattern from `game/engine.scm`, cross-referencing `ece-choice-system/spec.md`
- [x] 5.4 Rewrite DESIGN.md §Data Structures "Character" block (lines ~952–1020): replace the `defclass character` + `defun take-damage` block with a Scheme `define-record character` form using the exact field list from `game/engine.scm` (recorded in task 1.3). Port `take-damage` to a Scheme function sketch that matches `game/combat.scm` behavior (HP absorbs first, overflow to STR, STR save on spillover, death at STR ≤ 0)
- [x] 5.5 Rewrite DESIGN.md §Data Structures "Game State" block (lines ~1024–1054): the current `game-state` object does not exist. Move this block under a new "Future / Aspirational" subsection labelled clearly, and note that dungeon turns, wandering-monster checks, roll logging, and roll visibility settings are unimplemented Phase 3/7 goals tracked in `TODOs.org`
- [x] 5.6 Review DESIGN.md §Core Game Loop (lines ~775–877) and §Combat Loop — if the flow diagrams describe behavior that doesn't match `game/combat.scm` (e.g., the exact "first round: PC makes DEX save" wording), either correct them to match `update-encounter-state` or mark the section as aspirational. Prefer correcting over marking.

## 6. Validate and hand off

- [x] 6.1 Run `openspec validate docs-and-specs-cleanup --strict` and fix any reported issues
- [x] 6.2 Run `make test` as a sanity check (expect no behavior change — this task only modifies docs and specs)
- [x] 6.3 Run `make build` as a sanity check (expect no behavior change)
- [x] 6.4 Review the full diff with `git diff --stat` and confirm every touched path is under `openspec/` or `DESIGN.md` — no `game/`, `tests/`, `scripts/`, `Makefile`, or `.github/` changes should appear
- [x] 6.5 Stop and wait for user review before creating a PR — do not auto-merge
