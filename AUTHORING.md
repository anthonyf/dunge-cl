# Dunge Authoring Guide

This guide describes public `.dunge` authoring conventions. The language stays
declarative: source files describe what content exists, what it means, and when
it is eligible. Common Lisp decides how content is rolled, generated, resolved,
mutated, and saved.

## Expressions and Conditions

Wherever a form takes a value, such as `:say`, `:set :value`, `:inc :amount`,
or the operands of a comparison, it takes an **expression**. Expressions run
the same way in the console and in the browser.

### Values

An expression is a literal or an expression form:

- Literals: strings, integers, keywords, `t`, and `nil`.
- State references: `(:global key)`, `(:player key)`, `(:self key)`, and
  `(:ref role key)`. The game declares its `:player` keys like its globals.
- Arithmetic: `(:add a b ...)`, `(:sub a b ...)`, `(:mul a b ...)`,
  `(:min a b ...)`, and `(:max a b ...)`. `:sub` subtracts each later operand
  from the first and needs at least two; the others take one or more.
- Text: `(:concat a b ...)` joins its parts as text, and strings may
  interpolate state (see below).
- Dice: `(:roll "2d6+1")` or `(:roll "2d6+1" :label :attack)` (see below).

Arithmetic works on integers only. An unset or cleared state value counts as
`0`, as it does for `:inc` and `:dec`. Any other non-integer operand, such as a
keyword or a string, is a runtime error. So is any result, including one from
`:inc` or `:dec`, beyond plus or minus 2^53 - 1 (9007199254740991), the
largest integer both runtimes represent exactly. The validator rejects integer
literals outside that range and non-integer literals used as arithmetic or
comparison operands.

```lisp
(:set :target (:global :hp)
      :value (:max 0 (:sub (:global :hp) (:self :damage))))
```

### Conditions

A condition is used by `:when`, `:if`, `:branch`, and choice `:when` fields:

- A state reference is true when its value is neither `nil` nor unset.
- `(:eq a b)` compares any two values. Strings, integers, and keywords are
  equal when they are the same value. `nil` equals unset and cleared state.
- `(:lt a b)`, `(:lte a b)`, `(:gt a b)`, and `(:gte a b)` compare integers,
  with the same operand rules as arithmetic.
- `(:not c)`, `(:and c ...)`, and `(:or c ...)` combine conditions.

```lisp
(:choice "Rest" (:set :target (:global :hp) :value (:global :max-hp))
 :when (:and (:lt (:global :hp) (:global :max-hp))
             (:gte (:global :rations) 1)))
```

Every positional form has a canonical keyword-field spelling: `(:lt a b)` is
`(:lt :left a :right b)`, and `(:add 1 2)` is `(:add :operands (1 2))`.

### Dice

`(:roll DICE [:label KEY])` rolls dice written as `NdS`, `NdS+M`, or `NdS-M`,
such as `"1d6"`, `"d20"`, or `"3d4-2"`. The dice string is checked when the
game loads. Each roll draws from the game's generator, which starts from the
game's `:seed`. It is the same generator in the console and the browser, so the
same seed and choices give the same rolls in both. Every roll is added to the
game's roll log, tagged with its `:label` when it has one. Browser saves
include the generator state and the roll log, so a reloaded game continues the
same sequence.

A roll is an integer expression, so it can be an arithmetic operand:

```lisp
(:set :target (:global :damage)
      :value (:max 0 (:sub (:roll "1d8" :label :damage) (:global :armor))))
```

Rolls may appear only in effects, never in conditions. A condition can be
evaluated any number of times, such as on every render, so a roll there would
consume the generator unpredictably. To branch on a roll, store it first:

```lisp
(:set :target (:global :check) :value (:roll "1d20"))
(:if :when (:gte (:global :check) 12)
 :then ((:say "You leap the gap."))
 :else ((:say "You fall short.")))
```

The validator also rejects dice with more than 2^31 sides, which the generator
cannot roll evenly, and dice whose modifier or largest possible total falls
outside the supported integer range.

### Interpolation

A string expression may name state in braces:

- `{global:key}`, `{player:key}`, `{self:key}`, and `{ref:role:key}` read state
  the same way as the forms above.
- `{{` and `}}` write literal braces. Any other `{` or `}` is a source error.

```lisp
(:say "The chest holds {self:coins} coins; you carry {global:gold}.")
```

An interpolated string compiles to `:concat`. Room paragraphs (`:p`), labels,
and titles are plain text and are not interpolated.

### How Values Display

`:say` and interpolation display values the same way in both runtimes:

| Value | Displays as |
|---|---|
| string | the string itself |
| integer | decimal digits, with a leading `-` when negative |
| keyword | its lower-case name without the colon: `:calm` shows `calm` |
| `t` | `true` |
| `nil`, and state that is unset or removed with `:clear` | nothing (the empty string) |

To show a flag as words, branch on it:
`(:if :when (:global :lit) :then ((:say "lit")) :else ((:say "dark")))`.

## Table Result Conventions

Random table entries use `:result` to return safe data. Today, only nested
table references are interpreted directly by the table runtime:

```lisp
(:table :nested-table-id)
```

The other result shapes below are public conventions for future systems such as
loot, inventory, shops, encounters, dungeon generation, NPCs, beats, and oracle
procedures. They are intentionally data, not commands.

### General Shape

A table result should usually be a list whose first element is a keyword result
type:

```lisp
(:result-type payload ... :option value ...)
```

Use these rules unless a subsystem documents a narrower shape:

- Result type names are keywords, such as `:gold`, `:item`, or `:encounter`.
- Content ids are keywords, such as `:rusted-dagger` or `:goblin-scouts`.
- Options are plist-style keyword/value pairs after the primary payload.
- Amounts may be integers or dice strings, such as `3`, `"1d6"`, or `"2d4+1"`.
- Results name content or facts; they do not mutate state by themselves.
- Use `:when` to control eligibility, and table mode fields such as `:weight`
  or `:range` to control selection.
- Use `:tags` as metadata for downstream systems, organization, filtering, and
  future tooling. Tags do not affect table selection by themselves today.

Scalar keyword results are allowed for small private tables, but reusable
systems should prefer typed result lists so CL can dispatch on the result type.

### Core Result Types

Use `(:table TABLE-ID)` to compose tables. The runtime resolves this now by
rolling the named table and returning its result.

```lisp
(:table :barrow-rare-loot)
```

Use `(:gold AMOUNT)` for money.

```lisp
(:gold 6)
(:gold "1d6")
```

Dice strings use `NdS`, `dS`, or `NdS+M`/`NdS-M` notation, such as `"1d6"`,
`"d8"`, or `"2d6+3"`. The string remains authored data until CL procedure code
rolls it and records the result.

Use `(:item ITEM-ID ...)` for inventory items. Supported options are
plist-style keys such as `:count`, `:slots`, `:bulky`, `:condition`, and
`:tags`. Omit `:count` for a single item. By default, each item copy costs
one inventory slot; `:bulky t` makes each copy cost two, and `:slots N`
overrides the slot cost for the whole entry.

```lisp
(:item :rusted-dagger)
(:item :torch :count "1d4")
(:item :iron-mail :bulky t)
(:item :coin-purse :slots 0)
(:item :silver-ring :condition :tarnished :tags (:loot :jewelry))
```

Use `(:supply SUPPLY-ID ...)` for stackable adventuring supplies that are not
distinct item records. `:count` is the common option. A supply stack costs one
inventory slot by default, regardless of count, unless `:slots` overrides it.

```lisp
(:supply :ration :count "1d4")
(:supply :oil-flask :count 2)
```

Dice strings in `:count` are table result shorthand that CL resolves when it
builds content. The player holds items as `:player` counters named by their
ids, such as `(:ration 3)`.

Use `(:encounter ENCOUNTER-ID ...)` for bestiary or encounter templates.
Common options include `:count`, `:reaction`, `:morale`, `:hp`, `:str`,
`:armor`, and `:damage`.

```lisp
(:encounter :goblin-scouts)
(:encounter :skeletons :count "1d6" :reaction :uncertain)
```

Encounter results are still data. CL decides which room owns the encounter,
which enemy profile defaults to apply, and whether the resulting combat is
active, defeated, escaped, or player-defeated. Generated rooms can surface
active encounter choices before ordinary exits.

Use `(:hazard HAZARD-ID)`, `(:feature FEATURE-ID)`, and
`(:room-detail DETAIL-ID)` for procedural dungeon content.

```lisp
(:hazard :unstable-ceiling)
(:feature :dry-fountain)
(:room-detail :flooded-floor)
```

Generated room procedures can combine these result shapes with loot,
encounter, and exit data to create room instances before play. The shared
resolver normalizes loot counts and extracts `(:exit DIRECTION ROOM-ID)` data,
and the crawler turns gold/item/supply results into once-only "Take ..." choices
that add to the player's counters. The table results stay declarative; Common
Lisp decides when a rolled result becomes a generated room, a loot choice, or
other content.

```lisp
(:exit :back "threshold")
(:exit :deeper "generated:dungeon:2")
```

Generator procedures may also reserve room-id templates that are not navigated
directly. The adaptation testbed uses `"generated:dungeon:*"` to mean "create or
recall the next generated dungeon room here." CL replaces that template with a
concrete generated room id before storing the playable room exit.

```lisp
(:exit :deeper "generated:dungeon:*")
```

Use `(:npc NPC-ID ...)` for an NPC presence or generated contact. Common
options include `:role` and `:disposition`.

```lisp
(:npc :blacksmith :role :merchant :disposition :wary)
```

Use `(:shop-stock STOCK-ID ...)` for stock entries. Common options include
`:price` and `:count`. A future shop system may expand stock ids into items,
prices, quantities, and availability.

```lisp
(:shop-stock :blacksmith-basic)
(:shop-stock :lantern :price 10 :count 1)
```

Use `(:beat BEAT-ID)` or `(:storylet STORYLET-ID)` when a table selects
eligible narrative content by id.

```lisp
(:beat :blacksmith-warns-about-mines)
(:storylet :mayor-reveals-first-regalia-clue)
```

Use `(:oracle ANSWER ...)` for solo oracle tables. Common options include
`:twist` and `:detail`.

```lisp
(:oracle :yes)
(:oracle :no :twist :but)
(:oracle :yes :detail (:table :omen-details))
```

### Bundles

Use `:bundle` tables when one roll should return several results.

```lisp
(:table
 :id :starter-kit
 :mode :bundle
 :entries
 ((:table-entry :result (:item :torch :count 2))
  (:table-entry :result (:supply :ration :count 3))
  (:table-entry :result (:gold "1d6"))))
```

Bundle entries can still use `:when`, so a subsystem can build context-aware
packages without adding procedural logic to `.dunge`.

### Example

```lisp
(:table
 :id :barrow-loot
 :mode :weighted
 :entries
 ((:table-entry :weight 4 :result (:gold "1d6"))
  (:table-entry :weight 2 :result (:item :rusted-dagger))
  (:table-entry :weight 2 :result (:supply :ration :count 1))
  (:table-entry
   :weight 1
   :when (:marked? :barrow-secret-found)
   :tags (:loot :regalia)
   :result (:item :dragon-scale-fragment))))
```

This table says what can be found. CL loot procedures decide how to parse dice,
surface a find to the player, add gold, create item stacks, handle tags, and
report the outcome.
