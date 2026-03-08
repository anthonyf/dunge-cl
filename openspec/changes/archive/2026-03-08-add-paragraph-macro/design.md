## Context

The `text` macro outputs formatted text + one newline. To get a blank line (paragraph break), rooms use `(text "")` after content lines. This is repetitive — 21 instances in content.scm alone.

## Goals / Non-Goals

**Goals:**
- Add `p` macro that outputs text + two newlines (paragraph break)
- Clean up content.scm by replacing `(text ...) (text "")` with `(p ...)`

**Non-Goals:**
- Removing `text` macro — it's still useful for lines without trailing blank lines
- Changing combat.scm or other files

## Decisions

**`p` macro implementation**: Same as `text` but adds an extra `(newline)` call. Defined as:
```scheme
(define-macro (p . args)
  `(begin (display (fmt ,@args)) (newline) (newline)))
```

**Placement**: Defined right after `text` in engine.scm.

## Risks / Trade-offs

None — purely additive change with no behavioral impact on existing code.
