## MODIFIED Requirements

### Requirement: CI workflows use ECE

Both `.github/workflows/ci.yml` and `deploy.yml` SHALL obtain ECE from the `vendor/ece` git submodule instead of inline `git clone` + `make install`. Workflows SHALL check out the repository with `submodules: recursive`, cache the built ECE binaries via `actions/cache` keyed on the submodule commit SHA, and invoke `make test` / `make build` (which in turn use the submodule-built binaries) rather than calling `ece` / `ece-build` directly. SBCL, qlot, and binaryen install steps remain in the workflows because they are required when the cache misses and the submodule must be rebuilt, but the workflow SHALL annotate them as existing for the ECE submodule build, not for Dunge itself.

#### Scenario: CI uses the submodule
- **WHEN** a CI workflow runs
- **THEN** it SHALL check out the Dunge repository with `submodules: recursive` so `vendor/ece/` contains the pinned ECE source, and it SHALL NOT perform an inline `git clone https://github.com/anthonyf/ece.git` step

#### Scenario: CI caches built ECE between runs
- **WHEN** a CI workflow runs and the cache contains an entry matching the current `vendor/ece` submodule SHA
- **THEN** the workflow SHALL restore the cached `vendor/ece/bin/` and `vendor/ece/share/` directories and skip the ECE build step

#### Scenario: Deploy workflow builds with ECE
- **WHEN** a push to main triggers the deploy workflow
- **THEN** it SHALL run `make test`, run `make build` (with `COMMIT_SHA` / `BUILD_TIME` env vars passed through to `scripts/build-web.sh`), and deploy `dist/` to gh-pages
