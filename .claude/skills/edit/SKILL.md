---
name: edit
description: Open a file in Emacs GUI
disable-model-invocation: true
---

Open a file in the Emacs GUI editor.

The argument is a file path. Use the Bash tool to run:

```bash
emacsclient -c -n -a "" <file-path>
```

If no file path is provided, ask the user which file they want to edit.
