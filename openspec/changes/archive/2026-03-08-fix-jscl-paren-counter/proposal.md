## Why

The web build produces a blank screen because `generate-browser-ece`'s `count-parens` function mishandles `#\"` (CL character literal for `"`). It enters "in-string" mode on the `"`, causing all subsequent parentheses in the `eval-when` block to be ignored. The filter thinks `eval-when` ends early, leaving orphaned code and unmatched close parens in the output. JSCL hits the read error and silently stops compiling — everything after the error, including `evaluate` and all its helper functions, is never compiled.

## What Changes

- **Fix `count-parens` in `web-export.lisp`**: Handle `#\` character literals so that `#\"`, `#\(`, `#\)` don't confuse the paren counter or trigger string mode.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `ece-web-export`: Fix the `count-parens` paren-counting logic so the `eval-when` filter correctly skips the entire block, producing valid CL source for JSCL compilation.

## Impact

- `web-export.lisp` — fix `count-parens` function in `generate-browser-ece`
- No changes to game logic, ECE engine, deploy workflow, or HTML template
