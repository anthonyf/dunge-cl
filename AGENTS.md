# Dunge Agent Notes

This file is for coding agents working in this repository. Keep durable
project documentation in the README or `docs/`; keep this file short.

## Read First

- [README.org](README.org) - project overview, setup, commands, dependencies
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) - architecture, workflow, ECE gotchas
- [DESIGN.md](DESIGN.md) - game mechanics and design reference
- [STORY.md](STORY.md) - story, setting, progression, endings
- [TODOs.org](TODOs.org) - current phase checklist

## Commands

Use the Makefile so Dunge uses the vendored ECE toolchain in `vendor/ece/`.

```bash
make ece       # build the vendored ECE toolchain and web dev assets
make run       # terminal game
make test      # ECE unit/integration tests
make build     # standalone web build in dist/
make serve     # live browser dev server on http://127.0.0.1:8080
make clean     # remove dist/
```

After code changes, run both `make test` and `make build`. Use
`npm run test:web` when browser behavior changed and Playwright is available.

## Core Conventions

- All app code is ECE Scheme in `game/*.scm` plus `browser-boot.scm`.
- Common Lisp belongs only inside the vendored `vendor/ece/` submodule.
- Do not invoke a globally installed `ece` or `ece-build`; use `make`.
- `game/main.scm` is the terminal entrypoint.
- `web/main.scm` is the `ece-serve` entrypoint and loads `browser-boot.scm`.
- `browser-boot.scm` is loaded by the web build, `web/main.scm`, and tests.
- Scheme booleans are `#t` and `#f`, not `t` or `nil`.
- Room/menu navigation is ordinary Scheme procedure calls plus `choose`.
- Background equipment uses thunks so each playthrough gets fresh item records.
- Prefer `fmt` or ECE string interpolation for mixed-type strings.

## Safety Notes

- Keep browser-only FFI guarded so CLI tests can load browser boot code.
- Do not use `parameterize` for output capture across `call/cc`; see
  `tests/run-all.scm` for the mutable-buffer pattern.
- When adding game files, wire them into the terminal load path, test runner,
  and web build as appropriate.
- Avoid writing `.scm` files with zsh heredocs containing `!`; history
  expansion can corrupt symbols such as `js-set!`. Use an editor or patch tool.
- Leave unrelated user changes alone.
