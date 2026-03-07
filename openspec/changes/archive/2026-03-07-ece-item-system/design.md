## Context

The CL engine uses CLOS multiple inheritance for items: `item` base, `stackable`/`weapon`/`consumable` mixins, concrete classes like `weapon-item`, `stackable-item`, `healing-herb`. ECE has `define-record` but no inheritance or generic dispatch. We need to map CLOS patterns to ECE idioms.

## Goals / Non-Goals

**Goals:**
- Item records with named fields and type predicates
- Display name formatting per item type
- Combat-readiness queries (usable?, use-label)
- Stackable consumption with quantity tracking
- Background equipment produces real items
- Inventory display uses item display names

**Non-Goals:**
- Serialization (handled later with continuations)
- Inventory management UI (separate change)
- Full combat system (separate change — this just provides the item interface combat needs)

## Decisions

### Separate records per item type (no inheritance)

ECE records don't support inheritance. Instead of trying to simulate mixins, define separate records for each concrete type:

```scheme
(define-record item name)
(define-record weapon name damage-die)
(define-record stackable-item name quantity stack-limit)
(define-record healing-herb quantity stack-limit)
```

`healing-herb` has a fixed name ("Healing Herbs") so no `name` field needed.

**Rationale:** Simple, explicit, no framework needed. Each record gets its own predicate (`weapon?`, `stackable-item?`, `healing-herb?`) which replaces CLOS `typep` checks.

### Manual dispatch via cond

Replace generic functions with plain functions that dispatch on type predicates:

```scheme
(define (item-display-name item)
  (cond
    ((weapon? item)
     (fmt (weapon-name item) " (d" (weapon-damage-die item) ")"))
    ((healing-herb? item)
     (if (> (healing-herb-quantity item) 1)
         (fmt "Healing Herbs x" (healing-herb-quantity item))
         "Healing Herbs"))
    ((stackable-item? item)
     (if (> (stackable-item-quantity item) 1)
         (fmt (stackable-item-name item) " x" (stackable-item-quantity item))
         (stackable-item-name item)))
    ((item? item) (item-name item))
    (else "???")))
```

**Rationale:** ECE has no generic functions. `cond` dispatch is straightforward and the number of item types is small. Order matters — check specific types before base `item?` since all records are hash tables with a `type` field.

### Constructor helpers

```scheme
(define (make-weapon name damage-die) ...)
(define (make-healing-herb quantity) ...)
(define (make-stackable name quantity stack-limit) ...)
(define (make-simple-item name) ...)
```

These already come from `define-record` but we can add convenience wrappers (e.g., `make-healing-herb` with default stack-limit).

### Base equipment as items

Common items shared across all backgrounds:

```scheme
(define (base-equipment)
  (list (make-stackable-item "Rations" 3 10)
        (make-stackable-item "Torch" 2 5)
        (make-item "Waterskin")))
```

Background equipment lambdas produce real item lists instead of strings.

## Risks / Trade-offs

- **[No polymorphism]** Adding a new item type requires updating every dispatch function (`item-display-name`, `usable?`, `consume-item`, etc.). Acceptable at this scale — there are only 4 types.
- **[Record ordering in cond]** Must check `healing-herb?` before `stackable-item?` and `weapon?` before `item?` since all records are hash tables and predicates only check the `type` tag. Not fragile, just needs awareness.
