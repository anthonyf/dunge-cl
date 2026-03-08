## Context

Two data structures use plain lists with manual accessors while every other structured type in the codebase uses `define-record`. This is inconsistent and the `car`/`cddr` chains are brittle.

## Goals / Non-Goals

**Goals:**
- Background entries use `define-record background`
- Bestiary entries use `define-record bestiary-entry`
- All manual accessor functions (`bg-name`, etc.) removed
- All `car`/`cddr` destructuring replaced with record accessors

**Non-Goals:**
- Converting hash-table-as-struct patterns (choice, attack result, etc.) — those are fine as-is
- Changing the enemy record itself — it already uses `define-record`

## Decisions

**Background record fields**: `name description equipment-thunk armor gold` — matches the existing list structure exactly. Generated accessors: `background-name`, `background-description`, `background-equipment-thunk`, `background-armor`, `background-gold`.

**Bestiary entry record fields**: `name hp armor attack-die str dex wil` — matches the existing list column order. Generated accessors: `bestiary-entry-name`, `bestiary-entry-hp`, etc.

**Constructor usage**: `*backgrounds*` and `*bestiary*` will use `make-background` and `make-bestiary-entry` instead of `list`.

## Risks / Trade-offs

None — purely structural cleanup with no behavioral change.
