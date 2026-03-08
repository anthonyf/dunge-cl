## Why

ECE now supports string interpolation (`"Hello $name, $(+ 1 2)"` expands to `(fmt "Hello " name ", " (+ 1 2))`) and a `lines` function that joins arguments with newlines. The game code currently uses verbose `(fmt ...)` calls and repetitive `(display ...) (newline)` patterns for text output. Adopting these features will make the code read more like prose and dramatically reduce boilerplate in display-heavy functions.

## What Changes

- Replace `(fmt "prefix" var "suffix")` patterns with string interpolation `"prefix $var suffix"` / `"prefix $(expr) suffix"` throughout game code
- Replace sequential `(display (fmt ...)) (newline)` blocks with `(display (lines ...))` where multiple lines are built together (especially character-summary)
- Replace `(text "prefix" var "suffix")` with `(text "prefix $var suffix")` where interpolation improves readability
- Replace `(string-append ...)` calls with interpolated strings where appropriate

## Capabilities

### New Capabilities

_None — this is a refactoring of existing output code._

### Modified Capabilities

- `ece-character-creation`: Display functions use interpolated strings and `lines` for cleaner output
- `ece-combat`: Combat stat display and log formatting use interpolated strings

## Impact

- `game/content.scm` — character-summary, equipment, roll-stats, choose-background, and other display functions
- `game/combat.scm` — combat stat display, heal log formatting
- `game/bestiary.scm` — one error message
- No behavioral changes — output is identical, only the source representation changes
