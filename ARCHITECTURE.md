# Dunge Language Architecture

This note records the core design decisions for Dunge's authored story
language. The goal is to keep Dunge small while making non-trivial choice-based
interactive fiction possible.

## Core Principle

Dunge game source is `.dunge` data. Authored files are read as s-expressions
with `*read-eval*` disabled, checked against an explicit source schema, and
compiled into internal CLOS AST objects. Authored files are not Common Lisp
programs and are never passed through `eval` or `load`.

The CLOS AST remains the runtime semantic model. It is the thing interpreted by
the console runtime, validated by the validator, and eventually compiled by
other backends. The AST is not the public source format, and `.dunge` files are
not raw serialized CLOS objects.

The pipeline is:

```text
.dunge source
  -> safe read as data
  -> source-schema field compilation
  -> private generated AST builders
  -> prepare and validate rooms locally
  -> prepare and validate the game
  -> evaluate
```

This gives Dunge one authoring language and one runtime representation. It also
keeps editor-authored and hand-authored files on the same path.

## Content vs Procedure

Dunge keeps a hard boundary between authored content and engine procedure:

```text
.dunge describes what exists, what it means, and when it is eligible.
Common Lisp implements how systems resolve, generate, mutate, and save state.
```

In practice, `.dunge` is the place for rooms, entities, choices, tables, future
actors, items, NPC beats, shops, encounters, room templates, and generated-site
ingredients. Common Lisp is the place for algorithms: combat resolution, random
table selection, dungeon graph generation, inventory rules, shop transactions,
morale, seeding, logging, and save/load mechanics.

This boundary is a design constraint, not just an implementation detail. New
language features should remain declarative data that compile through the
source schema. If a feature needs loops, graph construction, complex search, or
mutation strategy, it belongs in Common Lisp and should be selected or
configured from `.dunge` by id, tags, fields, or tables.

## Source Schema

AST classes are declared internally with `define-dunge-node`. Each node
definition may also register a public `.dunge` source form:

```lisp
(define-dunge-node container ()
  ((name :reader name :initarg :name :initform nil)
   (description :reader description :initarg :description :initform nil)
   (open-choice :reader open-choice :initarg :open-choice :initform nil)
   (close-choice :reader close-choice :initarg :close-choice :initform nil)
   (contents :accessor contents :initarg :contents :initform nil))
  (:children (thing) (contents thing))
  (:source :container
   (:fields
    (:name :string :required t)
    (:description :string)
    (:open :string :to :open-choice)
    (:close :string :to :close-choice)
    (:contents :node-list :default nil))))
```

The schema declares:

- which source tags are allowed;
- which fields are allowed;
- which fields are required;
- how source fields map to internal initargs;
- which values are raw data and which are recursively compiled source forms.

Field kinds such as `:string`, `:scene-id`, `:node-list`, `:condition`,
`:effect`, and `:state-reference` are source value compilers. They are not CLOS
classes. For example, `:node-list` means "compile each source form in this list
into an AST node."

Only registered source tags and field kinds are valid. Unknown tags, unknown
fields, duplicate fields, missing required fields, and malformed values are
hard errors.

Every node has one canonical keyword-field spelling, checked by its schema, such
as `(:go :room "hallway")` or `(:choice :label "Leave" :do (:quit))`. Shorthands
are registered with `define-dunge-shorthand` and rewrite a form into canonical
source before the schema sees it, so `(:go "hallway")` and
`(:choice "Leave" (:quit))` compile to the same nodes. A shorthand either has
its own tag, such as `:mark` or `:when`, or shares a node's tag and rewrites only
the positional spelling, leaving the keyword-field spelling to the schema. The
registered shorthands are `:p`, `:say`, `:go`, `:gosub`, `:not`, `:and`, `:or`,
`:choice`, `:once`, `:when`, `:global`, `:self`, `:ref`, `:marked?`, `:mark`, and
`:unmark`.

Source diagnostics preserve file and schema context while forms are compiled.
For split games, an error in a referenced room file reports the room file first
and then the manifest field that included it. Diagnostics intentionally track
source form and field paths rather than exact line and column positions.

## Source Example

A small game is written as data:

```lisp
(:game
 :start "kitchen"
 :flags (:recipe)
 :rooms
 ((:room
   :id "kitchen"
   :title "Kitchen"
   :body
   ((:p "It's a kitchen. A pot sits on the stove.")
    (:branch
     :when (:marked? :recipe)
     :then
     ((:choice "Cook stew" (:go "victory")))
     :else
     ((:p "You'd cook, but you don't know what.")))
    (:choice "Search the cupboard" (:gosub "cupboard"))
    (:choice "Leave" (:go "hallway"))))

  (:room
   :id "cupboard"
   :title "Cupboard"
   :body
   ((:p "Old shelves, dust.")
    (:once
     :id :take-recipe
     (:choice
      "Take the recipe card"
      ((:mark :recipe)
       (:back)))))))

  (:room
   :id "hallway"
   :title "Hallway"
   :body
   ((:p "A hallway.")))

  (:room
   :id "victory"
   :title "Victory"
   :body
   ((:p "You cooked. You win.")
    (:choice "Quit" (:quit)))))
```

This source compiles into internal `game`, `room`, `p`, `branch`, `choice`,
`state-ref`, `state-set`, `goto`, and related CLOS objects. Authors do not call
the private builders directly.

Use `:branch` when conditional body content needs an `:else`. For the common
no-else case, `:when` keeps control flow separate from the content it guards:

```lisp
(:when (:marked? :recipe)
  (:p "The recipe card is tucked safely into your notes."))
```

A game can also keep rooms in separate files:

```lisp
(:game
 :start "kitchen"
 :rooms
 ("rooms/kitchen.dunge"
  "rooms/cupboard.dunge"))
```

Room paths are resolved relative to the `.dunge` file that contains them. Each
referenced room file contains exactly one top-level `:room` form, which is read
through the same safe source-schema path as inline room data.

Room files are prepared and validated locally when they are loaded. Local room
validation catches room-internal authoring errors such as duplicate scene IDs,
unresolved entity refs, malformed state references, and once-only choices
without IDs. It deliberately does not reject navigation targets that may be
declared by another room file. Full game validation remains responsible for
game-level constraints such as the start room and `:go`/`:gosub` room targets.

## Internal AST

The AST is a semantic layer, not a second authoring language. Runtime behavior
is implemented with CLOS generic functions over AST classes:

```lisp
(defgeneric evaluate (node &optional context))
(defgeneric describe-entity (node &optional context))
(defgeneric collect-choices (node &optional context))
(defgeneric execute-effect (node &optional context))
(defgeneric evaluate-condition (node &optional context))
(defgeneric validate-node (node game context))
```

Structural passes that need to visit authored children use `node-children` and
`walk-node-tree`. Context-sensitive passes, such as action-owner assignment and
validation, can thread their own context while relying on the same child-access
protocol.

Internal nodes may exist without source tags. For example, `container-view`,
`refresh`, and `fall-through` are runtime machinery and should not leak into
authored `.dunge` files unless they become real authoring concepts.

## Rooms And Choices

Rooms use stable string IDs. A room may also have a display title. Navigation
targets point at room IDs:

```lisp
(:go "hallway")
(:gosub "cupboard")
```

`:gosub` and container views push the current location onto a return stack;
`:back` returns to it. A room with no available choices offers a single
**Continue** choice back to its caller when the return stack is not empty, and
otherwise ends play. `:back` with an empty return stack also ends play. Both
the console and browser runtimes behave this way, and the parity tests check it.

Choices remain the only player interaction primitive. Dunge does not need
Twine-style inline links. Removing links keeps the source schema, AST, renderer,
validator, and future compiler simpler.

Choice visibility is ordinary body control flow, and persistence is data on the
choice:

```lisp
(:when (:not (:marked? :recipe))
 (:once
  :id :take-recipe
  (:choice
   "Take the recipe card"
   ((:mark :recipe)
    (:back)))))
```

Default choices are sticky. A once-only choice is hidden after it is selected.
The runtime records consumed choices in `taken-choices`, keyed by stable choice
IDs. Validation requires explicit IDs for once-only choices.

For choices, the common no-wrapper case can also be written flat:

```lisp
(:choice
 "Take the recipe card"
 ((:mark :recipe)
  (:back))
 :when (:not (:marked? :recipe))
 :once t
 :id :take-recipe)
```

Internally, this uses the shared availability protocol. Nodes that opt into that
protocol can expose `:when` conditions, stable ids, one-time consumption, tags,
or priority where those concepts have clear semantics. Dunge should not add
`:once` to every node by default; it is only appropriate when the runtime has a
well-defined consumption event, such as selecting a choice, drawing a unique
table entry, or eventually completing a beat.

## Random Tables

Random tables are first-class game content. They are authored in `.dunge`,
validated with the rest of the game, indexed by keyword id, and resolved by
Common Lisp at runtime.

```lisp
(:game
 :start "kitchen"
 :seed 12345
 :tables
 ((:table
   :id :cupboard-loot
   :mode :weighted
   :entries
   ((:table-entry :weight 3 :result (:gold "1d6"))
    (:table-entry :weight 1
     :when (:marked? :knows-secret-shelf)
     :tags (:loot :rare)
     :result (:item :silver-ring)))))
 :rooms ...)
```

Supported table modes are:

- `:weighted` chooses one available entry by positive integer weight.
- `:roll` maps a random roll onto non-overlapping entry ranges.
- `:deck` draws available entries without replacement, then reshuffles.
- `:sequence` returns entries in order and repeats the final entry.
- `:first-match` returns the first available entry.
- `:bundle` resolves all available entries and returns the list of results.

Entries may use `:when` and `:tags`. A result may be arbitrary safe data.
`(:table :nested-table)` is resolved by the table runtime as a nested roll.
Other public result conventions, such as `(:gold "1d6")`,
`(:item :silver-ring)`, `(:encounter :goblin-scouts)`,
`(:shop-stock :blacksmith-basic)`, and `(:room-detail :flooded-floor)`, are
documented in [AUTHORING.md](AUTHORING.md). The runtime has a small shared
resolver layer for common result shapes, while later systems such as combat,
shops, and richer dungeon generation will define deeper behavior for their own
result data.

Games may declare an initial `:seed`. The seed is authored data; the Common
Lisp runtime owns the deterministic pseudo-random generator, current RNG state,
and roll log. Table rolls and dice rolls advance the game RNG by default and
append structured roll records. Table records contain the table id, mode,
selected entry, roll details, and resolved result. Dice records contain the dice
expression, individual die results, optional label, and result total.

Stateful table progress, such as sequence position, deck draws, current RNG
state, and the roll log, is part of runtime save/load. This lets future
generated dungeons roll a room, encounter, or loot result once and keep it
stable when the player returns.

## Table Result Resolvers

Table results remain authored data until Common Lisp asks to resolve them. The
resolvers live in the `dunge/crawler` system (package `dunge.crawler`), which
holds the build-time procedures that turn tables into ordinary content. The
shared resolver normalizes the common crawler result shapes:

- `(:gold AMOUNT)` resolves integer or dice-string amounts.
- `(:item ITEM-ID ...)` and `(:supply SUPPLY-ID ...)` resolve `:count` dice
  strings into integer counts.
- `(:encounter ENCOUNTER-ID ...)` resolves optional `:count` dice and can be
  used by CL procedures to start persistent encounter state.
- `(:exit DIRECTION ROOM-ID)` validates and extracts generated-room exits.

`resolve-table-result-data` returns normalized result data without deciding
where it belongs. `table-result-loot-results` extracts gold/item/supply
results, `table-result-exits` extracts room exits, and
`table-result-encounters` extracts encounter results. This keeps the `.dunge`
boundary intact: source files describe what was rolled, and CL procedure code
decides whether that roll becomes a loot choice, an exit, room detail, an
encounter, or something else.

## Generated Rooms

Generated rooms are room instances created by Common Lisp from authored tables
before play. They subclass normal rooms, receive stable generated ids such as
`"generated:dungeon:1"`, and can be found by the same navigation lookup used
for authored rooms once registered with a game. They are part of the game's
definition: preparing a game for a new run keeps them, and saves do not
record them.

`dunge.crawler:create-generated-room` builds a room's body from resolved table
results as ordinary AST:

- a paragraph for the description and one per result, such as `Find: Ration.`;
- a once-only "Take ..." choice for each `:gold`, `:item`, or `:supply` result,
  which adds the loot to `:player` state;
- any extra `:options` choices, such as the crawler's "Eat ration" choice.

`:encounter-options` choices are offered between Attack and Flee while the
room's encounter is active. Exits are still rendered from the room's exit data.

The core API for the room graph is small:

- `register-generated-room` registers a room with an explicit id.
- `find-generated-room` recalls a generated room.
- `game-generated-rooms` returns the generated rooms.
- `generated-room-exit-target` reads the concrete target for a direction.
- `set-generated-room-exit` adds or replaces an exit.
- `link-generated-rooms` links two rooms and can also write the reciprocal exit.

Exits only store concrete room ids, so a generated room can link to authored
rooms or other generated rooms through the same navigation path.

`.dunge` still describes the possible ingredients; CL decides which rooms
exist. For example, the adaptation testbed rolls an authored
`(:exit :deeper "generated:dungeon:*")` table result, then CL creates a
concrete room such as `"generated:dungeon:2"` and links it back to the room that
discovered it. The adaptation loader also rewires the authored
`:enter-first-room` choice to the first generated room's id.

The browser backend does not roll rooms either. The compiler serializes the
generated rooms as `generatedRooms`, and the browser runtime registers them
alongside authored rooms so ordinary `:go` navigation can enter them.

## State

Global state is the first-class primitive for flags, counters, and simple
inventory-like facts. Entity-local state and ref-scope state are also supported
for scene-local mechanisms.

Source state references name a scope and a key. The canonical form spells both
out, and each scope has a shorthand:

```lisp
(:state :scope :global :key :recipe)          ; (:global :recipe)
(:state :scope :self :key :switch)            ; (:self :switch)
(:state :scope :ref :role :door :key :open)   ; (:ref :door :open)
```

`(:marked? :recipe)` is the author-facing predicate for global story flags. It
expands to the same global state reference as `(:global :recipe)`. `:mark` and `:unmark` are the matching
effects:

```lisp
(:mark :recipe)
(:unmark :recipe)
```

State keys, state scopes, entity reference roles, and choice IDs are explicit
keyword data. Dunge does not downcase symbols or strings into state keys. Room
IDs and scene entity IDs are strings and are matched exactly, so state data and
story object names keep separate, predictable representations.

Entity-local and ref-scope state is strictly declared. Reading, writing,
incrementing, clearing, or toggling a key that the target entity did not declare
in `:state` is an error. This catches typos instead of silently creating
phantom slots.

An entity that declares `:state` must also declare an `:id`. Saves key
entity-local state by room ID and entity ID, so a stateful entity without one
would silently lose its state on save and load.

Game-level global state can also be declared:

```lisp
(:game
 :start "kitchen"
 :flags (:recipe)
 :marked (:knows-town-secret)
 :state ((:phase :prologue))
 :rooms ...)
```

When a game declares any global state, every global state read or write must use
one of those declared keys. `:flags` declares initially unmarked story flags,
`:marked` declares initially marked story flags, and `:state` remains available
for non-flag values such as phases or counters. Small experiments may omit
game-level state declarations and continue using unrestricted globals, but
authored mystery content should declare its clue, fact, phase, deduction, and
scoring flags.

## Player State

The player is ordinary state in the `:player` scope. A game declares its keys
and starting values the same way it declares globals:

```lisp
(:game
 :start "town"
 :player ((:name "Mara")
          (:hp 4) (:max-hp 4)
          (:armor 1)
          (:gold 8)
          (:fatigue 0)
          (:deprived nil)
          (:rusted-dagger 1)
          (:ration 3))
 :rooms ...)
```

Content reads and writes it with `(:player KEY)` and `{player:key}`, and every
reference must use a declared key. Each inventory item or supply is a counter
named by its id.

The crawler builds these declarations from its richer inventory data.
`dunge.crawler:player-declarations` turns a character sheet and inventory
entries into counters, declaring every item the tables can award. Inventory
entries follow the table result conventions in [AUTHORING.md](AUTHORING.md):
`(:item ITEM-ID ...)` items cost one slot per copy, or two with `:bulky t`;
`(:supply SUPPLY-ID ...)` stacks cost one slot; `:slots N` overrides either.
`used-slots-expression` turns those rules into an expression over the
counters, with fatigue filling slots too, and `ration-choice-form` builds the
"Eat ration" choice. It is offered when the player has a ration and is hurt,
fatigued, deprived, or at full inventory. Per-stack metadata such as an item's
condition is not kept.

## Encounter State And Combat

Encounter state is runtime data owned by Common Lisp. A `.dunge` table can
describe an encounter with `(:encounter ENCOUNTER-ID ...)`, but that result does
not start combat by itself. CL code chooses the room or generated room that owns
the encounter, applies any enemy profile defaults, and registers an
`encounter-state` with:

- room id;
- enemy id and source result;
- reaction;
- HP/STR current and maximum values;
- armor and damage;
- round count;
- status, one of `:active`, `:defeated`, `:escaped`, or `:player-defeated`.

`ensure-room-encounter-state` creates or recalls a room-bound encounter from a
resolved table result. `attack-encounter` rolls player damage, applies enemy
armor, and lets an active enemy strike back if it survives. `flee-encounter`
marks the encounter escaped. Generated rooms render active encounter choices
before ordinary exits, with available item-use choices such as "Eat ration"
inserted into the combat menu when they can help. Once the encounter is
defeated or escaped, loot and ordinary room exits become available again. A
defeated player ends the run. The browser runtime rolls combat dice from the
same generator as the console, in the same order and with the same labels, so
both runtimes play a fight identically.

Runtime save data includes `:encounters`, and undo captures encounter state
alongside player, table, RNG, and local/global state.

## Effects And Sequences

Choices can target a single effect/control node or a sequence:

```lisp
(:choice
 "Take the recipe card"
 ((:mark :recipe)
  (:back)))
```

List-valued choice effect fields compile to a `sequence` effect/control AST node.
`sequence` is not Lisp `progn`: it executes its children in order and stops when
a child produces a control result from authored forms such as `:go`, `:gosub`,
`:back`, or `:quit`.

## Save And Load

`.dunge` files serialize authored content. Player save files should serialize
runtime state, not executable story code and not the whole authored game.

The minimum save payload is still:

```lisp
(:current-room "cupboard"
 :return-stack ("kitchen")
 :player ((:hp . 4) (:max-hp . 4) (:name . "Mara") (:ration . 3))
 :globals ((:recipe . t))
 :locals ((:room "kitchen"
           :entity "stove"
           :state ((:lit . t))))
 :taken-choices (:take-recipe))
```

Runtime sessions track the current location and return stack separately from
authored content. `capture-runtime-state` produces the serializable payload,
`restore-runtime-state` applies one to a prepared game, and
`write-runtime-state-file` / `load-runtime-state-file` round-trip that payload
through a safe s-expression reader with `*read-eval*` disabled. Entity-local
state is saved for entities with stable scene IDs.

## Validator

Validation is a separate pass over the AST after game construction. It catches
authoring errors before play:

- missing `:go` and `:gosub` room targets when statically known;
- malformed conditions and effects;
- unknown state scopes;
- undeclared global state references when game-level state declarations are present;
- undeclared player state references;
- once-only choices without stable IDs;
- duplicate room IDs and duplicate scene IDs;
- unresolved entity refs;
- entities that declare `:state` without an `:id`.

Dynamic values that cannot be statically resolved should be reported as such
rather than silently accepted as validated.

## HTML Compiler

The `dunge-html` package is the browser backend for the same CLOS AST used by
the console runtime. It lives in the main `dunge` system but has its own package
boundary so the compiler-specific API stays isolated from the source loader and
console evaluator.

The backend emits a single self-contained `index.html` file. Lisp generates the
static document shell, including the app mount points for scene title, scene
body, and choices. Parenscript generates the embedded browser runtime script.
The script owns game state and re-renders those static mount points as the
player selects choices.

The browser runtime keeps player state in the same `:player` scope as the
console, and does not display it as a permanent dashboard. Character
information should be rendered by authored narrative or explicit views when it
is useful. The compiler also serializes current encounter states so generated
rooms can render encounter text and choices in the narrative flow, resolve the
minimal attack/flee loop, and persist combat in local storage.

The generated file does not rely on modules, fetches, or a web server. It is
intended to run directly from `file://` in ordinary browsers. Browser storage,
refresh guards, save-game UI, and story rendering are part of this backend;
generation itself is still driven by Common Lisp before the file is compiled.

The adaptation testbed uses that boundary as a runnable vertical slice.
`dunge-examples:write-adaptation-browser-demo` loads the adaptation, installs
the generated player and two-room generated dungeon graph, rewires the authored
threshold to the first generated room, and writes the
`examples/adaptation/index.html` standalone build.

Builds are reproducible: the runtime script is expanded with `ps:ps-doc`, which
resets Parenscript's gensym counter, so identical sources produce identical
HTML regardless of what the Lisp image compiled first. Browser saves are keyed
by a hash of the game data and the runtime script, so a save only restores into
a build that can read it. Built HTML is not committed; `dunge-pages:build-site`
(system `dunge/pages`) writes the whole Pages site, and `site/check.sh` builds
it twice under different compiler state, diffs the results, and boots each page
under the parity harness. CI runs that script and deploys its output.

## Scope Cuts

Dunge will not have inline links. Choices are enough.

Dunge will not embed arbitrary Lisp in story data. The old public Lisp DSL is
removed; `.dunge` source is canonical.

Dunge will not copy the full Twine or Ink surface area. The bar is stateful,
validatable, saveable choice-based interactive fiction with a small set of
flexible primitives.
