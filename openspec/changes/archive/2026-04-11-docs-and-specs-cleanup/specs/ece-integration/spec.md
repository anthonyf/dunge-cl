## REMOVED Requirements

### Requirement: Ece is registered as a qlot git dependency
**Reason**: The `qlfile` was deleted in PR #33 (2026-04-10 drop-cl-pure-ece) along with the rest of the Common Lisp / ASDF toolchain. Dunge no longer uses qlot to obtain ECE — ECE is vendored as a git submodule at `vendor/ece/` and built in-place. The replacement behavior is owned by `ece-toolchain` ("ECE is vendored as a git submodule") and `ece-cli-runner` ("Game runs via ece CLI").

**Migration**: Readers looking for how Dunge acquires ECE should consult `openspec/specs/ece-toolchain/spec.md`. The file `qlfile` does not exist in the repository.

### Requirement: Dunge ASDF system depends on ece
**Reason**: The `dunge.asd` system definition was deleted in PR #33. Dunge no longer has an ASDF system — game code is pure ECE (Scheme), loaded via `ece game/main.scm`. There is no CL-side loading step.

**Migration**: Readers looking for how the game is loaded should consult `openspec/specs/ece-cli-runner/spec.md`. The file `dunge.asd` does not exist in the repository.
