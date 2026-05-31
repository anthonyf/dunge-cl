# Dunge Adaptation Research

This note captures the first pass at choosing an existing public-domain or
openly licensed dungeon-crawl target for Dunge. It is not legal advice; the
goal is to keep the project on conservative, easy-to-explain footing while we
use a real game-shaped adaptation to pressure-test the language and engine.

## Goals

- Adapt a complete-enough dungeon RPG loop instead of inventing every test case.
- Prefer public-domain or CC0 sources so Dunge examples can stay simple to use,
  remix, and redistribute.
- Keep authored `.dunge` files focused on "what": rooms, tables, encounters,
  items, NPCs, shops, and prose.
- Keep Common Lisp focused on "how": dice, character creation, generation,
  combat, inventory mutation, transactions, and persistence.
- Avoid copying protected text, tables, names, layout, art, or trade dress from
  closed commercial games.

## Candidate Matrix

| Candidate | License signal | Fit for Dunge | Risk | Recommendation |
| --- | --- | --- | --- | --- |
| [The Elf Game](https://osrelfgame.itch.io/eg) | Itch page says all text and images are public domain. | Good compact rules base: roll-under fantasy, light procedures, small enough to port. | Public-domain declaration is simple but less formally structured than CC0. | Use as the primary rules inspiration if we want the smallest mechanics target. |
| [The White Beast of Sel Vorynn](https://doomedzone.itch.io/the-white-beast-of-sel-vorynn) | Itch page says original writing, layout, and design are CC0/public domain; art has separate licenses. | Strong adventure/content target: modular dream dungeon, creatures, traversal, encounters. | Art needs separate handling; use text/data first and keep attribution notes. | Use as the primary dungeon content target. |
| [Open Adventure RPG](https://openadventurerpg.com/content-creation-licensing/) | Content Creation and Licensing page says listed community-owned content is CC0. | Complete fantasy system with clean licensing and a larger rules surface. | Only the listed community-owned content archive is CC0; third-party presentations are not automatically open. | Keep as a fallback/secondary rules source if The Elf Game is too thin. |
| [One Page Dungeon Contest](https://www.dungeoncontest.com/submission-rules) | Submission rules require CC BY-SA 4.0. | Huge pool of system-neutral dungeon content. | Attribution and share-alike obligations complicate bundling and derivative examples. | Useful later, but isolate license-bearing adapted content carefully. |
| [Cairn SRD](https://cairnrpg.com/first-edition/cairn-srd/) | SRD states Cairn is licensed under CC BY-SA 4.0. | Mechanically close to our current design notes: STR/DEX/WIL, HP, inventory pressure. | Share-alike matters if we adapt text/content directly. | Use as design comparison, not the first bundled adaptation target. |
| [D100 Dungeon](https://store.steampowered.com/app/2148300/D100_Dungeon__Lost_Tome_of_Extraordinary_Rules/) | Steam page for official DLC states D100 Dungeon is copyright Martin Knight, all rights reserved. | Very relevant solo procedural dungeon-crawl genre reference. | Not open; direct adaptation of tables, text, or distinctive structure is not appropriate without permission. | Inspiration only. Do not copy or port. |

## Recommended Target

Build a Dunge crawler testbed from **The Elf Game** plus **The White Beast of Sel
Vorynn**:

- Use The Elf Game as the compact rules reference for stats, tests, combat
  posture, and character scale.
- Use The White Beast as the dungeon/adventure reference for modular room
  segments, dream traversal, creatures, hazards, and a final objective.
- Rename and reshape our implementation as a Dunge-native demo rather than
  presenting it as an official port.
- Attribute sources even when not required, because this keeps provenance clear
  for future contributors.

Open Adventure is the backup if we decide we want a fuller CC0 rules engine
instead of a tiny public-domain one. One Page Dungeon and Cairn stay useful
comparisons, but their share-alike terms make them less attractive for the first
cleanly bundled repo example.

## Prototype Scope

Working title: **Dunge Crawler Testbed**.

The first playable vertical slice should include:

- Character creation from CL procedures: name, stats, HP, gold, inventory, and
  starting gear.
- A small `.dunge` authored hub and dungeon entrance.
- Random tables for room segments, sensory details, hazards, encounters, loot,
  and exits.
- Persistent generated room instances so a random room stays the same after the
  player leaves, returns, saves, and resumes. The current testbed can instantiate
  and recall a two-room generated dungeon graph from authored table results.
- A minimal combat loop with one player, one enemy profile, attacks, damage,
  defeat, escape, and save/load support.
- Inventory-linked choices such as claim generated loot and use a ration for
  recovery during exploration or combat.
- Save/load coverage for player, generated dungeon state, table state, current
  room, and encounter state.

## Engine Pressure Points

This adaptation should tell us whether Dunge needs:

- Dice utilities with roll records and transcript visibility.
- Larger graph policies on top of the CL generated room API.
- Richer encounter rules on top of the first room-bound encounter state.
- Item-use effects that can be invoked from rooms, combat, and shops.
- Character panel/browser UI for stats, slots, gold, conditions, and current
  encounter.
- Richer table result procedures for room details, objectives, item effects,
  and encounter starts.
- A clear content package layout for example games with license/provenance
  notes.

## License Hygiene

- Keep a source/provenance section in every adaptation doc or example package.
- Do not vendor original PDFs, images, or layouts unless we have verified their
  license and actually need them.
- Prefer paraphrased/adapted mechanics and Dunge-native data over copied prose.
- For CC0/public-domain sources, attribution is optional but recommended.
- For CC BY-SA sources, keep adapted content isolated and include the required
  attribution and license text/link.
- For closed/commercial references such as D100 Dungeon, record only broad genre
  observations and avoid copying names, table entries, layout, text, or unique
  expression.

## Proposed Implementation Slices

1. **Adaptation Skeleton**
   Create an example package directory, license/provenance notes, and a tiny
   authored entrance loop. This is represented by `examples/adaptation/` and
   the support audit in [ADAPTATION_SUPPORT_AUDIT.md](ADAPTATION_SUPPORT_AUDIT.md).

2. **Dice And Character Creation**
   Add dice utilities and CL character creation procedures, then generate a
   starting player that uses the existing player/inventory model. The
   adaptation example now exposes this through its generated-player loader.

3. **Generated Room Instances**
   Add a CL-side room instancing API and a small persistent dungeon graph.

4. **Encounter State And Combat**
   Add enemy profiles, encounter state, combat choices, damage, defeat, escape,
   and save/load support. The current testbed now has this first loop.

5. **Loot, Item Use, And Recovery**
   Resolve table results into inventory/gold mutations, implement basic item use,
   and wire recovery/Deprived behavior. The current testbed now surfaces
   generated room loot as claimable choices, persists claimed result indexes,
   and lets the player eat rations to recover HP/Fatigue and clear Deprived.

6. **Browser Character Panel**
   Show character, inventory, slots, fatigue, conditions, and encounter status
   in the browser runtime.
