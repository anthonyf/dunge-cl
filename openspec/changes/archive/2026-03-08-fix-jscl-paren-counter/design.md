## Context

`generate-browser-ece` in `web-export.lisp` reads ECE's `ece.lisp` line by line and filters out incompatible forms (eval-when blocks, specific defuns, ece-load calls, repl). It uses a `count-parens` helper to track parenthesis depth so it knows when a multi-line form ends.

The `count-parens` function handles strings (ignoring parens inside `"..."`) and comments (ignoring after `;`), but does NOT handle CL character literals (`#\X`). When it encounters `#\"` (the character literal for `"`), it sees the `"` and enters string mode. All subsequent parens are ignored until another `"` exits string mode — but the next `"` might be far away or never come, throwing the depth count off completely.

## Goals / Non-Goals

**Goals:**
- Fix `count-parens` to correctly handle `#\` character literals
- The web build should produce a working game (all ECE functions compiled by JSCL)

**Non-Goals:**
- Replacing the line-based filter with a proper CL reader (would be a larger refactor)
- Fixing other potential edge cases in the filter (e.g., `#|...|#` block comments)

## Decisions

### Handle `#\` character literals in `count-parens`

**Decision:** When `count-parens` sees `#` followed by `\`, skip the next character entirely. This prevents `#\"` from triggering string mode and `#\(` / `#\)` from being counted as real parens.

**Implementation:** Track the previous character. When `prev-char` is `#` and current char is `\`, set a flag to skip the next character. Or simpler: when we see `\` after `#`, consume the backslash and the following character without processing.

**Alternative considered:** Using CL's `read` to parse forms instead of line-based counting — rejected as too large a change for this bug fix, and would require handling the custom readtable differences between SBCL and JSCL.

## Risks / Trade-offs

- **Other character literals:** `#\Space`, `#\Newline` etc. are multi-character names after `#\`. The fix only needs to skip the character immediately after `#\`, which handles `#\"`, `#\(`, `#\)`, `#\;` — the problematic cases. Multi-character names like `#\Space` are just identifiers that don't contain special chars, so they're harmless.
