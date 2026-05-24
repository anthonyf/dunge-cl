# Dunge Authoring Guide

Dunge games are written as `.dunge` files: safe, data-only s-expressions that
describe rooms, choices, state, and effects. This guide is for authors using
Dunge as the engine for a choice-based interactive fiction game.

## Source Basics

A `.dunge` file contains exactly one top-level form. Each form starts with a
keyword tag. Most full forms use keyword fields, while author-facing shorthand
forms use positional arguments:

```lisp
(:p "A lantern burns beside the locked door.")
```

Dunge expands shorthand forms into their full keyword-field forms before schema
validation. Unknown forms, unknown fields, duplicate fields, missing required
fields, and malformed values are authoring errors.

The current public surface is intentionally small:

- Write choices as `(:choice "Label" effect)`.
- Use `:when` around body content when it should appear conditionally.
- Use `:once` around a `:choice` when it should disappear after selection.
- Use `:go` and `:gosub` for room movement.
- Use `:flags`, `:marked`, `:mark`, `:unmark`, and `:marked?` for ordinary
  global story flags.
- Use explicit `:state`, `:set`, `:inc`, and related forms for counters,
  phases, entity-local state, and referenced entity state.

Use these value shapes consistently:

- Room IDs and scene entity IDs are strings, such as `"foyer"`.
- State keys, choice IDs, and reference roles are keywords, such as
  `:has-key`, `:take-key`, and `:door`.
- Expressions can be strings, keywords, numbers, `t`, `nil`, or a `:state`
  reference. `:marked?` is the shorthand expression for global flags.
- Conditions can be `:marked?`, `:state`, `:eq`, `:not`, `:and`, or `:or`.

## Minimal Game

```lisp
(:game
 :start "foyer"
 :flags (:has-key)
 :rooms
 ((:room
   :id "foyer"
   :title "Foyer"
   :body
   ((:p "Rain ticks against the glass roof.")
    (:once
     :id :take-brass-key
     (:choice
      "Take the brass key"
      ((:mark :has-key)
       (:say "The key is cold from the rain."))))
    (:when (:marked? :has-key)
     (:choice "Open the study" (:go "study")))
    (:choice "Leave" (:quit))))

  (:room
   :id "study"
   :title "Study"
   :body
   ((:p "The study smells of paper, wax, and secrets.")
    (:choice "Return to the foyer" (:go "foyer"))))))
```

## Splitting A Game Into Files

A game manifest may keep rooms inline or refer to room files. String paths are
resolved relative to the file that contains them.

```lisp
(:game
 :start "foyer"
 :flags (:has-key
         :read-journal)
 :rooms
 ("rooms/foyer.dunge"
  "rooms/study.dunge"))
```

Each referenced room file contains one top-level `:room` form:

```lisp
(:room
 :id "foyer"
 :title "Foyer"
 :body
 ((:p "The front door is swollen shut from the rain.")
  (:choice "Wait in the foyer" (:say "The rain keeps falling."))))
```

Room files are validated when loaded, but navigation targets are checked when
the whole `:game` is validated. That lets a room point to another room defined
in a different file.

## Authoring Model

Dunge has three main layers:

- **Rooms** render scene text and collect choices.
- **State** records facts such as clues, counters, switches, and progress.
- **Effects** run when the player selects a choice.

Room bodies contain node forms such as `:p`, `:choice`, `:once`, `:when`,
`:entity`, `:branch`, `:item`, and `:container`.

An effect form is one of `:go`, `:gosub`, `:back`, `:quit`, `:sequence`,
`:mark`, `:unmark`, `:set`, `:clear`, `:inc`, `:dec`, `:toggle`, `:say`, or
`:if`.

The effect in a `:choice` may be either one effect form or a list of effects. A
list-valued choice effect is compiled as a sequence. `:placed :do` still takes a
single effect, so use `:sequence` there when you need several effects.
`:action :do`, `:if :then`, and `:if :else` take effect blocks, which are plain
lists of effects.

## Source Forms Reference

### `:game`

Defines a whole game.

Fields:

- `:rooms` required. A list of inline `:room` forms or relative room file paths.
- `:start` optional. The starting room ID string. If omitted, the first room is
  used.
- `:flags` optional. Keyword story flags initialized to `nil`.
- `:marked` optional. Keyword story flags initialized to `t`.
- `:state` optional. Global state declarations as `(KEY INITIAL-VALUE)` pairs
  for counters, phases, and other non-flag values.

Example:

```lisp
(:game
 :start "station"
 :marked (:has-ticket)
 :flags (:met-conductor
         :found-luggage)
 :state ((:tickets 1)
         (:chapter :arrival))
 :rooms
 ("rooms/station.dunge"
  "rooms/platform.dunge"))
```

When a game declares any global state, all global state references must use one
of the declared keys. `:flags` and `:marked` are folded into the same global
state declarations as `:state`, so they also make typo checking strict.

### `:room`

Defines a scene the player can visit.

Fields:

- `:id` required. Stable room ID string used by `:go`, `:gosub`, and
  `:game :start`.
- `:title` optional. Display title. If omitted, the room ID is shown.
- `:body` optional. List of room content nodes.

Example:

```lisp
(:room
 :id "platform"
 :title "Empty Platform"
 :body
 ((:p "A clock ticks above the silent platform.")
  (:choice "Enter the station" (:go "station"))))
```

### `:p`

Prints a paragraph in the current room.

Preferred shorthand:

```lisp
(:p "Dust covers every shelf except one.")
```

Explicit form:

```lisp
(:p :text "Dust covers every shelf except one.")
```

### `:choice`

Defines one selectable player choice. Choices can appear directly in a room
body, inside an `:entity`, inside `:branch`/`:when` content, or inside a
container view.

Arguments:

- A label string.
- A single effect form or a list of effects.

Examples:

```lisp
(:choice "Enter the station" (:go "station"))
```

```lisp
(:choice
 "Read the journal"
 ((:mark :read-journal)
  (:say "The final entry changes everything.")
  (:go "study")))
```

Use `:when` outside the choice for visibility:

```lisp
(:when (:marked? :has-key)
 (:choice "Unlock the study" (:go "study")))
```

Use `:once` outside the choice for persistence.

### `:once`

Wraps a `:choice` and makes it disappear after the player selects it.

Arguments:

- `:id`
- A keyword choice ID.
- The wrapped `:choice` form.

Example:

```lisp
(:once
 :id :take-torn-letter
 (:choice
  "Pocket the torn letter"
  ((:mark :has-letter)
   (:say "You pocket the torn letter."))))
```

Once-only choices must have stable keyword IDs so the runtime can save that the
choice was consumed.

### `:go`

Moves to another room and replaces the current room.

Arguments:

- One room ID string.

Example:

```lisp
(:choice "Go upstairs" (:go "upper-hall"))
```

### `:gosub`

Moves to another room while remembering the current room on the return stack.
Use it for temporary inspections, close-ups, and modal scenes.

Arguments:

- One room ID string.

Example:

```lisp
(:choice "Read the notice board" (:gosub "notice-board"))
```

### `:back`

Returns to the last room entered with `:gosub` or to the previous transient
view, such as an open container. If there is no return location, play falls out
of the current session.

Fields: none.

Example:

```lisp
(:choice "Back away" (:back))
```

### `:quit`

Ends play.

Fields: none.

Example:

```lisp
(:choice "End the investigation" (:quit))
```

### `:state`

Reads a state value. A state reference can be used as an expression, a
condition, or the target of a state effect. For ordinary global story flags,
prefer `:marked?`, `:mark`, and `:unmark`.

Fields:

- `:scope` required. One of `:global`, `:self`, or `:ref`.
- `:key` required. Keyword state key.
- `:role` required for `:ref`. Keyword role used to find a referenced entity.

Global state:

```lisp
(:state :scope :global :key :has-key)
```

Entity-local state:

```lisp
(:state :scope :self :key :open)
```

Referenced entity state:

```lisp
(:state :scope :ref :role :door :key :locked)
```

Entity-local and ref state must be declared on the target entity before use.

### `:marked?`

Shorthand condition/expression for reading a global story flag. It expands to
`(:state :scope :global :key KEY)`.

Arguments:

- One state key keyword.

Example:

```lisp
(:marked? :has-key)
```

Use it wherever a condition is accepted:

```lisp
(:when (:marked? :has-key)
 (:choice "Unlock the study" (:go "study")))
```

### `:eq`

Tests whether two expressions are equal.

Fields:

- `:left` required. Expression.
- `:right` required. Expression.

Example:

```lisp
(:eq
 :left (:state :scope :global :key :chapter)
 :right :midnight)
```

### `:not`

Inverts a condition.

Explicit form:

```lisp
(:not :condition (:state :scope :global :key :alarm-raised))
```

Preferred shorthand:

```lisp
(:not (:marked? :alarm-raised))
```

### `:and`

Requires every child condition to be true.

Explicit form:

```lisp
(:and
 :conditions
 ((:state :scope :global :key :has-key)
  (:not :condition (:state :scope :global :key :door-open))))
```

Preferred shorthand:

```lisp
(:and
 (:marked? :has-key)
 (:not (:marked? :door-open)))
```

### `:or`

Requires at least one child condition to be true.

Explicit form:

```lisp
(:or
 :conditions
 ((:state :scope :global :key :has-key)
  (:state :scope :global :key :knows-password)))
```

Preferred shorthand:

```lisp
(:or
 (:marked? :has-key)
 (:marked? :knows-password))
```

### `:sequence`

Runs several effects in order. If a control effect such as `:go`, `:gosub`,
`:back`, or `:quit` runs, later effects in the sequence are skipped.

Fields:

- `:effects` optional. List of effect/control forms.

Explicit form:

```lisp
(:sequence
 :effects
 ((:mark :read-journal)
  (:say "The final entry changes everything.")
  (:go "study")))
```

Inside `:choice`, you can usually write the effect list directly:

```lisp
(:choice
 "Read the journal"
 ((:mark :read-journal)
  (:say "The final entry changes everything.")
  (:go "study")))
```

### `:mark`

Shorthand for setting a global story flag to `t`.

Arguments:

- One state key keyword.

Example:

```lisp
(:mark :has-key)
```

### `:unmark`

Shorthand for setting a global story flag to `nil`.

Arguments:

- One state key keyword.

Example:

```lisp
(:unmark :alarm-raised)
```

### `:set`

Sets a state value. Prefer `:mark` and `:unmark` for boolean global story
flags.

Fields:

- `:target` required. `:state` reference.
- `:value` required. Expression.

Example:

```lisp
(:set
 :target (:state :scope :global :key :chapter)
 :value :arrival)
```

### `:clear`

Removes a state value. Reading a cleared value yields `nil`.

Fields:

- `:target` required. `:state` reference.

Example:

```lisp
(:clear :target (:state :scope :global :key :temporary-note))
```

### `:inc`

Increments numeric state. Missing numeric state is treated as `0`.

Fields:

- `:target` required. `:state` reference.
- `:amount` optional. Expression, default `1`.

Example:

```lisp
(:inc
 :target (:state :scope :global :key :visits)
 :amount 1)
```

### `:dec`

Decrements numeric state. Missing numeric state is treated as `0`.

Fields:

- `:target` required. `:state` reference.
- `:amount` optional. Expression, default `1`.

Example:

```lisp
(:dec
 :target (:state :scope :global :key :candles)
 :amount 1)
```

### `:toggle`

Toggles boolean-like state.

Fields:

- `:target` required. `:state` reference.

Example:

```lisp
(:toggle :target (:state :scope :self :key :switch))
```

Global state toggles between `nil` and `t`, or between `:off` and `:on`.
Entity-local state can be toggled when its declared initial value is `nil`,
`t`, `:off`, or `:on`.

### `:say`

Prints a short response during an effect, then refreshes the current room unless
a later control effect changes location.

Preferred shorthand:

```lisp
(:say "The latch clicks, but the door does not open.")
```

Explicit form:

```lisp
(:say :text "The latch clicks, but the door does not open.")
```

### `:if`

Runs one effect block when a condition is true and another when it is false.

Fields:

- `:when` required. Condition.
- `:then` optional. List of effects.
- `:else` optional. List of effects.

Example:

```lisp
(:if
 :when (:marked? :has-key)
 :then
 ((:mark :door-open)
  (:say "The study door opens."))
 :else
 ((:say "The lock refuses you.")))
```

### `:entity`

Groups authored behavior around a scene object or character. Entities can have
local state, references to other entities, and nested body nodes. Actions inside
an entity run with that entity as `:self`.

Fields:

- `:name` required. Author-facing name used for diagnostics and state labels.
- `:id` optional. Stable scene ID string. Required if another entity refers to
  it, and needed for saving local state.
- `:state` optional. Entity-local declarations as `(KEY INITIAL-VALUE)` pairs.
- `:refs` optional. References as `(ROLE TARGET-ID)` pairs.
- `:body` optional. List of child nodes.

Example:

```lisp
(:room
 :id "hallway"
 :body
 ((:entity
   :name "study door"
   :id "study-door"
   :state ((:open nil))
   :body
   ((:when (:state :scope :self :key :open)
     (:p "The study door stands open."))))
  (:entity
   :name "wall panel"
   :id "panel"
   :state ((:switch :off))
   :refs ((:door "study-door"))
   :body
   ((:p "A brass switch juts from the panel.")
    (:action
     :label "Flip the switch"
     :do
     ((:toggle :target (:state :scope :self :key :switch))
      (:if
       :when (:eq
              :left (:state :scope :self :key :switch)
              :right :on)
       :then
       ((:set
         :target (:state :scope :ref :role :door :key :open)
         :value t)
        (:say "Something opens in the wall."))
       :else
       ((:say "The mechanism settles back.")))))))))
```

### `:branch`

Chooses which room/body nodes to render and which choices to collect based on a
condition. Use `:branch` when you need both `:then` and `:else`; use `:when`
for the common no-else case.

Fields:

- `:when` required. Condition.
- `:then` optional. Node list.
- `:else` optional. Node list.

Example:

```lisp
(:branch
 :when (:marked? :door-open)
 :then
 ((:p "The study door stands open.")
  (:choice "Enter the study" (:go "study")))
 :else
 ((:p "The study door is locked.")))
```

### `:when`

Shorthand for a no-else `:branch`. It guards one or more body nodes.

Arguments:

- A condition.
- One or more body forms to include when the condition is true.

Example:

```lisp
(:when (:marked? :door-open)
 (:p "The study door stands open.")
 (:choice "Enter the study" (:go "study")))
```

### `:action`

Adds an entity-scoped choice. Actions must appear inside an `:entity`; their
effects run with the containing entity as `:self`.

Fields:

- `:label` required. Choice label.
- `:do` optional. Effect block, written as a list of effects.

Example:

```lisp
(:entity
 :name "journal"
 :id "journal"
 :state ((:open nil))
 :body
 ((:action
   :label "Open the journal"
   :do
   ((:set :target (:state :scope :self :key :open) :value t)
    (:say "The journal falls open to the last page.")))))
```

### `:placed`

Describes a placed thing and optionally adds a direct interaction for it. In
the current console runtime, `:description` is what appears in the room; the
embedded `:thing` supplies the authored object data but is not automatically
printed by the placement.

Fields:

- `:thing` required. A node such as `:item` or `:container`.
- `:description` optional. Text shown in the room.
- `:label` optional. Choice label for the interaction.
- `:do` optional. Single effect/control form for the interaction.

Example:

```lisp
(:placed
 :thing (:item :name "silver pin")
 :description "A silver pin glints in the dust."
 :label "Take the silver pin"
 :do (:sequence
      :effects
      ((:mark :has-pin)
       (:say "You slip the pin into your pocket."))))
```

### `:item`

Describes a simple object.

Fields:

- `:name` required.
- `:description` optional. If omitted, the name is printed.

Example:

```lisp
(:item
 :name "sealed envelope"
 :description "A sealed envelope rests under the blotter.")
```

### `:container`

Describes an openable collection of contents. A container can contribute a
choice that enters a container view, where its contents are described and a
back/close choice is added.

Fields:

- `:name` required. Title used for the container view.
- `:description` optional. Text shown in the room.
- `:open` optional. Choice label that opens the container.
- `:close` optional. Choice label that exits the container view. Defaults to
  `"Back"`.
- `:contents` optional. Node list displayed inside the container view.

Example:

```lisp
(:container
 :name "writing desk"
 :description "A narrow writing desk sits below the window."
 :open "Open the desk"
 :close "Close the desk"
 :contents
 ((:item :name "ink bottle")
  (:item
   :name "folded receipt"
   :description "A folded receipt is tucked behind the drawer.")))
```

## Common Patterns

### One-shot discovery

Use `:once` with a stable `:id`, and set a clue flag.

```lisp
(:once
 :id :study-receipt
 (:choice
  "Study the receipt"
  ((:mark :clue-receipt)
   (:say "The date on the receipt is wrong."))))
```

### Unlocking a new route

Hide a choice behind a flag with `:when`.

```lisp
(:when (:marked? :found-stair)
 (:choice "Enter the hidden stair" (:go "hidden-stair")))
```

### Temporary close-up scene

Use `:gosub` and `:back` for a room that behaves like an inspection view.

```lisp
(:room
 :id "portrait"
 :title "Portrait"
 :body
 ((:p "The paint is cracked around one eye.")
  (:choice "Return" (:back))))
```

## Validation Notes

Dunge validates many authoring mistakes before play:

- Room IDs must be strings, and `:go`/`:gosub` targets must exist in the full
  game.
- Entity IDs must be unique within a room.
- `:refs` must point to existing entity IDs in the same room.
- If `:game :state`, `:flags`, or `:marked` declares globals, every global
  state key must be declared.
- Once-only choices must have unique keyword IDs.
- Actions must be inside entities.
- Multiple effects in `:placed :do` must be wrapped in `:sequence`; `:choice`
  may use a direct effect list.

Entity-local `:self` state and referenced `:ref` state are checked when the
condition or effect runs against a specific entity. Declare each local key in
the owning entity's `:state` field before reading or writing it.

## Retired And Private Syntax

Do not author the old or private forms below:

- `(:choice :options (...))` and `(:option ...)` are retired. Use one
  `(:choice "Label" effect)` per choice.
- `(:goto :room "room-id")` is retired. Use `(:go "room-id")`.
- `(:gosub :room "room-id")` is retired. Use `(:gosub "room-id")`.
- `:%choice`, `:%goto`, and `:%gosub` are private expansion targets and are
  rejected if authored directly.
- Choice visibility is no longer a field on the choice. Wrap the choice with
  `:when`.
- Choice persistence is no longer a field on the choice. Wrap the choice with
  `:once`.

## Runtime-only Nodes

Some internal runtime nodes are not public `.dunge` source forms. Do not author
`enter`, `refresh`, `fall-through`, or `container-view` directly; use the public
forms above. For example, `:container` creates the transient container view for
you, and a bare non-control effect refreshes the current room after it runs.
