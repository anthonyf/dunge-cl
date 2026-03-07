## Context

Cairn combat rules: roll weapon die for damage, subtract target armor, apply remainder to HP. At 0 HP, further damage goes to STR. At 0 STR = death. Any STR damage triggers a critical save (d20 <= STR to survive). DEX save for initiative and fleeing. Healing herbs restore HP to max.

The CL implementation uses CLOS `combat-encounter` class with a `perform` method that acts as a state machine. ECE needs an equivalent using records and the existing element dispatch.

## Goals / Non-Goals

**Goals:**
- Full Cairn combat: attack, armor, HP→STR spillover, critical saves, death
- Heal via consumables, flee via DEX save
- Combat encounter as a room element with state machine (intro → active → outcome)
- Bestiary with ~33 enemies
- Combat choices built dynamically from player inventory
- Test encounter accessible from town

**Non-Goals:**
- Room-local storage (use a global `*current-encounter*` instead)
- Multiple simultaneous encounters
- Serialization of encounter state

## Decisions

### Enemy and encounter records

```scheme
(define-record enemy name hp hp-max armor str dex wil attack-die)
(define-record encounter enemy first-round log state)
```

`encounter-state` is a symbol: `'active`, `'victory`, `'death`, `'incapacitated`, `'fled`.

### Global encounter instead of room-local

CL uses `room-local` for per-room state. ECE doesn't have this concept. Use a simple global:

```scheme
(define *current-encounter* nil)
```

This is fine since there's only ever one encounter at a time. Reset it on encounter end.

**Rationale:** Adding room-local storage to the ECE engine is unnecessary complexity for a single use case.

### Combat encounter as a new element type

Add a `combat-encounter` tagged list to the engine's `render-element` dispatch:

```scheme
(define-macro (combat-encounter . args)
  `(list 'combat-encounter (hash-table ,@args)))
```

Used in room definitions like:
```scheme
(combat-encounter
  'enemy (list "Goblin" 4 0 6 'str 8 'dex 12 'wil 8)
  'intro (text "A goblin leaps from the shadows!")
  'victory (exit "Continue" town-square)
  'death (text "You died."))
```

The `render-element` handler for `'combat-encounter` runs the state machine: setup on first visit, show combat choices when active, show outcome when terminal.

### Attack resolution returns a hash table

```scheme
(define (resolve-attack attacker-die target)
  ;; Returns: (hash-table 'damage N 'str-damage N 'critical-save t/nil/'none 'dead t/nil)
```

Using hash tables instead of plists since ECE doesn't have keyword args or `getf`.

### Combat log as strings

Each round produces a log string. The encounter record stores the latest log. On the next render, the log is displayed and cleared. Same pattern as CL.

### Saves in combat.scm

```scheme
(define (roll-d20) (roll-die 20))
(define (str-save combatant) (<= (roll-d20) (character-str combatant)))
```

Saves work on any record with str/dex/wil fields. Since both `character` and `enemy` have these fields, and records are hash tables, we can use `(hash-ref target 'str)` for a generic accessor.

### Bestiary as simple list data

```scheme
(define *bestiary*
  (list
    (list "Goblin" 4 0 6 8 12 8)
    ...))
(define (make-enemy-from-bestiary name) ...)
```

Each entry: (name hp armor attack-die str dex wil). Lookup by name, construct enemy record.

## Risks / Trade-offs

- **[Generic field access for saves]** Saves need to read str/dex/wil from both character and enemy records. Since both are hash tables with matching field names, `(hash-ref target 'str)` works for both. This relies on field name consistency rather than a shared base type.
- **[Global encounter state]** A global `*current-encounter*` means you can't have nested or parallel encounters. Acceptable for this game — it's always one fight at a time.
- **[Large change]** This touches 6 files and adds 2 new ones. But it's a cohesive feature — breaking it smaller would create half-working combat.
