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

Source diagnostics preserve file and schema context while forms are compiled.
For split games, an error in a referenced room file reports the room file first
and then the manifest field that included it. Diagnostics intentionally track
source form and field paths rather than exact line and column positions.

## Source Example

A small game is written as data:

```lisp
(:game
 :start "kitchen"
 :rooms
 ((:room
   :id "kitchen"
   :title "Kitchen"
   :body
   ((:p :text "It's a kitchen. A pot sits on the stove.")
    (:branch
     :when (:state :scope :global :key :recipe)
     :then
     ((:choice
       :options
       ((:option
         :label "Cook stew"
         :do (:goto :room "victory")))))
     :else
     ((:p :text "You'd cook, but you don't know what.")))
    (:choice
     :options
     ((:option :label "Search the cupboard" :do (:gosub :room "cupboard"))
      (:option :label "Leave" :do (:goto :room "hallway"))))))

  (:room
   :id "cupboard"
   :title "Cupboard"
   :body
   ((:p :text "Old shelves, dust.")
    (:choice
     :options
     ((:option
       :label "Take the recipe card"
       :do (:sequence
            :effects
            ((:set
              :target (:state :scope :global :key :recipe)
              :value t)
             (:back)))
       :once t
       :id :take-recipe)))))

  (:room
   :id "hallway"
   :title "Hallway"
   :body
   ((:p :text "A hallway.")))

  (:room
   :id "victory"
   :title "Victory"
   :body
   ((:p :text "You cooked. You win.")
    (:choice
     :options
     ((:option :label "Quit" :do (:quit))))))))
```

This source compiles into internal `game`, `room`, `p`, `branch`, `choice`,
`state-ref`, `state-set`, `goto`, and related CLOS objects. Authors do not call
the private builders directly.

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
game-level constraints such as the start room and `:goto`/`:gosub` room
targets.

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
(:goto :room "hallway")
(:gosub :room "cupboard")
```

Choices remain the only player interaction primitive. Dunge does not need
Twine-style inline links. Removing links keeps the source schema, AST, renderer,
validator, and future compiler simpler.

Choice visibility and persistence are data:

```lisp
(:option
 :label "Take the recipe card"
 :do (:sequence
      :effects
      ((:set
        :target (:state :scope :global :key :recipe)
        :value t)
       (:back)))
 :when (:not
        :condition (:state :scope :global :key :recipe))
 :once t
 :id :take-recipe)
```

Default choices are sticky. A once-only choice is hidden after it is selected.
The runtime records consumed choices in `taken-choices`, keyed by stable choice
IDs. Validation requires explicit IDs for once-only choices.

## State

Global state is the first-class primitive for flags, counters, and simple
inventory-like facts. Entity-local state and ref-scope state are also supported
for scene-local mechanisms.

Source state references are explicit:

```lisp
(:state :scope :global :key :recipe)
(:state :scope :self :key :switch)
(:state :scope :ref :role :door :key :open)
```

State keys, state scopes, entity reference roles, and choice IDs are explicit
keyword data. Dunge does not downcase symbols or strings into state keys. Room
IDs and scene entity IDs are strings and are matched exactly, so state data and
story object names keep separate, predictable representations.

Entity-local and ref-scope state is strictly declared. Reading, writing,
incrementing, clearing, or toggling a key that the target entity did not declare
in `:state` is an error. This catches typos instead of silently creating
phantom slots. Global state is currently unrestricted; this may tighten in a
future revision.

## Effects And Sequences

Choices can target a single effect/control node or a sequence:

```lisp
(:sequence
 :effects
 ((:set
   :target (:state :scope :global :key :recipe)
   :value t)
  (:back)))
```

`sequence` is an effect/control AST node, not Lisp `progn`. It executes its
children in order and stops when a child produces a control result such as
`:goto`, `:gosub`, `:back`, or `:quit`.

## Save And Load

`.dunge` files serialize authored content. Player save files should serialize
runtime state, not executable story code and not the whole authored game.

The minimum save payload is still:

```lisp
(:current-room "cupboard"
 :return-stack ("kitchen")
 :globals ((:recipe . t))
 :taken-choices (:take-recipe))
```

Entity-local state can be added when save/load is implemented. The format can
start as s-expressions and later move to JSON because the runtime state model
does not depend on Lisp execution.

## Validator

Validation is a separate pass over the AST after game construction. It catches
authoring errors before play:

- missing `:goto` and `:gosub` room targets when statically known;
- malformed conditions and effects;
- unknown state scopes;
- once-only choices without stable IDs;
- duplicate room IDs and duplicate scene IDs;
- unresolved entity refs.

Dynamic values that cannot be statically resolved should be reported as such
rather than silently accepted as validated.

## Scope Cuts

Dunge will not have inline links. Choices are enough.

Dunge will not embed arbitrary Lisp in story data. The old public Lisp DSL is
removed; `.dunge` source is canonical.

Dunge will not copy the full Twine or Ink surface area. The bar is stateful,
validatable, saveable choice-based interactive fiction with a small set of
flexible primitives.
