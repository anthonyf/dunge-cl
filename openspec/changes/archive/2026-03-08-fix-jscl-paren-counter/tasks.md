## 1. Fix paren counter

- [x] 1.1 Update `count-parens` in `web-export.lisp` to handle `#\` character literals — when `prev-char` is `\` and the char before that was `#`, skip the current character (don't process it as string delimiter or paren)

## 2. Verify

- [x] 2.1 Run `make build` and confirm the build succeeds with no read errors
- [x] 2.2 Check that `dist/index.html` contains compiled `evaluate`, `self-evaluating-p`, `variable-p`, `make-procedure`, `qq-expand`, and `application-p` functions
- [x] 2.3 Run `make test` to confirm no regressions
