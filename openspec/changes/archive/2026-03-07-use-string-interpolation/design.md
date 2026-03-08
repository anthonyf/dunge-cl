## Context

Game code uses `(fmt "prefix" var "suffix")` for string building and repetitive `(display ...) (newline)` sequences for multi-line output. ECE now provides string interpolation at the reader level (`"Hello $name"` → `(fmt "Hello " name)`) and a `lines` function that joins args with newlines.

## Goals / Non-Goals

**Goals:**
- Replace `fmt` calls with interpolated strings where it improves readability
- Use `lines` to collapse sequential `(display ...) (newline)` blocks into single expressions
- Preserve identical output — pure refactoring, no behavior change

**Non-Goals:**
- Rewriting `format-attack-lines` in combat.scm — it uses string parameters as prefix/suffix, interpolation doesn't help there
- Changing `display-choices` — it's procedural with a counter, doesn't fit `lines`
- Changing the `text` and `p` function definitions themselves

## Decisions

**Use `$var` for simple variable references, `$(expr)` for function calls.**
- `"Welcome $name!"` for variables
- `"STR: $(character-str *player*)"` for accessor calls
- Rationale: matches ECE's interpolation syntax directly

**Use `lines` only for multi-line display blocks, not for single lines.**
- `character-summary` is the prime candidate: 28 lines of display/newline → 12 lines with `lines`
- Combat stat display (2 lines + blank) also benefits
- Single `(text ...)` calls stay as `text` — no need to wrap in `lines`

**Use `""` within `lines` for blank line separators.**
- `(lines "a" "" "b")` produces `"a\n\n b\n"` — the empty string gets a newline, creating a visual gap
- This replaces standalone `(newline)` calls between display blocks

## Risks / Trade-offs

- [Readability of long interpolated expressions] → Keep `$(...)` expressions short; use `let` bindings for complex sub-expressions (e.g., heal log in combat.scm)
- [Dollar signs in game text] → Use `$$` to escape. Unlikely in current content but worth noting.
