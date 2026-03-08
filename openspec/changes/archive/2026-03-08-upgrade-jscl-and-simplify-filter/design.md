## Context

The web build (`web-export.lisp`) compiles ECE source to JavaScript via JSCL. The current approach uses a text-based line scanner (`generate-browser-ece`) with `count-parens` to strip forms from ECE source before JSCL compilation. This already caused a production bug when `#\"` character literals confused the paren counter.

JSCL is pinned to an old version (0ba3552) because the latest (ab1327e) has breaking API changes. The latest JSCL supports `handler-case` and `eval-when`, meaning we no longer need to strip those forms.

## Goals / Non-Goals

**Goals:**
- Upgrade JSCL submodule to ab1327e
- Replace text-based source filtering with form-level filtering using CL's reader
- Simplify patches by leveraging JSCL's `handler-case`/`eval-when` support
- Maintain identical build output (dist/index.html works the same)

**Non-Goals:**
- Changing the browser I/O model (still need to replace ece-display, ece-load, etc.)
- Changing the bundled-sources pre-parsing approach
- Updating ECE itself to support browser mode natively (future work)

## Decisions

### 1. Form-level filtering via CL reader (over text-based scanning)

Read `ece.lisp` as CL forms using SBCL's `read` (with ECE's readtable), then filter by form type/name. This is semantically exact — no paren counting, no character literal edge cases.

**Implementation:**
```lisp
(defun read-ece-forms ()
  "Read all forms from ece.lisp using ECE's readtable."
  (let ((path (asdf:system-relative-pathname :ece "src/ece.lisp")))
    (with-open-file (stream path)
      (let ((*readtable* ece::*ece-readtable*)
            (*package* (find-package :ece))
            (eof (gensym)))
        (loop for form = (read stream nil eof)
              until (eq form eof)
              collect form)))))

(defun skip-form-p (form skip-names)
  "Return T if FORM should be filtered out."
  (and (listp form)
       (or
         ;; (defun NAME ...) where NAME is in skip list
         (and (eq (car form) 'cl:defun)
              (member (string (cadr form)) skip-names :test #'string-equal))
         ;; Top-level (ece-load ...) call
         (and (symbolp (car form))
              (string-equal (symbol-name (car form)) "ECE-LOAD"))
         ;; Top-level (repl) or (defun repl ...)
         (and (eq (car form) 'cl:defun)
              (string-equal (symbol-name (cadr form)) "REPL")))))

(defun generate-browser-ece ()
  "Generate filtered ECE source as a string of printed CL forms."
  (let ((forms (read-ece-forms))
        (skip-names '("ece-read" "ece-display" "ece-newline"
                       "ece-load" "ece-save-continuation!"
                       "ece-load-continuation" "ece-clear-screen" "ece-sleep")))
    (with-output-to-string (out)
      (format out "(in-package :ece)~%~%")
      (let ((*package* (find-package :ece))
            (*print-case* :downcase)
            (*print-circle* t))
        (dolist (form forms)
          (unless (skip-form-p form skip-names)
            (prin1 form out)
            (terpri out)
            (terpri out)))))))
```

**Alternative considered:** Keep text-based filtering but improve count-parens. Rejected because text scanning is fundamentally fragile — any new reader syntax in ECE could break it again.

### 2. Reduced skip list — keep handler-case/eval-when forms

Since JSCL now supports `handler-case` and `eval-when`:

| Function | Old action | New action | Why |
|----------|-----------|------------|-----|
| `ece-try-eval` | Skip + patch | **Keep original** | Uses handler-case, now supported |
| `ece-string->number` | Skip + patch | **Keep original** | Uses handler-case, now supported |
| `eval-when` blocks | Skip entirely | **Keep** | Now supported by JSCL |
| `ece-read` | Skip + patch | Skip + patch | Still needs browser replacement |
| `ece-display` | Skip + patch | Skip + patch | Still needs browser I/O |
| `ece-newline` | Skip + patch | Skip + patch | Still needs browser I/O |
| `ece-load` | Skip + patch | Skip + patch | Still needs bundled sources |
| `ece-save/load-continuation` | Skip + patch | Skip + patch | No filesystem in browser |
| `ece-clear-screen` | Skip + patch | Skip + patch | No terminal in browser |
| `ece-sleep` | Skip + patch | Skip + patch | Can't block event loop |
| `repl` | Skip | Skip | Browser uses browser-step |
| `(ece-load ...)` call | Skip | Skip | Prelude pre-bundled |

### 3. JSCL API migration

The new JSCL (ab1327e) has these API changes we must adapt to:

| Change | Old | New | Our code |
|--------|-----|-----|----------|
| Package | `:jscl` | `:jscl-xc` | Update `uiop:symbol-call` package arg |
| Bootstrap | `(bootstrap &optional verbose)` | `(bootstrap output-dir prefix &key verbose)` | Pass dist dir and "jscl" prefix |
| compile-application | Exported from `:jscl` | Not exported, in `jscl-xc::` | Use `jscl-xc::compile-application` |
| New keyword | — | `:jscl-name "jscl"` | Pass explicitly |
| JSCL output path | `dist/jscl.js` inside JSCL dir | Caller-specified dir | Read from returned path or specified output-dir |
| Feature flags | `:jscl-xc` | `:jscl-target` added by bootstrap | No direct impact on our code |

**Bootstrap call change:**
```lisp
;; Old:
(uiop:symbol-call :jscl :bootstrap)
;; Read JSCL JS from: vendor/jscl/dist/jscl.js

;; New:
(let ((jscl-dist (namestring (merge-pathnames "dist/" *jscl-dir*))))
  (uiop:symbol-call :jscl-xc :bootstrap jscl-dist "jscl"))
;; JSCL JS still at: vendor/jscl/dist/jscl.js
```

**compile-application call change:**
```lisp
;; Old:
(uiop:symbol-call :jscl :compile-application files output)

;; New — not exported, use package-qualified:
(jscl-xc::compile-application files output)
;; Or via symbol-call with internal symbol access
```

### 4. Simplify patches

Remove `ece-try-eval` and `ece-string->number` patches from `*patches-source*` since the originals (which use `handler-case`) now compile correctly in JSCL.

## Risks / Trade-offs

- **[Risk] Form printing fidelity**: `prin1` may not reproduce forms exactly as they appeared in source (e.g., whitespace, comments stripped, reader macros expanded). → Mitigation: ECE already pre-parses .scm files the same way. The semantics are preserved even if formatting differs. JSCL compiles forms, not text.

- **[Risk] ECE readtable required at read time**: The form-level reader needs ECE's readtable loaded. → Mitigation: We already load ECE via ASDF in Step 1 before filtering begins.

- **[Risk] JSCL handler-case may be incomplete**: The latest JSCL claims handler-case support but may have edge cases. → Mitigation: Test that `ece-try-eval` and `ece-string->number` work correctly in the browser after the change. If they don't, re-add those specific patches.

- **[Risk] compile-application not exported**: Using `jscl-xc::compile-application` accesses an internal symbol. → Mitigation: This is how JSCL's own `build-node-repl` works internally. The function is stable and documented in source.
