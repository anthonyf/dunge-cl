## 1. Delete Old CL Source Files

- [x] 1.1 Delete all old engine files from src/: packages.lisp, utils.lisp, data-store.lisp, dice.lisp, serialize.lisp, text-layout.lisp, engine.lisp, room.lisp, item.lisp, character.lisp, character-creation.lisp, combat.lisp, bestiary.lisp, container.lisp, overflow.lisp, character-sheet.lisp, inventory.lisp, main.lisp

## 2. Delete Old CL Tests

- [x] 2.1 Delete test files: tests/main.lisp, tests/data-store.lisp, tests/item.lisp, tests/room.lisp
- [x] 2.2 Delete tests/main.fasl if present

## 3. Simplify dunge.asd

- [x] 3.1 Update dunge.asd: remove alexandria dependency, reduce components to just ece-bootstrap, remove test system definition

## 4. Verify

- [x] 4.1 Verify ECE game still runs: `qlot exec sbcl --eval '(asdf:load-system :dunge)' --eval '(dunge/ece-bootstrap:start)'`
