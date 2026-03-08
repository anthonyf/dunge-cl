## Why

The JSCL submodule is pinned to an old version (0ba3552) because the latest (ab1327e) has breaking API changes. The current `generate-browser-ece` uses a fragile text-based line scanner with `count-parens` to strip forms from ECE source — this already caused a production bug when `#\"` character literals confused the paren counter. Since the latest JSCL supports `handler-case` and `eval-when`, we can stop stripping those forms entirely, and replace the text scanner with CL's own reader for robust form-level filtering.

## What Changes

- **BREAKING**: Update JSCL submodule from 0ba3552 to ab1327e
- Update `web-export.lisp` to use JSCL's new API (package `:jscl-xc`, new `bootstrap` signature, access `compile-application` from new location)
- Replace `generate-browser-ece` text scanner with form-level reader/filter using SBCL's `read`
- Remove `count-parens`, `defun-name-match-p`, `read-ece-source-lines` helper functions
- Reduce skip list — stop filtering `eval-when` blocks, `ece-try-eval`, and `ece-string->number` (JSCL now handles `handler-case`)
- Simplify `*patches-source*` to only redefine I/O functions (no longer need `ece-try-eval` or `ece-string->number` patches)

## Capabilities

### New Capabilities

_None_

### Modified Capabilities

- `ece-web-export`: Build process changes from text-based source filtering to form-level filtering; JSCL API calls updated for new version; patches simplified since handler-case/eval-when now supported. Remove debug console.log requirement (already removed from code).

## Impact

- `web-export.lisp` — major refactor of generate-browser-ece and JSCL integration code
- `vendor/jscl` — submodule pointer updated
- `.github/workflows/deploy.yml` — may need adjustment if JSCL bootstrap produces output differently
- Build output (dist/index.html) should be functionally identical
