---
name: play
description: Launch the Dunge text adventure REPL game
disable-model-invocation: true
---

Launch the Dunge text adventure game in the terminal.

Run this in SBCL via qlot:

```bash
qlot exec sbcl --eval '(asdf:load-system :dunge)' --eval '(in-package :dunge-user)' --eval '(game-repl (room (quote dunge::start)))'
```

Use the Bash tool to execute this command. The game is interactive,
so the user will play in their terminal.
