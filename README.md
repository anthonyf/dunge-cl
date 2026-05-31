# Dunge

Dunge is a Common Lisp toolkit for authoring choice-based text adventures in
`.dunge` source files, running them locally, and publishing standalone HTML
builds.

## Play

[The Mysterious Affair at Styles](https://anthonyf.github.io/dunge-cl/styles/)
is published on GitHub Pages.

The authored Styles source lives in [styles/game.dunge](styles/game.dunge) and
[styles/rooms/](styles/rooms/). The committed standalone HTML build lives at
[styles/index.html](styles/index.html), and the Pages deploy copies it to
`/styles/`.

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

Install dependencies:

```sh
qlot install
```

Run the test suites:

```sh
qlot exec sbcl --non-interactive --eval '(asdf:test-system :dunge/tests)'
qlot exec sbcl --non-interactive --eval '(asdf:test-system :dunge-styles/tests)'
```

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
