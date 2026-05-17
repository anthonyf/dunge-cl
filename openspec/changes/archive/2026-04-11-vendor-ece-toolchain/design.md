## Context

Dunge's game code has been 100% pure ECE since PR #33. The Makefile, tests, and web build all call `ece` / `ece-build` from `$PATH`, assuming the user has run `make install` in a separate `~/git/ece/` checkout. CI independently `git clone`s ECE `main` on every run.

This arrangement is fragile in three ways:

1. **No pin.** Nothing in Dunge declares which ECE commit any given Dunge commit is compatible with. An upstream breaking change lands, CI breaks, and the only way to recover is to debug ECE's recent commits — Dunge's git history gives no clue which version used to work.
2. **Local/CI drift.** The user's `~/.local/bin/ece` and CI's fresh clone can easily diverge. Local tests can pass while CI fails with no code changes in Dunge.
3. **No reproducibility.** `git checkout` an old Dunge commit and `make test` runs against today's ECE, not the one the commit was written against.

ECE does not publish prebuilt binaries or release artifacts (verified via upstream README and GitHub releases page — "There aren't any releases here"). Building ECE requires SBCL + qlot + binaryen; once built, the resulting `bin/ece` is a self-contained ~64MB SBCL image with no runtime CL dependency.

## Goals / Non-Goals

**Goals:**
- A single source of truth for "which ECE version does Dunge build against," visible in Dunge's git history
- Local dev and CI build and invoke the same ECE binary by construction
- Reproducible builds at any historical Dunge commit
- CI caches the built ECE binary so most runs don't rebuild
- Clean up stale CL-era docs, config, and scripts that survived PR #33

**Non-Goals:**
- Publishing prebuilt ECE binaries upstream (a separate ECE-repo concern)
- Forcing the user to abandon their `~/git/ece/` experimental workspace
- Removing SBCL/qlot as a build-time requirement entirely — impossible until ECE ships prebuilts
- Vendoring ECE as source (copying files in); we want it as a pinned submodule so upstream changes flow through `git pull` in the submodule
- Any change to game code, tests, or runtime behavior

## Decisions

### 1. Submodule, not workflow env var or source vendoring

**Alternatives considered:**

- **Env var pin (`ECE_REF: <sha>` in CI YAML):** Smallest change, but creates two sources of truth (`ci.yml` and `deploy.yml`) with no enforcement that they agree, and no local visibility. Review of an ECE bump is a hash diff with zero context.
- **Vendor ECE source as a copy inside Dunge's repo:** Pollutes Dunge's git history with ECE commits, fights `git pull` ergonomics, makes "what changed upstream" hard to answer.
- **Git submodule at `vendor/ece/`:** Git-native, one-line pointer, atomic bumps, `cd vendor/ece && git log old..new` shows exactly what upstream changed between pins.

**Chosen:** submodule at `vendor/ece/`. The usual submodule foot guns (recursive trees, frequent churn, clone-without-recurse confusion) don't apply: ECE is a single flat repo, updated deliberately and infrequently, and the Makefile refuses to build with a clear error if the submodule is uninitialized.

### 2. Build ECE in-tree; don't `make install` globally

ECE's Makefile produces `bin/ece` and `share/ece/` inside its own tree via plain `make` (without `make install`). Dunge can invoke that binary by absolute path without touching `$PATH` or any system install prefix. This means:

- Local `~/.local/bin/ece` continues to exist for the user's other experiments; Dunge's build ignores it completely.
- No sudo, no `PREFIX` negotiation, no "did you remember to put `~/.local/bin` on your PATH".
- CI has no install step — just build the submodule and call the in-tree binary.

### 3. `make ece` as an explicit target, and as a prerequisite of the main targets

```make
ECE_DIR   := $(CURDIR)/vendor/ece
ECE       := $(ECE_DIR)/bin/ece
ECE_BUILD := $(ECE_DIR)/bin/ece-build

.PHONY: run test build clean ece

ece: $(ECE)

run: $(ECE)
	$(ECE) game/main.scm

test: $(ECE)
	$(ECE) tests/run-all.scm

build: $(ECE) $(ECE_BUILD)
	ECE_BIN=$(ECE_BUILD) scripts/build-web.sh

$(ECE) $(ECE_BUILD):
	@test -f $(ECE_DIR)/Makefile || { \
	  echo >&2 "ERROR: vendor/ece submodule is not initialized."; \
	  echo >&2 "Run: git submodule update --init"; \
	  exit 1; }
	$(MAKE) -C $(ECE_DIR)
```

The file-existence prerequisites mean first-time builds trigger the ECE build automatically, but subsequent builds skip it (Make sees the binary exists). Explicit `make ece` lets a user force a rebuild after bumping the pin without having to know about `$(MAKE) -C vendor/ece`.

**Rebuild after submodule bump:** `make -C vendor/ece` is incremental and should detect ECE source changes correctly. If it doesn't, `make -C vendor/ece clean && make ece` is the escape hatch. We do *not* add complex submodule-SHA dependency tracking in the Makefile — ECE's own build system is the source of truth for what's out of date inside the submodule.

### 4. `ECE_BIN` env var for `scripts/build-web.sh`

Today `build-web.sh` calls `ece-build` by name. The Makefile needs to pass the submodule path through without modifying `$PATH` globally. Cleanest approach: the script reads `ECE_BIN` (the path to `ece-build`) with a fallback to `ece-build` on PATH. Makefile sets `ECE_BIN=$(ECE_BUILD) scripts/build-web.sh`.

This also means the script still works for anyone running it directly with a system-installed `ece-build`, preserving the standalone-script contract.

### 5. CI caches on the submodule pointer SHA

GitHub Actions `actions/cache` key:

```yaml
- uses: actions/checkout@v4
  with:
    submodules: recursive

- name: Compute ECE submodule SHA
  id: ece-sha
  run: echo "sha=$(git -C vendor/ece rev-parse HEAD)" >> $GITHUB_OUTPUT

- name: Cache built ECE
  uses: actions/cache@v4
  with:
    path: |
      vendor/ece/bin
      vendor/ece/share
      vendor/ece/.qlot
      vendor/ece/.fasl-cache
    key: ece-${{ runner.os }}-${{ steps.ece-sha.outputs.sha }}
```

Cache hit → `make test` just runs the existing binary. Cache miss (first build of a new pin) → `make ece` triggers, then the cache is populated for subsequent runs.

SBCL + qlot + binaryen still have to be installed on every run because they're needed when the cache misses, but the SBCL+qlot *work* (downloading Quicklisp archives, compiling FASLs, building the ECE image) only happens on a pin bump.

### 6. Clean up CL-era stragglers in the same change

The stale docs and scripts are conceptually separate from the submodule work but trivially tied to it: they describe the "ECE lives globally on PATH" world that this change replaces, and a separate cleanup PR would have to re-explain the whole migration context. Bundling keeps the "post-migration cleanup" story in one reviewable unit.

Specifically:
- `README.org` — rewrite dependency list, quick start, and remove references to `make fmt`, `make setup`, JSCL, qlot, `vendor/jscl/`, "ECE interpreter implemented in Common Lisp"
- `.dir-locals.el` — the `make-room` indent rule is dead code; the file itself becomes empty and can be deleted
- `setup-vps.sh` — delete entirely; a new VPS can just `apt install sbcl`, clone Dunge, and `make test`
- Development notes — add a short section on bumping the ECE pin so future coding-agent sessions don't try to update it by editing `~/git/ece/`

## Risks / Trade-offs

**[First-build-is-slow]** — A fresh clone's first `make test` builds ECE from scratch (SBCL + qlot + compile), which is minutes not seconds. Mitigated by one-time nature: subsequent builds are instant. Newcomers will notice; documented in README.

**[SBCL+qlot local requirement]** — Local dev now requires SBCL and qlot installed (to build the submodule), not just to have done it once elsewhere. In practice, the only person likely to work on Dunge locally already has these for other reasons. Documented in README.

**[Submodule onboarding friction]** — `git clone` without `--recurse-submodules` leaves `vendor/ece/` empty and `make test` errors out. Mitigated by:
(a) clear error message in the Makefile pointing at the exact command to run,
(b) README quick-start line showing `--recurse-submodules`,
(c) CI checkouts always use `submodules: recursive`.

**[Cache-key collisions or stale hits]** — Cache is keyed on ECE submodule SHA and OS. If ECE's Makefile output ever depends on something outside those inputs (host libc version, etc.), a cache hit could ship a subtly broken binary. Mitigated by: (a) cache key also includes `runner.os`, (b) worst case is manual cache bust via key change in the workflow. Not blocking.

**[Bumping ECE is now a two-step ritual]** — `cd vendor/ece && git checkout <sha> && cd ../.. && make ece && git add vendor/ece && git commit`. Previously the user could `make install` in `~/git/ece/` and have it take effect silently. The new flow is strictly more work, but it produces a reviewable commit and is the whole point of the change. Documented in the development notes.

**[`vendor/ece/` vs `~/git/ece/` duplication]** — The user keeps two ECE checkouts on their machine. Minor disk cost. They could collapse by using `vendor/ece/` as their iteration workspace and deleting `~/git/ece/`, but there's no pressure to — the two-workspace model is fine.

## Open Questions

- **Initial pin:** which ECE commit should the first `vendor/ece/` submodule pointer be? Probably whatever commit the user currently has installed locally (so the first build matches today's behavior). Verify during implementation by running `ece --version` or `git -C ~/git/ece rev-parse HEAD`.
- **Cache eviction:** GitHub Actions cache has a 10GB repo limit and evicts LRU. If ECE pin churns a lot, old caches will roll off and occasional PRs will hit the slow path. Not worrying about this until it becomes a problem.
- **Do we also want a `make ece-clean` target?** Probably yes — forwards to `make -C vendor/ece clean`. Cheap to add. Deciding during implementation.
