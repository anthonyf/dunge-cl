# Dunge

Dunge is a Common Lisp toolkit for authoring choice-based text adventures in
`.dunge` source files, running them locally, and publishing standalone HTML
builds.

## Play

[The Mysterious Affair at Styles](https://anthonyf.github.io/dunge-cl/styles/)
is published on GitHub Pages.

The authored Styles source lives in [styles/game.dunge](styles/game.dunge) and
[styles/rooms/](styles/rooms/). The standalone HTML builds are not committed:
CI builds the whole Pages site from source on every push and deploys it from
`main`.

[The Dunge Crawler Testbed](https://anthonyf.github.io/dunge-cl/examples/adaptation/)
is a smaller browser demo for generated rooms, loot, encounters, inventory, and
save/load pressure on the engine.

## Repository Layout

- [src/](src/) contains the core Dunge model, source loader, runtime, and HTML
  compiler.
- [examples/](examples/) contains small Dunge examples.
- [styles/](styles/) contains the playable Styles adaptation.
- [tests/](tests/) and [styles/tests/](styles/tests/) contain the FiveAM test
  suites.
- [.github/workflows/ci.yml](.github/workflows/ci.yml) runs tests and deploys
  GitHub Pages after successful pushes to `main`.

## Development

Dependencies are managed with [ocicl](https://github.com/ocicl/ocicl) and
pinned in [ocicl.csv](ocicl.csv). One-time setup: install ocicl (`brew install
ocicl` on macOS) and add the snippet printed by `ocicl setup` to `~/.sbclrc`.
That snippet loads the ocicl runtime and lets ASDF find this repository's
systems when SBCL starts in the repository root.

Install the pinned dependencies into `ocicl/`:

```sh
ocicl install
```

Run the test suites:

```sh
sbcl --non-interactive --eval '(asdf:test-system :dunge/tests)'
sbcl --non-interactive --eval '(asdf:test-system :dunge-styles/tests)'
```

The suites include runtime parity tests: each plays the same scripted choices
through the console runtime and through the compiled browser runtime under
[Node.js](https://nodejs.org/) (see [tests/parity/](tests/parity/)), then
compares what each rendered. They use `node` from `PATH`, or the executable
named by `DUNGE_NODE`, and are skipped when neither is available unless
`DUNGE_REQUIRE_NODE=1` is set, as it is in CI.

Build the GitHub Pages site locally into `public/` (it needs Node for the
final boot check):

```sh
sh site/check.sh public
```

The script builds the site twice, the second time after recompiling Dunge with
different Parenscript compiler state, and fails unless both builds are
byte-identical. It then boots each game page under the parity harness. CI runs
the same script and deploys its output.

Enable playtesting controls, including Undo, by binding `dunge:*debug*` for
console play, passing `:debug t` to `dunge:evaluate-session`, or compiling an
HTML build with `:debug t`. Browser builds also accept `?debug=1`, `&debug=1`
when adding to an existing query string, or `#debug`.

## Design Notes

- [AUTHORING.md](AUTHORING.md) describes public `.dunge` authoring
  conventions, including table result shapes for future gameplay systems.
- [ARCHITECTURE.md](ARCHITECTURE.md) describes the current `.dunge` source
  model, AST, runtime, and HTML compiler.
- [DESIGN.md](DESIGN.md) captures broader game-design ideas and future
  direction.
