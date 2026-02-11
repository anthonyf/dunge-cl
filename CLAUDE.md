# Dunge — Text Adventure Engine in Common Lisp

## Quick Reference

```bash
# Terminal REPL (in SBCL)
(asdf:load-system :dunge)
(dunge:game-repl (dunge:room 'start))

# Web build (produces dist/)
sbcl --load web-export.lisp

# Run tests
(asdf:test-system :dunge)
```

## Architecture

**Source files** load in order (src/):
1. `utils.lisp` — string utilities (trim-whitespace, validate-non-empty-string)
2. `data-store.lisp` — nested hash table storage (*data-store*, lookup, ref)
3. `dice.lisp` — dice rolling
4. `text-layout.lisp` — text formatting (columns, text macro, nl, spaces)
5. `engine.lisp` — game loop, generic functions, context classes
6. `room.lisp` — room system (room, exit, gate, p, prompt elements)
7. `main.lisp` — game content (room definitions)

**Key pattern:** Two UI contexts share the same engine:
- `print-context` — terminal REPL (synchronous read-line loop)
- `browser-context` — web UI (event-driven DOM rendering)

**Engine dispatch:** Generic functions `perform`, `menu`, `out`, `execute-action` dispatch on context type. Rooms are declarative trees of elements (p, exit, gate, prompt) that `perform` walks.

**Data store:** Global `*data-store*` with nested hash tables. Access via `(lookup key1 key2 ...)` and `(setf (lookup ...) value)`. `ref` creates lazy lookup closures for use in room content.

## Conventions

- All packages use `uiop:define-package` (not `defpackage`)
- Package per file: `dunge/utils`, `dunge/data-store`, `dunge/engine`, `dunge/room`, etc.
- `dunge` package re-exports everything via `:mix-reexport`
- No changes to src/ files for web compatibility — patches go in web-export.lisp
- main.lisp should be the last file to load.

## JSCL Web Export Gotchas

- JSCL `oget` is in the `JSCL` package — code in other packages must use `jscl::oget`
- JSCL strings are char arrays, not JS strings — use `jscl::jsstring` for DOM APIs, `jscl::clstring` to convert back
- `uiop:define-package` shim must create sub-packages matching SBCL's home-package structure (e.g. `UIOP/PACKAGE`, `UIOP/UTILITY`)
- Functions defined in browser-context.lisp are internal to `dunge/engine` — boot code must use qualified names
- JSCL doesn't support `~{~A~}` format directive — use dolist+princ instead
- `#j:` reader syntax works in cross-compilation context
- `uiop:symbol-call` needed for JSCL functions since the package doesn't exist at read time
