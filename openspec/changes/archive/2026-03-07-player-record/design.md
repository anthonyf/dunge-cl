## Context

Character data lives in `*state*` as `(state-set! 'character 'field val)` / `(state-get 'character 'field)`. ECE now has `define-record` which generates constructors, predicates, accessors, mutators, functional updates, and copy. Records are hash tables with a `type` tag, so they interop with existing hash table primitives.

## Goals / Non-Goals

**Goals:**
- Define `character` record with all character sheet fields
- Replace `*state*` with `*player*` global holding a character record
- Update all content code to use named accessors/mutators
- Remove the state system from engine.scm

**Non-Goals:**
- Item records (separate future change)
- Changing room system or game loop
- Adding new character fields beyond what exists now

## Decisions

### Record definition

```scheme
(define-record character
  name background str dex wil hp hp-max armor gold fate inventory)
```

Fields match current `state-set!` keys. `inventory` holds a list of strings (same as now).

**Rationale:** Flat record with all fields. No nested records yet — items are still strings. Keep it simple.

### Player global and initialization

```scheme
(define *player* nil)
```

Initialize with `make-character` during character creation instead of incremental `state-set!` calls. Since character creation builds up fields across multiple rooms, use `set!` to replace `*player*` or mutate fields individually with `set-character-name!` etc.

### Replacing state-ref thunks

`(state-ref 'character 'name)` returns a thunk for lazy display in text elements. Replace with:

```scheme
(define (player-ref field)
  "Return a thunk that reads a player field by name."
  (lambda () (hash-ref *player* field)))
```

This preserves the lazy lookup pattern that `text` elements depend on, using the fact that records are hash tables underneath.

### Removing temporary flags

Current code uses `stats-rolled`, `hp-rolled`, `equipped` flags to guard one-time initialization. These won't be record fields. Instead, check if the relevant field has been set:
- `stats-rolled` → check `(character-str *player*)` is non-nil
- `hp-rolled` → check `(character-hp *player*)` is non-nil
- `equipped` → check `(character-inventory *player*)` is non-nil

This requires initializing `*player*` early (before room rendering starts) with nil fields.

### Early player initialization

Create `*player*` at game start with nil fields:

```scheme
(set! *player* (make-character nil nil nil nil nil nil nil nil nil nil '()))
```

Or add an `init-player!` helper that creates a blank character.

## Risks / Trade-offs

- **[Many-argument constructor]** `make-character` takes 11 positional args which is error-prone. Mitigation: only call it once in `init-player!` helper. Future: ECE could add keyword args to records.
- **[Nil field checks replacing flags]** Checking `(character-str *player*)` instead of a dedicated flag is slightly less explicit. Mitigation: these are only used in 3 places and the intent is clear.
