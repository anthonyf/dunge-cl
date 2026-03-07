## Context

The project uses qlot for dependency management. The `ece` library is a private repo maintained by the project author on GitHub at `anthonyf/ece`. It needs to be available as an ASDF system for the dunge project to depend on. The maintainer develops ece separately and will pull updates into dunge via `qlot update ece`.

Current dependency chain: `qlfile` → qlot → ASDF → `dunge.asd` `:depends-on`. The project currently depends on `uiop` and `alexandria`.

## Goals / Non-Goals

**Goals:**
- Register ece as a qlot git dependency using SSH URL
- Add `:ece` to the project's ASDF dependencies

**Non-Goals:**
- Vendoring ece as a git submodule (rejected — adds friction for active co-development)
- Integrating ece into game content (separate change)
- Pinning to a specific ece version/tag (use latest main branch)

## Decisions

1. **Use qlot `git` source type with SSH URL** — the `github` source type uses the GitHub API which doesn't support private repos. The `git` source type with `git@github.com:anthonyf/ece.git` delegates to the system's git and inherits SSH key auth.

2. **No submodule** — ece is actively developed alongside dunge. A submodule would require commit-push-update cycles on every change. Qlot git source lets the maintainer develop ece in its own checkout and pull updates with `qlot update ece`.

3. **Add as ASDF `:depends-on` in `dunge.asd`** — ensures the ece system is loaded before dunge's own files.

## Risks / Trade-offs

- **SSH key required**: Anyone building the project needs SSH access to the private ece repo. → Mitigation: This is a solo project; if collaborators are added later, ece can be made public or added to Ultralisp.

- **No version pinning**: Using latest main means ece changes could break dunge. → Mitigation: `qlot.lock` pins the exact commit; updates are explicit via `qlot update ece`.
