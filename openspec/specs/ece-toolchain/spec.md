## ADDED Requirements

### Requirement: ECE is vendored as a git submodule

ECE SHALL be vendored in the Dunge repository as a git submodule located at `vendor/ece/`, pinned to a specific upstream commit. The submodule pointer SHALL be the single source of truth for the ECE version that any given Dunge commit is built against — across local development, CI, and historical checkouts. Dunge SHALL NOT invoke a globally-installed `ece` or `ece-build` binary for any of its build, test, or web-export steps.

#### Scenario: Submodule present and pinned
- **WHEN** a user runs `git submodule status` in the Dunge repository
- **THEN** `vendor/ece` SHALL appear with a specific commit SHA pinned, and `.gitmodules` SHALL declare the ECE repository URL and the `vendor/ece` path

#### Scenario: Historical reproducibility
- **WHEN** a user checks out a historical Dunge commit and runs `git submodule update --init` followed by `make test`
- **THEN** the build SHALL use the exact ECE commit that was pinned at that Dunge commit, not whatever ECE is installed on the host system

#### Scenario: No global ECE dependency at build time
- **WHEN** `ece` and `ece-build` are not present anywhere on `$PATH`
- **THEN** `make run`, `make test`, and `make build` SHALL still succeed (assuming the submodule is initialized and buildable)

### Requirement: Makefile builds and invokes ECE from the submodule

The Dunge `Makefile` SHALL build ECE in-place inside `vendor/ece/` and invoke the resulting `vendor/ece/bin/ece` and `vendor/ece/bin/ece-build` binaries by absolute path. A `make ece` target SHALL exist to explicitly build the submodule by delegating to ECE's own Makefile (`$(MAKE) -C vendor/ece`). The `run`, `test`, and `build` targets SHALL depend on the in-tree ECE binary existing, and SHALL trigger the build automatically on first use.

#### Scenario: make ece builds the submodule
- **WHEN** a user runs `make ece` with the submodule initialized
- **THEN** the recipe SHALL invoke `$(MAKE) -C vendor/ece`, resulting in `vendor/ece/bin/ece` and `vendor/ece/bin/ece-build` existing as executable binaries

#### Scenario: First make test triggers build
- **WHEN** a user runs `make test` on a clean submodule (no `vendor/ece/bin/ece`)
- **THEN** Make SHALL first build the submodule, then run `vendor/ece/bin/ece tests/run-all.scm`

#### Scenario: Subsequent make test skips build
- **WHEN** a user runs `make test` and `vendor/ece/bin/ece` already exists from a prior build
- **THEN** Make SHALL NOT re-run the ECE build and SHALL invoke the existing binary directly

#### Scenario: Uninitialized submodule produces a clear error
- **WHEN** a user runs `make ece`, `make test`, `make run`, or `make build` with `vendor/ece/` empty (submodule not yet initialized)
- **THEN** the Makefile SHALL print an error message naming the exact remediation command (`git submodule update --init`) and exit non-zero without attempting the build

#### Scenario: make build invokes the submodule's ece-build
- **WHEN** a user runs `make build`
- **THEN** the Makefile SHALL pass `ECE_BIN=vendor/ece/bin/ece-build` to `scripts/build-web.sh` and the script SHALL use that binary to produce `dist/`

### Requirement: build-web.sh honors ECE_BIN

`scripts/build-web.sh` SHALL read the `ECE_BIN` environment variable to locate the `ece-build` binary, falling back to `ece-build` on `$PATH` if `ECE_BIN` is unset. This preserves standalone-script usability (running the script directly with a system-installed ECE) while letting the Makefile route it at the submodule binary without modifying `$PATH`.

#### Scenario: Makefile passes ECE_BIN
- **WHEN** `make build` invokes `scripts/build-web.sh` with `ECE_BIN` set to `vendor/ece/bin/ece-build`
- **THEN** the script SHALL invoke that exact binary and not search `$PATH`

#### Scenario: Standalone invocation with PATH fallback
- **WHEN** `scripts/build-web.sh` is run directly with `ECE_BIN` unset, and `ece-build` is on `$PATH`
- **THEN** the script SHALL succeed using the PATH-resolved `ece-build`

### Requirement: Test runner locates ece-unit.scm from the submodule

`tests/run-all.scm` SHALL be able to load `ece-unit.scm` from the path named by the `ECE_UNIT_PATH` environment variable when invoked via `make test`, without requiring `ece-unit.scm` to be installed at `~/.local/share/ece/` or any other global location. The Makefile SHALL set `ECE_UNIT_PATH=vendor/ece/src/ece-unit.scm` (the in-tree source location; `share/ece/ece-unit.scm` is only populated by `make install`, which is not run on the submodule).

#### Scenario: Tests run without global install
- **WHEN** `~/.local/share/ece/ece-unit.scm` does not exist but the submodule is built
- **THEN** `make test` SHALL successfully load `ece-unit.scm` via `ECE_UNIT_PATH=vendor/ece/src/ece-unit.scm` and run the test suite

### Requirement: CI uses the submodule with pointer-keyed caching

Both `.github/workflows/ci.yml` and `.github/workflows/deploy.yml` SHALL check out the Dunge repository with `submodules: recursive`, and SHALL use `actions/cache` keyed on the `vendor/ece` submodule commit SHA to cache the built ECE binaries between runs. Cache hit SHALL skip the ECE build step entirely. Cache miss SHALL build ECE from the submodule via `make ece`, populating the cache for subsequent runs. Test and build steps SHALL invoke `make test` and `make build` respectively, not raw `ece` / `ece-build` commands. SBCL, qlot, and binaryen install steps SHALL remain in the workflows (required for cache-miss builds) but SHALL be commented as "required to build the ECE submodule, not Dunge itself."

#### Scenario: Cache hit skips ECE build
- **WHEN** a CI run starts with a cache entry matching the current `vendor/ece` submodule SHA
- **THEN** the workflow SHALL restore `vendor/ece/bin/` and `vendor/ece/share/` from cache, and the subsequent `make test` / `make build` SHALL not rebuild ECE

#### Scenario: Cache miss builds and populates
- **WHEN** a CI run starts with no matching cache entry (e.g. after a submodule pin bump)
- **THEN** the workflow SHALL build ECE from the submodule (`make ece` or equivalent), run tests and build, and populate the cache for future runs keyed on the new submodule SHA

#### Scenario: Submodule is checked out
- **WHEN** the `actions/checkout@v4` step runs
- **THEN** it SHALL use `submodules: recursive` so `vendor/ece/` contains the pinned ECE source before any subsequent step runs

### Requirement: Post-migration stale files are removed

The following files SHALL be deleted or updated to reflect the post-migration, submodule-based reality: `setup-vps.sh` (unreferenced VPS bootstrap from the CL era), the `make-room` Common Lisp indent rule in `.dir-locals.el` (DSL form no longer exists), and any README/docs references to JSCL, `vendor/jscl/`, `make fmt`, `make setup`, ASDF cache cleanup, or "ECE interpreter implemented in Common Lisp."

#### Scenario: setup-vps.sh is deleted
- **WHEN** the change is complete
- **THEN** `setup-vps.sh` SHALL NOT exist in the repository

#### Scenario: .dir-locals.el has no CL indent rule
- **WHEN** the change is complete
- **THEN** `.dir-locals.el` SHALL NOT contain a `common-lisp-indent-function` entry for `make-room` (the form no longer exists); if the file contains no other rules, it SHALL be deleted

#### Scenario: README matches the pure-ECE submodule model
- **WHEN** a user reads `README.org` after the change
- **THEN** the Dependencies section SHALL list ECE (via submodule) and its build-time requirements (SBCL, qlot, binaryen) rather than describing ECE as "implemented in Common Lisp" or listing JSCL as a vendored dependency; the Quick Start section SHALL show `git clone --recurse-submodules` and document `make ece`; the Makefile target list SHALL NOT include `make fmt` or `make setup`

### Requirement: CLAUDE.md documents the ECE-bump workflow

`CLAUDE.md` SHALL document how to bump the vendored ECE version so future Claude sessions update the pin intentionally rather than editing a separate ECE checkout. The documentation SHALL include: (a) the exact sequence of commands to checkout a new ECE commit in `vendor/ece/`, rebuild via `make ece`, run tests, and commit the pointer bump; (b) a rule forbidding global `ece` installation as a substitute for updating the submodule.

#### Scenario: ECE-bump section exists
- **WHEN** a reader searches `CLAUDE.md` for "bump" or "ECE version"
- **THEN** there SHALL be a subsection describing the `cd vendor/ece → git fetch → git checkout <sha> → cd ../.. → make ece → make test → git add vendor/ece → git commit` flow
