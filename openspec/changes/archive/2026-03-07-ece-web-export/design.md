## Context

ECE is a Scheme-like language evaluator written in Common Lisp (~1,100 lines). It uses an explicit control evaluator with a state machine loop and first-class continuations via `call/cc`. The game is written in .scm files that ECE evaluates. JSCL is a CL-to-JS compiler (submodule at `vendor/jscl/`) previously used to compile the old CL engine to JavaScript.

The old web export compiled 17 CL source files directly to JS via JSCL. The new approach compiles the ECE evaluator to JS and has it evaluate pre-parsed game forms in the browser.

## Goals / Non-Goals

**Goals:**
- Single standalone HTML file (`dist/index.html`) with all JS inlined
- Same game code (game/*.scm) runs in both terminal and browser — no forking
- Use `call/cc` for browser I/O — no restructuring of game loop
- Pre-parse .scm files at build time to avoid shipping ECE's reader to the browser

**Non-Goals:**
- Save/load (localStorage persistence) — future work
- Mobile-optimized UI — keep the existing terminal-aesthetic CSS
- Server-side rendering or WebSocket architecture

## Decisions

### Pre-parse .scm files at build time

SBCL loads ECE, reads all .scm files using ECE's custom readtable, and serializes the parsed S-expressions as CL data. JSCL compiles these data literals into JS. The browser never needs ECE's reader or custom readtable.

```
Build: SBCL + ECE readtable reads game/*.scm → CL literals → JSCL → JS
```

The `ece-load` function is patched in the browser to look up pre-parsed forms by filename from a hash table instead of reading from the filesystem.

**Rationale:** ECE's custom readtable uses `copy-readtable`, `set-macro-character`, and `read-delimited-list` — features JSCL doesn't fully support. Pre-parsing sidesteps this entirely.

### call/cc for browser I/O (no ECE changes)

The browser uses nested `call/cc` at the Scheme level to suspend/resume the game loop:

```scheme
(define *top-continuation* nil)
(define *resume-continuation* nil)

(define (browser-step input)
  "Called by JS. First call starts game, subsequent calls provide input."
  (call/cc (lambda (exit)
    (set *top-continuation* exit)
    (if *resume-continuation*
        (*resume-continuation* input)
        (start-game 'start)))))

;; Replaces read-line in browser mode
(define (browser-read-line)
  (call/cc (lambda (k)
    (set *resume-continuation* k)
    (*top-continuation* 'waiting))))
```

Flow:
1. JS calls `browserStep(null)` → ECE evaluates `(browser-step nil)`
2. Game runs until `read-line` → captures resume continuation, escapes to `browser-step` caller via `*top-continuation*`
3. `browser-step` returns `'waiting'` to JS
4. JS renders accumulated output + choices to DOM
5. User clicks choice "3" → JS calls `browserStep("3")`
6. `browser-step` captures new exit continuation, invokes `(*resume-continuation* "3")`
7. Game resumes from `read-line`, processes choice, loops back to step 2

ECE's `call/cc` captures the evaluator's internal `stack` and `conts` registers. Invoking a continuation restores them via `:continuation-apply`. This works across `evaluate` invocations because the continuation contains the complete evaluator state.

**Rationale:** No ECE library changes needed. The same `engine.scm` game loop works for both terminal and browser.

### Output buffering via patched display/newline

In browser mode, `ece-display` and `ece-newline` append to a global string buffer instead of stdout. After each `browser-step` call, JS reads the buffer, renders it to the DOM, and clears it.

```lisp
;; Browser-mode patches (compiled by JSCL)
(defvar *output-buffer* "")

(defun ece-display (obj)
  (setf *output-buffer*
        (concatenate 'string *output-buffer* (princ-to-string obj)))
  obj)

(defun ece-newline ()
  (setf *output-buffer*
        (concatenate 'string *output-buffer* (string #\Newline)))
  nil)
```

### Bundle pre-parsed .scm and prelude into ece-load lookup

At build time, for each .scm file (including prelude.scm), SBCL reads all forms and stores them. A generated CL file defines a hash table mapping filenames to lists of parsed forms:

```lisp
(defvar *bundled-sources* (make-hash-table :test 'equal))
(setf (gethash "game/engine.scm" *bundled-sources*) '((define-record character ...) ...))
(setf (gethash "game/dice.scm" *bundled-sources*) '((define (roll-die sides) ...) ...))
;; etc.
```

The patched `ece-load` evaluates forms from this table:

```lisp
(defun ece-load (filename)
  (let ((forms (gethash filename *bundled-sources*)))
    (let ((result nil))
      (dolist (expr forms result)
        (setf result (evaluate expr))))))
```

### Patch handler-case for JSCL

ECE uses `handler-case` in three places: `ece-read`, `ece-try-eval`, and `ece-string->number`. JSCL doesn't support the CL condition system. Patches:

- `ece-read` — not needed in browser (we pre-parse everything)
- `ece-try-eval` — used by REPL only, not needed in browser
- `ece-string->number` — wrap with JSCL-compatible error handling or use `parse-integer` with `:junk-allowed t`

### Inline everything into index.html

The build produces a single HTML file:
1. JSCL runtime JS (from `vendor/jscl/dist/jscl.js`)
2. Compiled dunge JS (ECE evaluator + patches + bundled game data + browser boot)
3. HTML/CSS for the game UI
4. All inlined via `<script>` tags

### Browser UI structure

Reuse the CSS from the old web export (terminal aesthetic, dark theme). The DOM structure:

```html
<div id="game">
  <div id="game-output"></div>    <!-- text output -->
  <div id="game-controls"></div>  <!-- choice buttons -->
</div>
```

JS rendering after each `browser-step`:
1. Parse `*output-buffer*` content
2. Create `<pre>` elements for text output
3. Detect choice lines (numbered "  1. Label") and create buttons
4. Button click calls `browserStep("N")` where N is the choice number

### Browser boot sequence

The boot code in Lisp (compiled by JSCL) exposes `browserStep` to JS:

```lisp
;; Load prelude (from bundled sources)
(ece-load "prelude.scm")

;; Load all game files (from bundled sources)
(ece-load "game/engine.scm")
(ece-load "game/dice.scm")
;; ... etc

;; Install browser-mode read-line, init player
(evaluate '(begin
  (define (read-line) (browser-read-line))
  (init-player!)))

;; Expose to JS
(setf (jscl::oget #j:window "browserStep")
      (lambda (input)
        (setf *output-buffer* "")
        (evaluate (list 'browser-step input))
        *output-buffer*))
```

## Risks / Trade-offs

- **[JSCL compatibility]** ECE may use CL features JSCL doesn't support beyond what's been identified. Mitigation: iterative patching during implementation. ECE is only ~1,100 lines.
- **[Continuation size]** Each `call/cc` copies the entire evaluator stack. For a text adventure this is small, but worth monitoring.
- **[Choice parsing]** Extracting choices from text output (detecting "  1. Label" patterns) is fragile. Alternative: accumulate choices in a structured buffer alongside text output. Can refine later.
- **[No read-line for prompts]** The `prompt` element also uses `read-line` (via `handle-prompt` in engine.scm). The same `call/cc` pattern works — browser would show a text input instead of buttons when a prompt is active. Need to distinguish "waiting for choice" vs "waiting for text input".
