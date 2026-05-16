## Why

Dunge currently has no declared relationship to ECE at all. The Makefile, tests, and web build all assume `ece` and `ece-build` happen to be on `$PATH` from a global `make install` in a separate checkout (`~/git/ece/`). CI independently `git clone`s ECE from `main` and builds it fresh on every run. Consequences:

- **No version of record.** Nothing in the Dunge repo identifies which ECE commit any given Dunge commit was built against. `git bisect` cannot cross the ECE boundary.
- **Silent drift.** A breaking change upstream in `ece@main` will break Dunge CI with no local warning, because locally you're on a different (older) ECE install.
- **"Works on my machine" risk.** If the global `~/.local/bin/ece` diverges from what CI sees, local `make test` can pass while CI fails (or vice versa), with no obvious cause.
- **Reproducibility is lost.** Checking out an old Dunge commit and running `make test` uses today's ECE, not the ECE that commit was written against.
- **Leftover stale docs and scripts.** `README.org` still describes JSCL/SBCL/qlot as dependencies and lists Makefile targets that no longer exist. `.dir-locals.el` contains a dead CL indent rule. `setup-vps.sh` installs quicklisp+qlot for a `qlot install` step in Dunge that is now a no-op. CI workflows install SBCL+qlot+ECE from source on every run with no caching or pinning.

## What Changes

- **Vendor ECE as a git submodule at `vendor/ece/`**, pinned to a specific commit. The submodule pointer becomes the single source of truth for "which ECE version does Dunge build against."
- **Dunge's Makefile builds and invokes ECE from the submodule**, not from `$PATH`. `make ece` explicitly builds the submodule (delegating to ECE's own Makefile). `make run`, `make test`, `make build` depend on the in-tree `vendor/ece/bin/ece` and trigger `make ece` as a prerequisite if it's missing.
- **`scripts/build-web.sh` honors an `ECE_BIN` environment variable** so the Makefile can pass the submodule binary through without polluting `$PATH`. Falls back to PATH lookup for standalone use.
- **CI workflows use the submodule, not inline `git clone`**, with `actions/cache` keyed on the submodule pointer SHA so most runs reuse a prebuilt ECE and only rebuild when the pin is bumped.
- **Delete `setup-vps.sh`** — it's unreferenced, its `qlot install` step in the Dunge repo is a no-op, and a new VPS can just clone Dunge and run `make test`.
- **Rewrite `README.org`** to match the pure-ECE, submodule-based reality (dependencies, quick start, `make ece` target, `--recurse-submodules` clone note).
- **Remove the dead CL indent rule from `.dir-locals.el`** (the `make-room` DSL form no longer exists).
- **Document the ECE-bump workflow in development notes** so future sessions know how to update the ECE pin intentionally.

## Capabilities

### New Capabilities

- `ece-toolchain`: ECE is vendored as a git submodule at `vendor/ece/` and built in-place via `make ece`. Dunge's Makefile, tests, web build, and CI all invoke the in-tree binary, never a globally-installed `ece`. The submodule pointer is the single source of truth for the ECE version across local dev, CI, and historical checkouts.

### Modified Capabilities

- `ece-web-build`: The "CI workflows use ECE" requirement is replaced. CI now checks out the submodule, uses `actions/cache` on the submodule SHA, and invokes `make build` / `make test` instead of running `ece tests/run-all.scm` / `scripts/build-web.sh` directly.

## Impact

- **BREAKING for local dev workflow:** Contributors must clone with `--recurse-submodules` (or run `git submodule update --init` after clone). `make test` on a fresh clone will build ECE on first run (slow), then subsequent runs use the cached binary.
- **BREAKING for ECE update workflow:** Updating ECE in Dunge now means `cd vendor/ece && git fetch && git checkout <sha> && cd ../.. && make ece && make test && git commit vendor/ece`. The global `~/.local/bin/ece` no longer affects Dunge builds.
- **Reproducibility:** Any historical Dunge commit can be rebuilt with its exact ECE version via `git checkout <sha> && git submodule update && make test`.
- **CI:** Most runs skip ECE rebuild via cache. ECE version bumps in Dunge trigger a single rebuild+cache-population run, then subsequent PRs are fast again.
- **Deleted files:** `setup-vps.sh`, the dead indent rule from `.dir-locals.el`.
- **Rewritten files:** `README.org`, `Makefile`, `scripts/build-web.sh`, `.github/workflows/ci.yml`, `.github/workflows/deploy.yml`, development notes (ECE-bump section added).
- **New files:** `.gitmodules`, `vendor/ece/` (submodule).
