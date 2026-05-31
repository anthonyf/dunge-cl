# Dunge Authoring Guide

This guide describes public `.dunge` authoring conventions. The language stays
declarative: source files describe what content exists, what it means, and when
it is eligible. Common Lisp decides how content is rolled, generated, resolved,
mutated, and saved.

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

When an item or supply entry is stored directly in player inventory,
`:count` and `:slots` must already be resolved integers. Dice strings are table
result shorthand for CL loot procedures to roll before adding entries to a
player.

Use `(:encounter ENCOUNTER-ID ...)` for bestiary or encounter templates.
Common options include `:count`, `:reaction`, and `:morale`.

```lisp
(:encounter :goblin-scouts)
(:encounter :skeletons :count "1d6" :reaction :uncertain)
```

Use `(:hazard HAZARD-ID)`, `(:feature FEATURE-ID)`, and
`(:room-detail DETAIL-ID)` for procedural dungeon content.

```lisp
(:hazard :unstable-ceiling)
(:feature :dry-fountain)
(:room-detail :flooded-floor)
```

Generated room procedures can combine these result shapes with loot,
encounter, and exit data to create persistent runtime room instances. The shared
resolver can normalize loot counts, apply gold/items/supplies to a player, and
extract `(:exit DIRECTION ROOM-ID)` data. The table results stay declarative;
Common Lisp decides when a rolled result becomes a registered generated room or
a player/world mutation.

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

This table says what can be found. The future loot/inventory subsystem decides
how to parse dice, add gold, create item stacks, handle tags, and report the
outcome to the player.
