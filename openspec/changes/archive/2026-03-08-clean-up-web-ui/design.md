## Context

The web UI is functional but minimal. Content is top-aligned, buttons have no keyboard support, and transitions are instant. All UI lives in two string variables in `web-export.lisp`: `*html-template*` (HTML + CSS) and `*js-renderer*` (JS). Changes are purely CSS + JS — no build system or game logic changes needed.

## Goals / Non-Goals

**Goals:**
- Vertically center game content in the viewport
- Add keyboard navigation for choice buttons (arrows, Enter/Space, number keys)
- Add visual focus indicator for keyboard users
- Add subtle fade-in transition on content change
- Auto-focus first choice after each render
- Keep the monospace "dungeon terminal" aesthetic

**Non-Goals:**
- Sound effects or audio (future work)
- Changing the font to serif/sans-serif
- Mobile-specific touch gestures
- Saving/loading game state
- Changing the game's color scheme significantly

## Decisions

### 1. Vertical centering via flexbox

Change body from `justify-content: center` (horizontal only) to also include `align-items: center` with `min-height: 100vh`. When content is short it centers vertically; when content overflows it scrolls naturally.

**Alternative considered:** CSS Grid with `place-items: center`. Slightly cleaner but flexbox is already in use and works the same way.

### 2. Keyboard navigation via keydown listener on #game-controls

Add a single `keydown` event listener on the `#game-controls` container that handles:
- `ArrowDown` / `ArrowRight` — focus next button (wrap to first)
- `ArrowUp` / `ArrowLeft` — focus previous button (wrap to last)
- `Enter` / `Space` — click the focused button
- `1`-`9` — directly activate the Nth choice

Buttons are already focusable `<button>` elements, so `Tab` navigation works for free. The arrow key handler adds game-like navigation on top.

**Alternative considered:** Per-button keydown listeners. Rejected because a single delegated listener is simpler and handles the wrap-around logic in one place.

### 3. Focus management after render

After `renderStep()` creates buttons, automatically focus the first button. This means keyboard users can immediately start navigating without tabbing into the game area.

For text prompts, the input is already auto-focused (existing behavior).

### 4. Fade-in transition via CSS opacity

Add a CSS class `.fade-in` with `animation: fadeIn 150ms ease-in`. Apply it to `#game-output` and `#game-controls` after each render. This gives a subtle "passage change" feel without being slow.

**Alternative considered:** JS-driven opacity transition. Rejected because CSS animation is simpler and doesn't require setTimeout cleanup.

### 5. Button focus style

Add `.choice-btn:focus` style with a visible outline/border change. Use the existing accent color `#e94560` for the focus indicator, matching the prompt input focus style. Add `outline: none` and use a custom border/box-shadow instead for a cleaner look.

## Risks / Trade-offs

- **[Risk] Vertical centering may jump on long content**: When text is short it centers, when it's long it top-aligns. The transition between states could feel jarring. → Mitigation: Use `align-items: flex-start` initially and only center when content fits in viewport, OR accept the slight jump since most passages are short.

- **[Risk] Number keys conflict with text input**: Pressing `1` while a text prompt is focused would type `1` AND trigger the choice shortcut. → Mitigation: Only bind number keys when choice buttons are rendered, not during text prompts.

- **[Risk] Fade-in on every step**: May feel sluggish on fast interactions. → Mitigation: 150ms is fast enough to be barely noticeable. Can be tuned or removed if it feels slow.
