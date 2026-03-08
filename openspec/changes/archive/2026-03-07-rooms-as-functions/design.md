## Context

Rooms are currently hash-table data structures with a title and a body (list of tagged elements). A renderer dispatches on element type (`text`, `exit`, `gate`, `dynamic`, `prompt`, `combat-encounter`), collects choices, then the game loop presents them and handles input. This intermediary exists because the old CL engine needed static room data. ECE has no such constraint — rooms can be functions that execute directly.

The engine is ≈288 lines. Roughly half is the element system and renderer that this change eliminates.

## Goals / Non-Goals

**Goals:**
- Rooms are functions — entering a room calls the function
- Remove the element/renderer dispatch layer entirely
- Provide small helper functions/macros (`text`, `choose`, `ask`) for common patterns
- Keep `define-room` as a convenience macro (now defines a function instead of a data structure)
- All existing game behavior preserved (character creation, town navigation, combat)
- Integration tests continue to pass

**Non-Goals:**
- Changing the combat system internals (combat.scm stays mostly unchanged)
- Adding new game content or rooms
- Changing the call/cc browser I/O pattern
- Changing the player record system

## Decisions

### 1. Room = named function registered in `*rooms*`

`define-room` becomes:
```scheme
(define-macro (define-room name title . body)
  `(hash-set! *rooms* (quote ,name)
              (hash-table 'title ,title
                          'fn (lambda () ,@body))))
```

Entering a room displays the title and calls the function. The function body runs directly — displaying text, reading input, navigating to other rooms.

**Alternative**: Rooms as top-level `define` functions (no registry). Rejected because the registry enables `goto` by symbol name and keeps room lookup uniform.

### 2. `choose` function for menus

```scheme
(choose
  ("Look at the Adventure Board" (goto 'adventure-board))
  ("Go to the blacksmith" (goto 'blacksmith)))
```

`choose` is a macro that expands to: build choice list, display numbered menu, read input, execute the selected action. It calls `read-line` directly (which suspends via call/cc in browser mode).

**Alternative**: Return choices from the room function and let the game loop handle them. Rejected because it re-introduces the separation we're eliminating.

### 3. `ask` function for text prompts

```scheme
(ask "What is your name?"
     non-empty-string?
     (lambda (input)
       (set-character-name! *player* input)))
```

Replaces the `prompt` element type. Calls `read-line`, validates, retries on failure.

### 4. `text` stays as a convenience macro

```scheme
(define-macro (text . args)
  `(begin (display (fmt ,@args)) (newline)))
```

No thunks, no `callable?` check. Arguments are evaluated at call time (when the room function runs), not at definition time.

### 5. Game loop simplifies to a trampoline

```scheme
(define (game-loop)
  (when *current-room*
    (let ((room (get-room *current-room*)))
      (display (hash-ref room 'title))
      (newline) (newline)
      ((hash-ref room 'fn))
      (game-loop))))
```

Each room function is responsible for calling `goto` before it returns. The loop just keeps calling the current room's function.

### 6. Combat encounter becomes a function call

Instead of a `combat-encounter` element type with its own dispatch case in the renderer, combat becomes a function:

```scheme
(define-room test-combat "The Forest Path"
  (run-combat "Goblin"
    (lambda () (text "A goblin leaps from the shadows!"))
    (lambda (outcome) (goto (case outcome ...)))))
```

The combat loop lives inside `run-combat`, which handles rounds, choices, and outcomes. The room just calls it and reacts to the result.

## Risks / Trade-offs

- **Risk**: Integration tests depend on step counts through character creation. Room function bodies may change the number of `read-line` calls per step. → Mitigation: Run tests after each room conversion, adjust step sequences as needed.
- **Risk**: Combat encounter is deeply coupled to the current element dispatch. → Mitigation: Extract combat logic into a standalone function first, then convert the room.
- **Trade-off**: Rooms can now do anything (arbitrary side effects). The element system constrained what rooms could express. This is intentional — the constraint wasn't providing value, just complexity.
