# Adaptation Testbed Example

This directory holds the first Dunge crawler adaptation skeleton. It is a
loadable example, not a complete game yet.

The skeleton deliberately contains only:

- a safe camp;
- a dungeon threshold;
- one placeholder generated chamber in authored `.dunge`;
- a starter player record;
- a few authored tables that describe room, loot, encounter, and graph-link
  data.

The example also exposes CL helpers that can roll and install a generated
starting player before play, and helpers that roll the authored tables to create
and recall a persistent two-room generated dungeon graph. The first resolver
layer now applies basic loot, extracts generated exits, and lets CL replace an
authored graph-link template with concrete generated room ids. The next
implementation slice should add encounter state.

See [PROVENANCE.md](PROVENANCE.md) for source/license notes and
[../../ADAPTATION_SUPPORT_AUDIT.md](../../ADAPTATION_SUPPORT_AUDIT.md) for the
engine support audit.
