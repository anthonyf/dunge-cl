## Why

The web UI was deleted along with the old CL engine. The game now runs on ECE but only has a terminal interface. Restoring browser play expands access — a single HTML file anyone can open.

## What Changes

- Rewrite `web-export.lisp` to compile the ECE evaluator + game via JSCL
- Pre-parse all .scm files at build time (SBCL reads with ECE's custom readtable, serializes as CL data literals for JSCL)
- Use ECE's `call/cc` for browser I/O: capture continuation at `read-line`, yield to browser event loop, resume when user clicks a choice
- Patch ECE I/O primitives (`display`, `newline`, `read-line`) for DOM output and continuation-based input
- Produce a single standalone `dist/index.html` with all JS inlined
- Add browser-specific boot code (`browser-boot.scm`) that defines the `browser-step` / patched `read-line` pattern

## Capabilities

### New Capabilities

- `ece-web-export`: Build process that compiles ECE evaluator and pre-parsed game files to a standalone HTML file via JSCL

### Modified Capabilities

(none)

## Impact

- `web-export.lisp` — complete rewrite
- `game/` .scm files — no changes (browser uses same game code)
- ECE library — no changes (call/cc already supported)
- Build output: `dist/index.html` (standalone, all JS inlined)
