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
| Enter dungeon | `:go`, `:gosub`, `:back`, and authored room ids. | A CL entry point that creates or retrieves generated dungeon rooms. | Generated room instances. |
| Generate room | Random tables, deterministic seed, table state, roll log. | Room instance API, generated graph state, table-result resolver to concrete room data. | Generated room instances. |
| Inspect room | Paragraphs, entities, conditional choices, local/ref/global state. | Generated room rendering model and a stable way to attach generated content to room views. | Generated room instances. |
| Encounters | Table result conventions can name encounters. | Encounter model/state, enemy profiles, initiative/turn procedure, damage, morale, escape. | Encounter state and combat. |
| Loot and supplies | Table result conventions, player inventory helpers, gold field. | Resolver that turns `(:gold ...)`, `(:item ...)`, and `(:supply ...)` into player mutations. | Loot, item use, and recovery. |
| Item use | Inventory entries can store count, slots, condition, tags. | Item-use procedures and effect hooks callable from rooms and combat. | Loot, item use, and recovery. |
| Recovery | Player HP/max HP, fatigue, conditions, Deprived predicate. | Rest/recovery procedure and rules for clearing fatigue/conditions. | Loot, item use, and recovery. |
| Save/load | Current room, return stack, globals, locals, table state, roll log, player state. | Generated dungeon graph state and encounter state. | Generated room instances; encounter state and combat. |
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
   We need a CL-side API that can create a room-like playable location, assign
   it a stable id, register it for navigation/save/load, and render generated
   details from resolved table results.

3. **Table result resolvers**
   Tables already return data. The adaptation needs resolver functions that
   decide what data means in a specific procedure: add loot, start encounter,
   attach room detail, create exit, or mark an objective.

4. **Encounter state**
   Combat needs persistent state separate from static room state: enemy id,
   current HP/STR, disposition, round, escape state, and outcome.

5. **Item-use procedures**
   Rooms and combat both need to ask "what can this item do here?" without
   turning every item into bespoke authored room logic.

## Next Recommended PR

Build the **generated room instances** slice next. The adaptation now has a real
player to carry through the skeleton; the next pressure point is replacing the
placeholder chamber with a persistent generated room.
