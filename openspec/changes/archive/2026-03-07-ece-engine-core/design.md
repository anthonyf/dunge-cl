## Context

Dunge currently uses a CL engine built on CLOS generic functions (`perform`, `menu`, `out`, `execute-action`) with a declarative room DSL (`make-room`, `exit`, `gate`, `prompt`, `p`). Game state lives in a global nested hash table (`*data-store*`). The engine supports two I/O contexts via method dispatch: `print-context` (terminal) and `browser-context` (web/JSCL).

ECE is the project author's Scheme-like language with an explicit control evaluator, first-class continuations, macros, and hash tables. It is already added as a qlot dependency. This change builds a new IF engine entirely in ECE and ports the existing game content, targeting terminal I/O only.

## Goals / Non-Goals

**Goals:**
- Build a dunge-specific IF engine in ECE with rooms, choices, gates, prompts, and a game loop
- Port all existing game content (character creation, town) to ECE
- Game state via ECE hash tables
- Include dice rolling for character creation
- Playable in terminal via `(ece:evaluate ...)`
- Coexist with old CL engine (both runnable)

**Non-Goals:**
- Browser/JSCL target (Change 3)
- Item system with stackable mixin (Change 2)
- Text layout / column formatting (Change 2)
- Removing old CL engine files (Change 4)
- Save/load game via continuations (Change 4, though the architecture supports it)
- Pluggable I/O abstraction (Change 3 — for now, use ECE's built-in `display`/`read-line`)

## Decisions

### 1. File structure: `game/` directory with ECE scripts

Game scripts live in `game/`:
- `game/engine.scm` — IF engine (room, choose, gate, prompt macros + game loop)
- `game/dice.scm` — Dice rolling utilities
- `game/content.scm` — All game content (character creation, town rooms)
- `game/main.scm` — Bootstrap: loads engine + content, starts game

Rationale: Keeps ECE scripts separate from CL source. The `game/` name is simple and content-focused. Single content file for now since the game is small; can split later.

### 2. Room system: macros that register rooms in a global hash table

Rooms are defined with a `define-room` macro that stores a room record (hash table) in a global `*rooms*` hash table keyed by symbol name. Each room has a title, a body (list of elements to render), and produces choices for the player.

Elements within a room body:
- `(text ...)` — display text
- `(exit label target-room)` — navigation choice
- `(gate condition then-elements else-elements)` — conditional content
- `(prompt question validate-fn action-fn)` — text input

Rationale: Mirrors the current CL room DSL semantics but uses ECE macros and hash tables. The `define-room` macro captures body as a list of thunks/data that the engine walks at render time.

### 3. Game state: single global hash table with nested access

A global `*state*` hash table stores all game state. Helper functions `state-get` and `state-set!` provide nested key access (e.g., `(state-get 'character 'name)`).

Rationale: Direct equivalent of CL's `*data-store*` with `lookup`/`(setf lookup)`. ECE's hash tables support `hash-ref`, `hash-set!`, `hash-has-key?`.

### 4. Choice system: list of choice records with optional guards

Choices are hash tables with `:label`, `:action`, and optional `:guard` keys. The engine filters by guard, displays numbered menu, reads input, dispatches action.

Rationale: More flexible than if-lib's `choose` macro. Guards enable conditional choices (equivalent to CL's `gate` within choice lists). Actions are zero-argument thunks that typically call `(goto 'room-name)`.

### 5. Game loop: tail-recursive with `goto` setting current room

The game loop renders the current room, collects choices, presents menu, reads selection, executes action, repeats. `(goto 'room-name)` sets the next room. The loop is tail-recursive (ECE has TCO).

Rationale: Simple and natural in ECE. No vignette stack needed for Change 1 (that's a CL engine concept for push/pop scenes). Direct room-to-room navigation via `goto`.

### 6. CL bootstrap: single function that evaluates game scripts

A new CL function (e.g., `dunge-ece:start`) calls `(ece:evaluate '(load "game/main.scm"))`. The ECE `load` function handles file loading relative to CWD.

Rationale: Minimal CL surface. The old engine entry point `(dunge:game-repl (dunge:room 'start))` remains unchanged.

### 7. Dice rolling: simple ECE functions using `random`

`(roll-die sides)` returns 1-sides. `(roll-dice n sides)` returns a list of n rolls. ECE has `(random n)` built in.

Rationale: Trivial to implement. No CL dependency needed.

## Risks / Trade-offs

- **ECE `load` path resolution**: ECE's `load` reads files relative to CL's `*default-pathname-defaults*`. The bootstrap must ensure this is set to the project root. → Mitigation: Set `*default-pathname-defaults*` before calling `ece:evaluate`.

- **Debugging ECE code**: Errors in ECE scripts surface as CL conditions from the evaluator. Stack traces won't show ECE call frames. → Mitigation: ECE has `try-eval` for error handling. Keep scripts small and test incrementally.

- **Feature gap with CL engine**: The ECE version won't have items with stackable display (Change 2). Character creation equipment will use simple string lists instead. → Mitigation: Acceptable for Change 1. Equipment display is cosmetic.

- **Duplicate game content**: During coexistence, game content exists in both `src/main.lisp` (CL) and `game/content.scm` (ECE). → Mitigation: Temporary. Old content removed in Change 4.
