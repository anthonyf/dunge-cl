## Why

Background and bestiary entries use plain lists with manual `car`/`cddr` accessor chains. This is fragile and hard to read. `define-record` already exists and is used everywhere else — these two should use it too.

## What Changes

- Convert `*backgrounds*` entries from plain lists to `background` records with `define-record`
- Remove hand-written `bg-*` accessor functions (replaced by generated accessors)
- Convert `*bestiary*` entries from plain lists to `bestiary-entry` records with `define-record`
- Replace `car`/`cddr` destructuring in `make-enemy-from-bestiary` with record accessors

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `ece-character-creation`: Background data uses records instead of plain lists

## Impact

- `game/content.scm` — `define-record background`, convert `*backgrounds*` list, remove `bg-*` accessors, update `find-background` and `choose-background`/`equipment` to use generated accessors
- `game/bestiary.scm` — `define-record bestiary-entry`, convert `*bestiary*` list, simplify `make-enemy-from-bestiary`
