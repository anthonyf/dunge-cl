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
| Player creation | `:player` source form, player save/load, inventory data model, adaptation player creation helper. | A player-facing character creation flow. | Browser character panel. |
| Safe camp / entrance | Authored rooms, choices, actions, branches, flags, global state. | Nothing major for a static entrance loop. | Adaptation skeleton. |
| Enter dungeon | `:go`, `:gosub`, `:back`, authored room ids, registered generated room ids, resolved exit data, generated room graph links, and active encounter choices. | Player-facing dungeon entrance flow that invokes the CL graph helpers directly. | Loot, item use, and recovery. |
| Generate room | Random tables, deterministic seed, table state, roll log, generated room API, generated room save/load, first table result resolvers, a two-room adaptation graph, and room-bound encounters. | Richer room detail procedures and larger graph policies. | Loot, item use, and recovery. |
| Inspect room | Paragraphs, entities, conditional choices, local/ref/global state, generated room rendering, resolved room result facts, generated exits, and combat options. | Rich generated room interactions beyond description, facts, exits, and the minimal combat loop. | Loot, item use, and recovery. |
| Encounters | Table result conventions can name encounters; CL can create persistent encounter state, render active choices, attack, damage, defeat, and flee. | Richer enemy profiles, morale, initiative/turn policy, encounter rewards, and item integration. | Loot, item use, and recovery. |
| Loot and supplies | Table result conventions, player inventory helpers, gold field, and resolver support for gold/item/supply mutations. | Player-facing loot choices, item use, and recovery procedures. | Loot, item use, and recovery. |
| Item use | Inventory entries can store count, slots, condition, tags. | Item-use procedures and effect hooks callable from rooms and combat. | Loot, item use, and recovery. |
| Recovery | Player HP/max HP, fatigue, conditions, Deprived predicate. | Rest/recovery procedure and rules for clearing fatigue/conditions. | Loot, item use, and recovery. |
| Save/load | Current room, return stack, globals, locals, table state, roll log, player state, generated room instances, and encounter state. | Browser/runtime parity for encounter display. | Browser character panel. |
| Browser presentation | Browser runtime already serializes player data. | Character/inventory/encounter panels and UI affordances for slots and conditions. | Browser character panel. |

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

5. **Item-use procedures**
   Rooms and combat both need to ask "what can this item do here?" without
   turning every item into bespoke authored room logic.

## Next Recommended PR

Build the **loot, item use, and recovery** slice next. The adaptation can now
generate rooms, link them, and run a small persistent combat loop; the next
pressure point is making inventory matter during exploration and combat through
item-use procedures, recovery, and player-facing loot choices.
