# Dunge

Dunge is a Common Lisp engine for choice-based interactive fiction. Games are
authored as safe `.dunge` data files with a small shorthand DSL for rooms,
choices, story flags, and effects, then loaded, validated, and evaluated by the
runtime.

## Documentation

- [Authoring Guide](AUTHORING.md): how to write `.dunge` games, with examples
  for every public source form.
- [Language Architecture](ARCHITECTURE.md): implementation notes for the
  source schema, AST, runtime, validation, and save/load model.
- [Game Design Document](DESIGN.md): long-term game design direction.
- [Story Notes](STORY.md): narrative design notes.

## Examples

- `examples/basic.dunge` loads two simple rooms from `examples/basic/`.
- `examples/control-panel.dunge` demonstrates entity state, refs, actions, and
  conditional room text.
- `styles/game.dunge` is a larger authored example with global clue and
  deduction state.
