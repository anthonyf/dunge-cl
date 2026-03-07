## 1. Build Infrastructure

- [x] 1.1 Rewrite `web-export.lisp` scaffold: load JSCL, define paths, set up build pipeline (no game compilation yet — just produce an HTML file with JSCL runtime)
- [x] 1.2 Implement .scm pre-parser: load ECE, use its readtable to read all .scm files (prelude + game/), serialize parsed forms as CL data into a generated temp file
- [x] 1.3 Implement bundled `ece-load` patch: hash table of filename → forms, evaluate forms in sequence

## 2. JSCL Compatibility Patches

- [x] 2.1 Patch `handler-case` usages: replace `ece-read` (no-op in browser), `ece-try-eval` (simple wrapper), `ece-string->number` (safe fallback)
- [x] 2.2 Patch I/O primitives: `ece-display` and `ece-newline` append to `*output-buffer*` string; `finish-output` becomes no-op
- [x] 2.3 Patch `ece-clear-screen` to no-op (no ANSI escapes in browser)
- [x] 2.4 Patch any other JSCL-incompatible constructs found during compilation

## 3. Browser I/O via call/cc

- [x] 3.1 Write `browser-boot.scm`: defines `*top-continuation*`, `*resume-continuation*`, `browser-step`, and `browser-read-line`
- [x] 3.2 Add browser boot CL code: load prelude + game files via bundled ece-load, install `browser-read-line` as `read-line`, expose `browserStep` to JS via `jscl::oget`

## 4. Browser UI

- [x] 4.1 Write HTML/CSS template (dark terminal theme, game-output + game-controls divs)
- [x] 4.2 Write JS rendering logic: call `browserStep`, parse output buffer, render text as `<pre>`, detect choices and create buttons, handle text prompts with input field
- [x] 4.3 Inline jscl.js and dunge.js into index.html

## 5. Integration and Test

- [x] 5.1 Run full build (`sbcl --load web-export.lisp`), fix compilation errors iteratively
- [x] 5.2 Test in browser: character creation flow, town navigation, combat encounter
