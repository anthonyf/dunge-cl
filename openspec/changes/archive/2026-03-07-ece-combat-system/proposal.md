## Why

The CL engine has a full Cairn-inspired combat system with attack resolution, armor, HP/STR spillover, critical saves, healing, fleeing, and a state-machine encounter element. The ECE engine has items with damage dice and combat-readiness queries (`usable?`, `item-use-label`) but no combat. This is the core gameplay loop — without it, there's nothing to do in dungeons.

## What Changes

- Add `roll-d20` to dice.scm
- Add ability saves (`str-save`, `dex-save`, `wil-save`) to engine or a new combat.scm
- Define `enemy` and `encounter` records
- Implement attack resolution: roll damage die → subtract armor → apply to HP → spillover to STR → critical save
- Implement heal (restore HP to max), flee (DEX save, parting blow on fail)
- Implement combat choice generation from player inventory (weapons attack, consumables heal+take hit, unarmed fallback, flee)
- Implement encounter state machine (active → victory/death/incapacitated/fled)
- Implement combat log formatting
- Add `combat-encounter` element type to the engine's render dispatch
- Port bestiary data (~33 enemies across 4 tiers)
- Port the test-combat room from main.lisp to content.scm

## Capabilities

### New Capabilities
- `ece-combat`: Attack resolution, saves, healing, fleeing, encounter state machine, combat choices, combat-encounter room element
- `ece-bestiary`: Enemy data and lookup

### Modified Capabilities
- `ece-room-system`: Engine gains `combat-encounter` element type in render dispatch
- `ece-character-creation`: Player record needs no changes but combat reads/mutates `*player*` fields (hp, str, dex, wil, armor, inventory)

## Impact

- New file: `game/combat.scm` — combat mechanics, encounter state machine, combat choices
- New file: `game/bestiary.scm` — enemy data
- Modified: `game/dice.scm` — add `roll-d20`
- Modified: `game/engine.scm` — add `combat-encounter` to `render-element` dispatch
- Modified: `game/content.scm` — add test-combat room and wire it into town
- Modified: `game/main.scm` — load combat.scm and bestiary.scm
