## Context

The engine currently uses a registry pattern: `define-room` registers rooms in a `*rooms*` hash table, `goto` sets `*current-room*`, and `game-loop` trampolines by looking up and executing rooms. This was inherited from the CL engine where rooms were data structures needing a separate renderer. Now that rooms are already functions (from the rooms-as-functions change), the registry and trampoline are unnecessary indirection.

ECE has tail-call optimization, so a room function can call another room function in tail position without growing the stack.

## Goals / Non-Goals

**Goals:**
- Eliminate `*rooms*`, `*current-room*`, `goto`, `get-room`, `define-room`, `game-loop`, `start-game`
- Rooms are plain `define` functions that call each other directly
- Engine reduces to just UI helpers: `text`, `choose`, `ask`, choice system

**Non-Goals:**
- Changing the choice system, combat system, or item system
- Adding new game features
- Changing the browser I/O pattern (call/cc)

## Decisions

**Rooms as plain functions**: Rooms use `define` instead of `define-room`. The title is displayed as a `text` call at the top of the function body. This is the simplest possible approach — no macro needed.

*Alternative*: Keep a lightweight `define-room` macro that auto-displays the title. Rejected because it adds complexity for minimal benefit — a `text` call is clear and explicit.

**Direct function calls instead of goto**: `choose` macro actions call room functions directly (e.g., `(town-square)` instead of `(goto 'town-square)`). ECE's TCO keeps the stack flat as long as the call is in tail position, which it naturally is inside `choose` action lambdas.

**No game-loop trampoline**: The game is just functions calling functions. Entry point is `(start)` which calls the first room. The call chain continues via tail calls through `choose` actions.

**Tests check output text**: Integration tests that previously asserted `*current-room*` will instead check output text content, which is more meaningful anyway.

## Risks / Trade-offs

**[Risk] Non-tail-position room calls** → Room calls inside `choose` lambdas are in tail position by construction. The `choose` macro evaluates `((hash-ref chosen 'action))` which returns the result of the lambda, which calls the next room in tail position. Combat's `run-combat` returns an outcome symbol, so the room calling `run-combat` then calls the next room in tail position based on the outcome.

**[Trade-off] No room registry for introspection** → Cannot enumerate all rooms or look them up by name at runtime. This is acceptable — no current feature needs this. If needed later, a simple list could be added.
