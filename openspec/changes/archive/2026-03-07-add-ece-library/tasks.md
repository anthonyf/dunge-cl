## 1. Register with qlot

- [x] 1.1 Add `git ece git@github.com:anthonyf/ece.git` to `qlfile`
- [x] 1.2 Run `qlot install` and verify it completes successfully

## 2. Wire into ASDF

- [x] 2.1 Add `"ece"` to `:depends-on` list in `dunge.asd`
- [x] 2.2 Verify `(asdf:load-system :dunge)` loads successfully with ece available
