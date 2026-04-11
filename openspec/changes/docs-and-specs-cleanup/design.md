## Context

Two large migrations have landed recently:

- **PR #33 (2026-04-10) — Drop Common Lisp, run game and tests on pure ECE.** Deleted `dunge.asd`, `qlfile`, `qlfile.lock`, `src/ece-bootstrap.lisp`, `run-tests.lisp`, and `web-export.lisp`.
- **PR #40 (2026-04-11) — Vendor ECE as a git submodule at `vendor/ece/`.** Moved build-time ECE from an upstream clone to `vendor/ece/`.

Both migrations shipped their own OpenSpec deltas (`2026-04-10-drop-cl-pure-ece` and `2026-04-11-vendor-ece-toolchain` in the archive), which correctly updated specs like `ece-toolchain`, `ece-web-build`, `ece-cli-runner`, and `ece-test-runner`. However, several **older** specs that overlapped with the deleted capabilities were not touched:

| Live spec | Describes | Status |
|---|---|---|
| `ece-integration/spec.md` | `qlfile`, `(asdf:load-system :dunge)`, `dunge.asd :depends-on "ece"` | Entirely stale — the files it names were deleted in PR #33 |
| `room-system/spec.md` | `define-room` macro, `*rooms*` registry, `goto` | Entirely stale — superseded by `ece-room-system` in PR #31 (2026-03-08 `remove-room-machinery`) |
| `player-record/spec.md` | `character` record, `*player*`, `player-ref` | Partial shadow — record and `*player*` overlap `ece-character-creation`; `player-ref` was deleted in `2026-03-07-rooms-as-functions` and does not exist anywhere in `game/` or `tests/` |
| `ece-game-loop/spec.md` | "CL bootstrap starts the ECE game" (first requirement only) | Top requirement is stale; the dice-rolling requirements below it are still accurate |
| `web-version-display/spec.md` | `sbcl --load web-export.lisp` local-fallback scenario | One scenario is stale; the surrounding requirement is still correct |

In parallel, `DESIGN.md` contains a large Data Structures section (lines ~880–1054) written in Common Lisp pseudo-code (`defclass vignette`, `defclass character`, `defclass game-state`, `defun take-damage`, `defmethod advance-turn`). The code shown doesn't match `game/*.scm` — there is no vignette data model (rooms are plain Scheme procedures), the `character` record has different fields (single STR/DEX/WIL, not split current/max), and the `game-state` object with `dungeon-turn`, `roll-log`, and `show-rolls` is still-unimplemented Phase 3/7 aspirational work from `TODOs.org`. Line ~92 also has a `lisp` enemy-spec plist example that doesn't match the current `define-record` enemies in `game/bestiary.scm`.

## Goals / Non-Goals

**Goals:**

- Every live spec under `openspec/specs/` reflects the pure-ECE, submodule-based, rooms-as-functions reality.
- No live spec names a file or symbol that doesn't exist in the codebase (`qlfile`, `dunge.asd`, `web-export.lisp`, `define-room`, `*rooms*`, `goto`, etc.).
- `DESIGN.md` code examples compile (or could compile) as ECE Scheme, or are clearly marked as "aspirational target" prose rather than pseudo-code that looks like real Scheme.
- The player-record capability has exactly one canonical home.

**Non-Goals:**

- No changes to `game/*.scm`, `tests/`, `scripts/`, `Makefile`, `.github/workflows/`, or CI config.
- No new gameplay features, no new specs for still-unimplemented phases (turn tracking, roll log, etc.).
- No rewrite of `DESIGN.md`'s rules/lore content. Only the code-example blocks and any section headers that become misleading.
- No reshuffling of `openspec/specs/` beyond what's needed to remove the stale capabilities. We're not renaming `ece-room-system` → `room-system` or similar — the `ece-` prefix stays.
- Not adding a "deprecated spec" convention. Stale specs get deleted, not kept as tombstones.

## Decisions

### Decision 1: Delete stale capabilities outright rather than deprecate them

**Chosen:** `ece-integration`, `room-system`, and `player-record` are removed as capabilities — their spec directories are deleted and a delta file in this change marks every requirement as REMOVED so the archive captures the history.

**Alternative considered:** Leave the spec files in place with a "DEPRECATED — see X" banner. Rejected because:

- OpenSpec doesn't have a first-class deprecation concept — a banner is unenforceable prose.
- The deleted capabilities describe code that literally doesn't exist. Readers who grep for `qlfile` or `define-room` and find these specs will be more confused, not less.
- The archive under `openspec/changes/archive/` already contains the historical deltas (e.g., `2026-03-08-remove-room-machinery`) that describe when and why the capability died. That's the correct place to look for history.

**Consequence:** Anyone with a bookmark to `openspec/specs/ece-integration/spec.md` hits a 404. Acceptable — the content was wrong.

### Decision 2: Fold the still-accurate `player-record` requirements into `ece-character-creation`, drop `player-ref`

**Chosen:** Delete `player-record/` entirely. Move its first two requirements (`character` record shape, `*player*` global + `init-player!`) into `ece-character-creation/spec.md` as ADDED requirements. Drop the third requirement (`player-ref` lazy lookup closures) entirely — `player-ref` was removed in the archived change `2026-03-07-rooms-as-functions` when rooms stopped being data and became plain functions, and `grep -r player-ref game/ tests/` returns no matches. Rooms now call `(character-name *player*)` and similar accessors directly at display time; there is no lazy-thunk pattern to document.

**Alternatives considered:**

1. *Rename `player-record` → `ece-player` and leave `ece-character-creation` alone.* Rejected because we'd end up with two closely-related capabilities, and the field lists in the two current specs are already contradictory (`player-record/spec.md` names fields `name background str dex wil hp hp-max armor gold fate inventory`; `ece-character-creation/spec.md` references different record-accessor conventions via `background-*`). Keeping two capabilities would let them drift further.
2. *Fold `player-ref` in anyway with a "deprecated" note.* Rejected because the function does not exist — documenting nonexistent behavior is the exact failure mode this whole change is trying to fix.
3. *Re-add `player-ref` to `game/engine.scm` as a thin wrapper so the spec stays accurate.* Out of scope — this change is docs-only, and the "rooms are plain functions" model deliberately removed the lazy-thunk pattern as unnecessary.

**Consequence:** `ece-character-creation` grows from covering backgrounds + equipment display to also covering the underlying `character` record and the `*player*` global. The name is still reasonable — character creation is where those entities come from. `player-ref`'s removal is captured in the REMOVED delta of `player-record/spec.md` (with a pointer to the archived change that deleted it), so archive history reflects why it was dropped rather than moved.

### Decision 3: Surgical edit of `ece-game-loop` and `web-version-display`, not wholesale rewrite

**Chosen:** Issue MODIFIED deltas that touch exactly the stale requirement / scenario and nothing else. The dice-rolling requirements in `ece-game-loop` and the build-time-injection requirement in `web-version-display` are factually correct and stay put.

**Alternative considered:** Rewrite the whole spec file. Rejected because it produces noisy diffs that obscure the actual correction and increases the risk of losing an accurate requirement in the shuffle.

### Decision 4: DESIGN.md — port code blocks to Scheme, not delete

**Chosen:** Rewrite the Common Lisp pseudo-code in `DESIGN.md` §Data Structures and §Bestiary enemy-spec (line ~92) as ECE Scheme using `define-record`, matching actual fields from `game/engine.scm`, `game/combat.scm`, and `game/bestiary.scm`. For fields that describe still-unimplemented aspirations (`game-state.dungeon-turn`, `roll-log`, `show-rolls`, `global-flags`), move them under a clearly-labelled "Future / Aspirational" subsection.

**Alternatives considered:**

1. *Delete the code blocks entirely and keep only the English design prose.* Rejected because the code shapes are genuinely useful — readers want to see the record structure, not just a paragraph about it.
2. *Add a disclaimer banner ("Code in this section is pseudocode; see `game/*.scm` for actual implementation") and leave the CL as-is.* Rejected because CL pseudo-code in a Scheme project invites confusion, especially for examples that look like they could paste into a REPL. Port is cheaper than an ongoing "don't worry, it's pseudocode" footnote.

**Consequence:** DESIGN.md becomes slightly longer in the aspirational subsection (we want to preserve the design thinking for Phase 3/7) but the "current" code blocks accurately reflect `game/*.scm`.

### Decision 5: Verify before delete

Before deleting or modifying any requirement, we diff it against the current code to confirm the behavior it describes is genuinely absent:

| Spec/requirement | Verification command |
|---|---|
| `ece-integration` qlfile/asdf | `ls qlfile qlfile.lock dunge.asd 2>&1` should return "not found" |
| `room-system` `define-room` | `grep -r 'define-room\|^\*rooms\*\|(goto ' game/ tests/` should return no matches |
| `player-record` field names | Read `game/engine.scm` `define-record character` and confirm field list matches the spec's field list before absorbing it into `ece-character-creation` |
| `player-record` `player-ref` | `grep -r player-ref game/ tests/` should return no matches (the function was deleted in `2026-03-07-rooms-as-functions`); do NOT fold this requirement into `ece-character-creation` |
| `ece-game-loop` CL bootstrap | `ls src/ece-bootstrap.lisp 2>&1` should return "not found" |
| `web-version-display` sbcl fallback | `ls web-export.lisp 2>&1` should return "not found"; confirm `scripts/build-web.sh` is the current entry point |
| `DESIGN.md` code blocks | Read `game/engine.scm`, `game/combat.scm`, `game/bestiary.scm` and list actual record fields before writing new code blocks |

This is a one-shot verification, done during the task execution, not an ongoing check.

## Risks / Trade-offs

- **Risk:** Accidentally delete a requirement that's still load-bearing somewhere. → **Mitigation:** Decision 5 — verify each removed requirement against the code before marking it REMOVED. Verification caught the inverse case for `player-ref`: the original draft assumed it was still load-bearing and proposed folding it into `ece-character-creation`, but the function does not exist in the code — so it is dropped entirely, not moved.
- **Risk:** `DESIGN.md` code-block rewrite drifts further from the code during future edits. → **Mitigation:** Port the blocks to match today's code exactly; no speculation. If future engine changes break them again, that's a future docs-cleanup PR, not an argument against doing this one.
- **Risk:** Readers hitting archived 404s for removed specs. → **Mitigation:** The REMOVED deltas in this change's archive record exactly when and why each capability was dropped, so `git log`/`openspec archive` history remains intact.
- **Risk:** We end up with `ece-character-creation` covering too much (backgrounds, equipment display, character record, `*player*`). → **Mitigation:** Acceptable — the name still fits, and the current split is demonstrably worse (contradictory field lists).
- **Trade-off:** Porting DESIGN.md CL → Scheme takes more effort than slapping on a disclaimer. We accept the cost because the blocks are the most visible part of the doc and get read by humans looking to understand the engine.

## Migration Plan

1. **Verify** each stale reference against the code (Decision 5 table) before touching anything.
2. **Delete** `openspec/specs/ece-integration/`, `openspec/specs/room-system/`, `openspec/specs/player-record/` directories as part of the same commit that lands the REMOVED deltas in this change's `specs/` folder. (OpenSpec archive normally handles the deletion on archive-change, but we call it out here so the implementer doesn't leave the directories dangling.)
3. **Edit** `openspec/specs/ece-game-loop/spec.md` and `openspec/specs/web-version-display/spec.md` per the MODIFIED deltas.
4. **Edit** `openspec/specs/ece-character-creation/spec.md` to add the absorbed requirements.
5. **Rewrite** the affected `DESIGN.md` code blocks.
6. **Validate:** run `openspec validate docs-and-specs-cleanup --strict` and `make test` (should be a no-op for tests but a good sanity check).
7. **Archive** this change after merge via `/opsx:archive`.

No rollback is needed for docs — if something is wrong, a follow-up PR fixes it.

## Open Questions

- **Q: Should `DESIGN.md` §Data Structures be split into "implemented" vs. "aspirational" subsections, or stay as one section with inline markers?** → Leaning toward split subsections because the reader-utility argument is stronger, but the implementer can make the final call when they see how the sections flow after rewriting.
