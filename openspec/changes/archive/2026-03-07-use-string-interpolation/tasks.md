## 1. content.scm — String interpolation

- [x] 1.1 Replace `fmt` calls and `text`/`p` args with interpolated strings in content.scm (welcome text, background choice labels, swap options, equipment display, stat rolls)
- [x] 1.2 Rewrite `character-summary` to use `(display (lines ...))` with interpolated strings for the stat block

## 2. combat.scm — String interpolation

- [x] 2.1 Replace combat stat display (`enemy HP/STR`, `Your HP/STR`) with interpolated strings and `lines`
- [x] 2.2 Rewrite `format-heal-log` to use interpolated strings with let bindings

## 3. bestiary.scm — Minor cleanup

- [x] 3.1 Replace `(error (fmt "Unknown enemy: " name))` with `(error "Unknown enemy: $name")`

## 4. Verify

- [x] 4.1 Run all tests and confirm identical output behavior
