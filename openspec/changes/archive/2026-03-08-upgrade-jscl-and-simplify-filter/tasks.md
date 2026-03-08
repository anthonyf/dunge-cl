## 1. Update JSCL submodule

- [x] 1.1 Update vendor/jscl submodule from 0ba3552 to ab1327e

## 2. Replace generate-browser-ece with form-level filter

- [x] 2.1 Replace `generate-browser-ece`, `read-ece-source-lines`, `defun-name-match-p`, and `count-parens` with form-level reader/filter using CL's `read` with ECE's readtable
- [x] 2.2 Reduce skip list to I/O-only functions (remove ece-try-eval, ece-string->number from skip list; stop filtering eval-when blocks)

## 3. Update JSCL API calls

- [x] 3.1 Update bootstrap call from `(uiop:symbol-call :jscl :bootstrap)` to new `(uiop:symbol-call :jscl-xc :bootstrap output-dir "jscl")` API
- [x] 3.2 Update compile-application call to use `jscl-xc::compile-application` (not exported, use package-qualified symbol)
- [x] 3.3 Update JSCL JS path reference if bootstrap output location changed

## 4. Simplify patches

- [x] 4.1 Remove ece-try-eval and ece-string->number from `*patches-source*`
- [x] 4.2 Update comment in web-export.lisp that says JSCL doesn't support handler-case/eval-when

## 5. Verify

- [x] 5.1 Run `make build` and verify it succeeds
- [x] 5.2 Verify all critical ECE functions are present in compiled JS output
- [x] 5.3 Run `make test` and verify all tests pass
- [x] 5.4 Open dist/index.html in browser and verify game works
