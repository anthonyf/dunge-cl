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
browser runtime now renders character, inventory, slot pressure, condition, and
room-bound encounter state.

The console example is now the first runnable crawler slice: the CL loader
installs a generated player, creates the persistent two-room dungeon graph, and
rewires the authored threshold's `:enter-first-room` choice to the first
generated room. The placeholder chamber remains only for the raw static source
path.

The browser backend can now serialize and render those pre-instanced generated
rooms too. In compiled HTML, generated rooms share normal navigation with
authored rooms and support the same first crawler interactions: flee/attack an
active encounter, claim generated loot, eat a ration, save/load, undo in debug
mode, return to the threshold, or continue deeper through concrete generated
exits.

## Browser Demo

The committed [index.html](index.html) file is a standalone browser build of
the instanced adaptation slice. It starts at camp, enters the authored
threshold, and follows the generated-room graph prepared by the CL helper.

Regenerate it from the repository root with:

```sh
qlot exec sbcl --non-interactive --eval '(asdf:load-system :dunge/examples)' --eval '(dunge-examples:write-adaptation-browser-demo)'
```

Repeatable smoke path:

1. Open `examples/adaptation/index.html`, or serve the repo locally and visit
   `/examples/adaptation/`.
2. Choose **Approach the white arch**.
3. Choose **Enter the generated chamber**.
4. Choose **Flee** or **Attack** until the encounter is no longer active.
5. Choose **Take ration**.
6. Choose **Continue deeper**.
7. Choose **Flee** or **Attack** in the deeper generated room.
8. Reload the page and confirm the deeper generated room, encounter state, and
   ration inventory change persist.

See [PROVENANCE.md](PROVENANCE.md) for source/license notes and
[../../ADAPTATION_SUPPORT_AUDIT.md](../../ADAPTATION_SUPPORT_AUDIT.md) for the
engine support audit.
