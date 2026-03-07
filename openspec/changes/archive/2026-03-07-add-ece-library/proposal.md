## Why

The dunge project needs access to the `ece` language library (authored by the project maintainer) for use in game content and text processing. Adding it as a qlot git dependency keeps setup simple and lets the maintainer develop ece separately, pulling updates into dunge with `qlot update ece`.

## What Changes

- Add `ece` as a qlot git dependency in `qlfile` using SSH URL (private repo)
- Add `:ece` as a dependency in `dunge.asd` so it loads with the project

## Capabilities

### New Capabilities
- `ece-integration`: Wire the ece library into the project's dependency chain (qlot git source, ASDF)

### Modified Capabilities

_(none)_

## Impact

- **Dependencies**: New qlot git entry for `git@github.com:anthonyf/ece.git`
- **Build**: `qlot install` will need to be re-run; requires SSH access to the private repo
- **ASDF**: `dunge.asd` gains `:ece` dependency
