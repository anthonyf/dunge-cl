# Adaptation Testbed Example

This directory holds the first Dunge crawler adaptation skeleton. It is a
loadable example, not a complete game yet.

The skeleton deliberately contains only:

- a safe camp;
- a dungeon threshold;
- one placeholder chamber in authored `.dunge` for the raw static path;
- a starter player record;
- a few authored tables that describe room, loot, encounter, and graph-link
  data.

The example also exposes CL helpers that can roll and install a generated
starting player before play, and helpers that roll the authored tables to create
and recall a persistent two-room generated dungeon graph. The first resolver
layer now applies basic loot, extracts generated exits, and lets CL replace an
authored graph-link template with concrete generated room ids. It also turns the
authored `:watchful-shadow` encounter result into persistent room-bound combat
state with attack and flee choices. Generated rooms now expose unclaimed
gold/item/supply results as loot choices, persist claimed result indexes, and
let the player eat rations for basic recovery during exploration or combat. The
browser runtime keeps character, inventory, condition, and room-bound encounter
state available for choices and save/load without displaying a permanent
character panel.

The console example is the first runnable crawler slice. The CL build
(`dunge-examples:build-adaptation`, run through `dunge.crawler:build-game`)
rolls a player and plans a two-room dungeon before play. The first chamber
takes the authored placeholder room's id, so the threshold's
`:enter-first-room` choice enters it; loading the raw `.dunge` source without
the build still reaches the static placeholder.

In compiled HTML the built rooms are ordinary rooms and support the same
crawler interactions: flee/attack an active encounter, take loot, eat a ration,
save/load, undo in debug mode, return to the threshold, or continue deeper.

## Browser Demo

The browser demo is a standalone build of the instanced adaptation slice. It
starts at camp, enters the authored threshold, and follows the generated-room
graph prepared by the CL helper. CI builds it as part of the Pages site (see
`site/check.sh`); the HTML is not committed.

Build it locally into this directory (git ignores the result) from the
repository root with:

```sh
sbcl --non-interactive --eval '(asdf:load-system :dunge/examples)' --eval '(dunge-examples:write-adaptation-browser-demo)'
```

Repeatable smoke path:

1. Open the built `examples/adaptation/index.html`, or serve the repo locally
   and visit `/examples/adaptation/`.
2. Choose **Approach the white arch**.
3. Choose **Enter the generated chamber**.
4. Choose **Flee** or **Attack** until the encounter is no longer active.
5. Choose **Take ration**.
6. Choose **Continue deeper**.
7. Choose **Flee** or **Attack** in the deeper generated room.
8. Reload the page and confirm the deeper generated room and encounter state
   persist without a permanent character/status panel.

See [PROVENANCE.md](PROVENANCE.md) for source/license notes and
[../../ADAPTATION_SUPPORT_AUDIT.md](../../ADAPTATION_SUPPORT_AUDIT.md) for the
engine support audit.
