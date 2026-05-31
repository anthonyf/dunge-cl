# Adaptation Support Audit

This audit maps the first Dunge crawler testbed loop to the engine we have
today. It exists to keep the next implementation slices honest: add language
forms only when the loop proves that authored `.dunge` needs to describe
something new. Otherwise, keep the behavior in Common Lisp.

## Minimum Playable Loop

The first adaptation target is intentionally small:

1. Create a player.
2. Start at a safe camp or threshold scene.
3. Enter the dungeon.
4. Generate or recall the next room.
5. Inspect the room and choose one interaction.
6. Resolve any encounter, hazard, loot, or exit.
7. Mutate player/world state.
8. Save enough state that the room, player, rolls, and encounter can resume.
9. Repeat until the player escapes, dies, or reaches the objective.

## Support Matrix

| Loop step | Current Dunge support | Missing support | Likely next slice |
| --- | --- | --- | --- |
| Player creation | `:player` source form, player save/load, inventory data model, adaptation player creation helper, and browser character panel. | A player-facing character creation flow. | Generated dungeon entrance flow. |
| Safe camp / entrance | Authored rooms, choices, actions, branches, flags, global state. | Nothing major for a static entrance loop. | Adaptation skeleton. |
| Enter dungeon | `:go`, `:gosub`, `:back`, authored room ids, registered generated room ids, resolved exit data, generated room graph links, and active encounter/item-use choices. | Player-facing dungeon entrance flow that invokes the CL graph helpers directly. | Generated dungeon entrance flow. |
| Generate room | Random tables, deterministic seed, table state, roll log, generated room API, generated room save/load, claimed loot indexes, a two-room adaptation graph, and room-bound encounters. | Richer room detail procedures and larger graph policies. | Generated dungeon entrance flow. |
| Inspect room | Paragraphs, entities, conditional choices, local/ref/global state, generated room rendering, resolved room result facts, claimable loot, generated exits, combat options, and browser status. | Rich generated room interactions beyond description, facts, loot, exits, and the minimal combat loop. | Generated dungeon entrance flow. |
| Encounters | Table result conventions can name encounters; CL can create persistent encounter state, render active choices, attack, damage, ration use, defeat, flee, and browser encounter status. | Richer enemy profiles, morale, initiative/turn policy, and encounter rewards. | Generated dungeon entrance flow. |
| Loot and supplies | Table result conventions, player inventory helpers, gold field, resolver support for gold/item/supply mutations, player-facing generated-room loot claims, and browser inventory display. | Richer item descriptions, treasure tags, and reward policies. | Generated dungeon entrance flow. |
| Item use | Inventory entries can store count, slots, condition, tags; generated rooms and combat can expose item-use choices; rations can be consumed. | Broader item-use catalog for light, tools, herbs, spellbooks, scrolls, and relics. | Generated dungeon entrance flow. |
| Recovery | Player HP/max HP, fatigue, conditions, Deprived predicate, recovery helper, ration procedure, and browser display. | Full rest procedures and broader condition rules. | Generated dungeon entrance flow. |
| Save/load | Current room, return stack, globals, locals, table state, roll log, player state, generated room instances, claimed loot, and encounter state. | Browser runtime parity for generated rooms and CL procedures. | Generated dungeon entrance flow. |
| Browser presentation | Browser runtime renders character, inventory, slot pressure, fatigue, conditions, and room-bound encounter status. | Browser runtime parity for generated dungeon procedures. | Generated dungeon entrance flow. |

## Boundary Decisions

- `.dunge` should describe static scenes, tables, result shapes, labels, and
  declarative conditions.
- CL should roll dice, instantiate generated rooms, resolve table result data,
  run combat, mutate player inventory, and manage saveable procedure state.
- The skeleton example may include placeholder authored rooms for generated
  spaces, but the real generated dungeon should not require authors to prewrite
  every possible room id.
- New language forms should wait until an authored example cannot describe the
  needed content cleanly with rooms, entities, choices, tables, and state.

## Support Status

1. **Dice utilities**
   The engine has a shared parser/roller for `XdY` style strings and explicit
   roll records. Character creation uses it now; loot quantities, damage, and
   oracle procedures should reuse it.

2. **Generated room instances**
   The engine has a CL-side API that creates room-like playable locations,
   assigns stable ids, registers them for navigation/save/load, and renders
   generated descriptions, exits, and resolved table results. Graph helpers can
   add, replace, and reciprocally link generated room exits. The adaptation uses
   this to create and recall a small two-room generated dungeon graph.

3. **Table result resolvers**
   The engine has a first shared resolver layer for result data: normalize
   dice-based gold/counts, apply gold/items/supplies to a player, validate
   encounter count data, extract encounter markers, and extract generated-room
   exits. Richer procedures still decide what room details, hazards,
   objectives, and item effects do in context.

4. **Encounter state**
   The engine has persistent room-bound encounter state: enemy id, current
   HP/STR, reaction, damage, round, source result, and outcome. Generated rooms
   can render active attack/flee choices and save/load or undo combat state.

5. **Loot, item use, and recovery**
   Generated rooms now expose unclaimed loot as choices and persist claimed
   result indexes. Rooms and combat can ask whether a ration-use action is
   available without turning every item into bespoke authored room logic.

6. **Browser character and encounter panel**
   The browser backend now renders a compact status panel from serialized player
   and encounter state: HP, attributes, armor, gold, fate, fatigue, conditions,
   inventory, slots, and the encounter bound to the current authored room.

7. **Generated dungeon entrance flow**
   The console adaptation example now installs the generated player and the
   persistent two-room dungeon graph before play, then rewires the authored
   threshold's `:enter-first-room` choice to the first generated room id. This
   gives the testbed a runnable camp-to-threshold-to-generated-room loop without
   moving room instancing into `.dunge`.

## Next Recommended PR

Build the **browser generated-room parity** slice next. The console adaptation
can now generate rooms, link them, enter the first generated room from the
authored threshold, run a small persistent combat loop, claim loot, use rations,
and display character state in the browser panel. The next pressure point is
serializing and rendering generated rooms in the browser backend so this same
vertical slice can be clicked as a standalone HTML demo.
