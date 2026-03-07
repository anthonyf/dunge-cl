## Why

The current dunge engine is implemented in Common Lisp using CLOS generic functions and a custom room DSL. Moving the game engine to ECE (the project author's own Scheme-like language with first-class continuations) enables continuation-based save/load, a unified scripting language for all game content, and a path toward browser deployment where call/cc handles async I/O. This is Change 1 of 4 in the ECE migration — establishing the core engine and terminal playability.

## What Changes

- **New**: ECE-based IF engine with room system, choice menus with guards, text prompts with validation, and a game loop — all written in ECE
- **New**: Game state management using ECE hash tables
- **New**: Character creation flow ported to ECE (name entry, background selection, stat rolling, equipment, summary)
- **New**: Town/adventure content ported to ECE (town square, blacksmith, adventure board)
- **New**: CL bootstrap that loads ECE and evaluates game scripts
- **New**: Dice rolling utilities in ECE
- Existing CL engine remains alongside (not removed until Change 4)

## Capabilities

### New Capabilities
- `ece-room-system`: Room definition, rendering, and navigation in ECE (rooms with title, text paragraphs, exits, conditional gates, text prompts)
- `ece-choice-system`: Choice menus with guard conditions and player input handling in ECE
- `ece-game-state`: Game state management via ECE hash tables (replaces CL data-store)
- `ece-game-loop`: Main game loop and CL bootstrap that loads and runs ECE game scripts
- `ece-character-creation`: Character creation flow in ECE (name, background, stats, equipment, summary)

### Modified Capabilities

_(none — existing CL engine is preserved alongside)_

## Impact

- **New files**: `game/` directory with ECE scripts (engine, rooms, main)
- **Dependencies**: Uses `ece` library (already added via qlot)
- **Entry point**: New CL bootstrap file or function that starts the ECE game
- **Coexistence**: Old `(dunge:game-repl (dunge:room 'start))` continues to work; new ECE path runs in parallel
