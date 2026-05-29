# Adaptation Testbed Example

This directory holds the first Dunge crawler adaptation skeleton. It is a
loadable example, not a complete game yet.

The skeleton deliberately contains only:

- a safe camp;
- a dungeon threshold;
- one placeholder generated chamber;
- a starter player record;
- a few authored tables that describe future room, loot, and encounter data.

The next implementation slices should replace the placeholder chamber with
Common Lisp procedures that roll tables, create persistent room instances,
resolve encounters, and mutate player inventory.

See [PROVENANCE.md](PROVENANCE.md) for source/license notes and
[../../ADAPTATION_SUPPORT_AUDIT.md](../../ADAPTATION_SUPPORT_AUDIT.md) for the
engine support audit.
