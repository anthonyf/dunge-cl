## Context

Documentation-only change. No architectural decisions needed.

## Goals / Non-Goals

**Goals:**
- Accurately describe the project's technology stack with ECE front and center
- Keep all existing dependency mentions (JSCL, Qlot, Playwright, SBCL, Make)
- Match Quick Start to current Makefile targets

**Non-Goals:**
- Restructuring the README format
- Rewriting DESIGN.md or development-agent guidance
- Adding new documentation files

## Decisions

**ECE as first dependency**: ECE is the core technology — game code is written in it. List it first with a brief description and link.

**Keep architecture description concise**: One sentence about the layered stack (ECE → CL → SBCL/JSCL) rather than a full diagram. The README should be scannable.

**TODOs.org minimal touch**: Only update Phase 1 checked items to reflect ECE terminology. Don't reorganize or reprioritize — the roadmap items are still valid.

## Risks / Trade-offs

_None — documentation only._
