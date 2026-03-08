## 1. Background Record

- [x] 1.1 Add `define-record background` with fields: name description equipment-thunk armor gold
- [x] 1.2 Convert `*backgrounds*` entries from `list` to `make-background`
- [x] 1.3 Remove manual `bg-*` accessor functions
- [x] 1.4 Update all `bg-*` references to use generated `background-*` accessors

## 2. Bestiary Record

- [x] 2.1 Add `define-record bestiary-entry` with fields: name hp armor attack-die str dex wil
- [x] 2.2 Convert `*bestiary*` entries from `list` to `make-bestiary-entry`
- [x] 2.3 Simplify `make-enemy-from-bestiary` to use record accessors instead of car/cddr chains

## 3. Verify

- [x] 3.1 Run all tests and verify they pass
