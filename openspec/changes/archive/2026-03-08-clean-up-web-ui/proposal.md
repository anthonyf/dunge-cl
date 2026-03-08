## Why

The web UI works but feels unpolished — content is pinned to the top of the viewport, buttons have no keyboard support, and there are no visual transitions between game steps. For a dungeon crawler, the interface should feel like a clean terminal with good accessibility.

## What Changes

- Vertically center the game content in the viewport so it floats in the middle of the screen
- Add keyboard navigation: arrow keys to move between choice buttons, Enter/Space to activate, number keys (1-9) as direct shortcuts
- Add a focused-button visual state (subtle glow/highlight) so keyboard users can see which button is selected
- Auto-focus the first choice button after each step renders
- Add a subtle fade-in transition (150ms) when new content renders
- Keep monospace "dungeon terminal" font aesthetic
- Ensure text prompts remain keyboard-friendly (already support Enter to submit)

## Capabilities

### New Capabilities

- `web-keyboard-nav`: Keyboard navigation for choice buttons and text prompts in the browser UI

### Modified Capabilities

- `ece-web-export`: Layout changes (vertical centering), button focus styles, fade-in transition, auto-focus behavior after render

## Impact

- `web-export.lisp` — CSS changes in `*html-template*`, JS changes in `*js-renderer*`
- No backend/build changes — purely frontend CSS + JS
- No changes to game logic or ECE code
