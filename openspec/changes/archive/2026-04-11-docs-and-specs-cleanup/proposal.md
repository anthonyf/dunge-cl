## Why

The pure-ECE migration (PR #33) and the vendor-submodule migration (PR #40) deleted whole swaths of the old Common Lisp / JSCL / ASDF toolchain, but several live OpenSpec capability docs and large sections of `DESIGN.md` still describe the pre-migration world as if it were current. Readers (and future Claude sessions) treating those docs as ground truth will chase nonexistent files like `qlfile`, `dunge.asd`, `web-export.lisp`, and code constructs like `define-room` / `*rooms*` / `goto` that no longer exist in the codebase. We want the docs to match reality before they mislead someone.

## What Changes

- **Delete `openspec/specs/ece-integration/`** — its entire content describes `qlfile` + `(asdf:load-system :dunge)` + `dunge.asd :depends-on "ece"`, all of which were removed in PR #33. The actual ECE integration story is now owned by `ece-toolchain` (submodule build) and `ece-cli-runner` (invocation). **BREAKING** for anyone reading the spec as canonical.
- **Delete `openspec/specs/room-system/`** — describes the pre-PR #31 `define-room` macro, `*rooms*` registry, `goto` navigation, and "text macro." None of those symbols exist in `game/engine.scm`. The canonical room model lives in `ece-room-system/spec.md`. **BREAKING** for anyone reading the spec as canonical.
- **Rewrite `openspec/specs/ece-game-loop/spec.md`'s "CL bootstrap" requirement** — replace the "WHEN the bootstrap function is called from the CL REPL" scenario with one describing `ece game/main.scm` loading files and calling `(start)`. Keep the dice-rolling requirements untouched (they remain accurate).
- **Fix `openspec/specs/web-version-display/spec.md` scenario** — replace the "WHEN `sbcl --load web-export.lisp` is run" fallback scenario with one that invokes `scripts/build-web.sh` directly. `web-export.lisp` was deleted.
- **Reconcile `openspec/specs/player-record/spec.md` with `ece-character-creation/`** — the two specs overlap. Delete `player-record/` as the shadow; its `define-record` character and `*player*` global requirements move into `ece-character-creation/spec.md`. Its third requirement (`player-ref` lazy lookup closures) is dropped entirely, not moved, because `player-ref` was removed in archived change `2026-03-07-rooms-as-functions` when rooms became plain functions — `grep -r player-ref game/ tests/` returns no matches.
- **Fix `DESIGN.md` stale code examples** — the Data Structures section (lines ~880–1054) and the enemy-spec example on line ~92 use Common Lisp syntax (`defclass`, `defun`, `defmethod`, plist enemy-specs) and describe data shapes that don't exist in the code (`vignette`, split `str-current`/`str-max`, `game-state` with `dungeon-turn` / `roll-log` / `show-rolls`). Replace the code blocks with Scheme `define-record` forms matching `game/engine.scm`, `game/combat.scm`, and `game/bestiary.scm`. For `game-state` fields that are still-unimplemented Phase 3/7 goals (turn tracking, wandering monsters, roll log, visibility settings), either move them to a clearly-labelled "Future / aspirational design" subsection or drop them from the code block.

## Capabilities

### New Capabilities

None. This is a docs/specs cleanup with no new behavior.

### Modified Capabilities

- `ece-game-loop`: replace the "CL bootstrap" requirement with a pure-ECE CLI-runner requirement. Dice-rolling requirements unchanged.
- `web-version-display`: replace the "sbcl --load web-export.lisp" fallback scenario with one that invokes `scripts/build-web.sh`.
- `ece-character-creation`: absorb the still-accurate requirements from `player-record/spec.md` (the `define-record character` and `*player*` global + `init-player!`) so the deleted shadow spec's content lives in one canonical place. The `player-ref` requirement is NOT absorbed — it describes a function that was already deleted.

### Removed Capabilities

- `ece-integration`: entire capability removed — it documented the now-deleted qlot/ASDF wiring. Its responsibilities are subsumed by `ece-toolchain` and `ece-cli-runner`.
- `room-system`: entire capability removed — it documented pre-PR #31 `define-room`/`*rooms*`/`goto` machinery that no longer exists. Replaced long ago by `ece-room-system`.
- `player-record`: entire capability removed — shadow of `ece-character-creation`.

## Impact

- **Docs only**: `openspec/specs/` (deletions and edits) and `DESIGN.md` (rewritten code blocks). No changes to `game/*.scm`, `tests/`, `scripts/`, `Makefile`, or CI.
- **Readers / tooling**: Anyone who had bookmarked the deleted spec capability names will get a 404 — acceptable, since those specs described deleted behavior. The archive directory (`openspec/changes/archive/`) already contains the historical record of when those capabilities died.
- **No runtime impact**: No tests need to run differently, no build changes. `make test` and `make build` are not affected.
- **Risk**: Low — purely documentation. The only way to get this wrong is to drop a requirement from a spec that's still accurate. We mitigate by diffing each removed requirement against the code before deleting.
