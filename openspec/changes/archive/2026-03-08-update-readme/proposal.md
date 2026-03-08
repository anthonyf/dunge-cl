## Why

The README and TODOs.org are stale after the ECE migration. The README doesn't mention ECE at all, lists outdated Makefile targets (`test-web`, `test-all`), and describes the architecture in CL-only terms. ECE is the core technology and should be prominently featured with a link to its repository.

## What Changes

- Update README.org tagline to: "A text adventure engine built with ECE (a Scheme on Common Lisp), playable in the terminal or browser."
- Add ECE to the overview section explaining the layered architecture (game code → ECE interpreter → SBCL/JSCL)
- Add ECE as first dependency with link to https://github.com/anthonyf/ece
- Update Quick Start to match current Makefile targets (remove `test-web`, `test-all`; add `fmt`, `setup`)
- Clean up TODOs.org Phase 1 terminology to reflect ECE migration

## Capabilities

### New Capabilities

_None — documentation-only change._

### Modified Capabilities

_None — no spec-level behavior changes._

## Impact

- `README.org` — full rewrite of tagline, overview, quick start, and dependencies sections
- `TODOs.org` — minor wording updates in Phase 1
