## MODIFIED Requirements

### Requirement: Build produces standalone HTML file
The build process SHALL produce a single `dist/index.html` file that contains all JavaScript (JSCL runtime + compiled game) inlined. Opening this file in a browser SHALL start the game with no server required. The line-based filter that generates JSCL-compatible ECE source SHALL correctly handle CL character literals (`#\X`) so that `#\"`, `#\(`, `#\)`, and `#\;` do not corrupt the parenthesis depth counter.

#### Scenario: Build and open
- **WHEN** `sbcl --load web-export.lisp` is run
- **THEN** `dist/index.html` SHALL be produced and opening it in a browser SHALL display the game start screen

#### Scenario: Character literals in eval-when block
- **WHEN** ECE source contains `#\"` or other character literals inside an `eval-when` block
- **THEN** the filter SHALL correctly skip the entire `eval-when` block without leaving orphaned code in the output
