## Why

Room functions are littered with `(text "")` calls just to add blank lines between paragraphs. A `(p ...)` macro that outputs text followed by an extra newline eliminates this boilerplate and makes room definitions cleaner.

## What Changes

- Add `(p ...)` macro to engine.scm — like `(text ...)` but appends an extra newline
- Replace `(text ...) (text "")` pairs with `(p ...)` throughout content.scm

## Capabilities

### New Capabilities

(none — this is a small addition to the existing room system)

### Modified Capabilities

- `ece-room-system`: Adding `p` macro as a paragraph-level display helper alongside `text`

## Impact

- `game/engine.scm` — Add `p` macro definition
- `game/content.scm` — Replace `(text ...) (text "")` patterns with `(p ...)`
