# Dunge - Game Design Document

This is the long-term game design north star. The current Lisp codebase
implements the interactive-fiction language layer described in
`ARCHITECTURE.md`; Cairn-style character, combat, dungeon, oracle, and town
systems below are aspirational until their roadmap phases land.

## Overview

**Dunge** is a text-based dungeon crawler/adventure game built as a solo RPG experience. Players navigate procedurally generated dungeons through a choice-based interface, with behind-the-scenes dice rolls determining available options.

### Design Pillars

1. **Choice-Based Interface** - Players interact through limited, context-sensitive choices rather than free-form commands
2. **Hidden Complexity** - Dice rolls and skill checks happen behind the scenes; results manifest as available (or missing) choices
3. **Solo RPG Experience** - Oracle systems replace the GM, creating surprising and emergent gameplay
4. **OSR Sensibility** - Deadly, resource-focused, exploration-driven gameplay

### System Foundation

- **Mechanics:** Cairn (simplified resolution, 3 stats, inventory slots)
- **Procedures:** B/X D&D (exploration turns, wandering monsters, reaction rolls, morale)
- **Solo Engine:** Oracle system for answering questions outside procedures

### Engine Design Rule

Dunge's authored language and engine code have separate jobs:

```text
.dunge describes what exists, what it means, and when it is eligible.
Common Lisp implements how systems resolve, generate, mutate, and save state.
```

This means authored data should define things like tables, actors, items, NPCs,
shops, encounters, room templates, and story beats. Common Lisp should handle
combat resolution, inventory math, transaction rules, procedural layout,
random selection, morale, seeding, logging, and persistence. When a future
feature starts needing algorithms instead of declarations, it belongs in CL and
should be configured from `.dunge`.

### Data Foundations

Dunge uses reusable data definitions rather than hand-authoring every outcome
inside rooms.

**Availability metadata** is the shared basis for conditional content. Forms
that opt in can support `:when`, `:once`, `:id`, `:tags`, and `:priority` where
those concepts have clear runtime meaning. Choices already use this model:

```lisp
(:choice
 "Ask about the old journal"
 ((:say "\"Where did you find that?\"")
  (:mark :blacksmith-saw-journal))
 :when (:marked? :found-first-journal)
 :once t
 :id :ask-blacksmith-journal)
```

**Random tables** are first-class content pools. They can power loot, rumors,
encounters, dungeon details, oracle results, shop stock, and future beat
selection. Current modes are `:weighted`, `:roll`, `:deck`, `:sequence`,
`:first-match`, and `:bundle`.

```lisp
(:game
 :seed 12345
 :tables
 ...)

(:table
 :id :barrow-loot
 :mode :weighted
 :entries
 ((:table-entry :weight 4 :result (:gold "1d6"))
  (:table-entry :weight 2 :result (:item :rusted-dagger))
  (:table-entry :weight 1
   :when (:marked? :barrow-secret-found)
   :tags (:loot :regalia)
   :result (:item :dragon-scale-fragment))))
```

Tables describe possible results; CL decides how to roll, draw, save progress,
log outcomes, and interpret results for a specific subsystem. Table rolls use
the game's deterministic seed by default, and save/load preserves the current
RNG state, roll log, sequence positions, and deck draws.

Public table result conventions live in [AUTHORING.md](AUTHORING.md). In
short, table results should name typed content, such as `(:gold "1d6")`,
`(:item :rusted-dagger)`, `(:encounter :goblin-scouts)`,
`(:room-detail :flooded-floor)`, or `(:shop-stock :blacksmith-basic)`, while CL
implements the inventory, combat, shop, generation, and persistence behavior
attached to those result types.

---

## Core Mechanics (Cairn-Based)

### Attributes

Three stats, each rolled 3d6 (range 3-18) at character creation:

| Stat | Abbr | Governs |
|------|------|---------|
| Strength | STR | Physical power, melee, resisting poison/disease, carrying capacity |
| Dexterity | DEX | Speed, stealth, reflexes, ranged attacks, dodging |
| Willpower | WIL | Perception, persuasion, magic, resisting fear/charm |

### Hit Protection (HP)

- Rolled 1d6 at character creation
- **HP is not health** - it's a buffer representing luck, skill at avoiding harm, fatigue
- When HP reaches 0, damage overflows to STR
- When STR takes damage, character is actually wounded

### Saves

When outcome is uncertain and risk is involved:
- Roll d20 ≤ relevant stat to succeed
- Only the player character rolls

Examples:
- Dodge a trap → DEX save
- Resist poison → STR save
- See through illusion → WIL save
- Notice hidden enemy → WIL save (passive, automatic)

### Combat

**No attack rolls.** Attacks automatically deal damage:

1. Roll weapon damage die
2. Subtract target's Armor value
3. Apply remaining damage to HP
4. When HP depleted, excess damages STR
5. When STR takes damage, roll d20 ≤ current STR or suffer **Critical Damage**

**Critical Damage:** Incapacitated, will die without aid.

**Death:** STR reduced to 0.

**Multiple Attackers:** When several attackers target the same foe, roll all damage dice and keep only the single highest result.

**Blast:** Attacks tagged "blast" hit all targets in an area, rolling damage separately for each.

**Impaired/Enhanced:** Attacking from a bad position → roll d4 instead of normal die. Attacking from advantage → roll d12 instead.

#### Multiple Enemies & Detachments

Cairn treats large groups of similar creatures as **detachments** — a single unit with shared HP and stats. Dunge uses this approach for multi-enemy encounters: rather than tracking individual combatants, a group can be represented as one enemy profile with boosted stats.

| Group Size | HP Modifier | Attack Modifier | Notes |
|------------|-------------|-----------------|-------|
| 1 (solo) | As listed | As listed | Standard encounter |
| 2-3 (small group) | +50% HP | Keep highest of 2 dice | e.g. "2 Goblins": 6 HP, roll 2d6 keep highest |
| 4-6 (pack) | Double HP | Enhanced (d12) | e.g. "Pack of Wolves": 12 HP, d12 attack |
| 7+ (detachment) | Triple HP | Enhanced (d12), blast | Player attacks impaired (d4) unless blast |

**Design model:**
- A group encounter can be represented as a single encounter with one enemy profile
- The enemy name reflects the group: "2 Goblins", "Wolf Pack", "Skeleton Horde"
- HP and attack die are pre-calculated from the base creature stats using the table above
- When the group takes critical damage, it's "routed or broken" — narratively some flee, the rest fall
- Blast spells (e.g. Elemental Wall) bypass the impaired penalty against detachments

**Example bestiary profiles:**

| Profile | HP | Armor | Attack | STR | DEX | WIL | Notes |
|---------|----|-------|--------|-----|-----|-----|-------|
| Goblin | 4 | 0 | d6 | 8 | 12 | 8 | Solo baseline |
| 2 Goblins | 6 | 0 | d8 | 8 | 12 | 8 | Small group, pre-scaled |
| Wolf Pack | 12 | 0 | d12 | 12 | 14 | 8 | Pack, enhanced attack |
| Skeleton Horde | 15 | 1 | d12 | 8 | 13 | 0 | Detachment, player attacks impaired |

### Armor

| Type | Armor Value | Slots |
|------|-------------|-------|
| None | 0 | 0 |
| Leather/Gambeson | 1 | 1 |
| Chain/Brigandine | 2 | 2 |
| Plate | 3 | 3 |
| Shield | +1 | 1 |

Armor subtracts from incoming damage before HP/STR.

### Weapons

| Type | Damage | Slots | Notes |
|------|--------|-------|-------|
| Unarmed | d4 | 0 | Always available |
| Light (dagger, club) | d6 | 1 | Can be thrown |
| Medium (sword, axe) | d8 | 1 | Standard |
| Heavy (polearm, greatsword) | d10 | 2 | Two hands, bulky |

Impaired/Enhanced rules (see Combat above) also apply to weapon attacks.

### Inventory

- **10 inventory slots** (can be modified by STR)
- Most items: 1 slot
- Bulky items: 2 slots
- Tiny items (coins, gems): 100 per slot
- **Fatigue** from spellcasting or exhaustion takes slots
- **Deprived:** All slots full → cannot recover HP

### Magic

- Spells contained in **Spellbooks** (1 slot each)
- Anyone can cast by holding the book and reading aloud
- After casting, gain 1 **Fatigue** (takes an inventory slot)
- Casting in danger (combat) requires a **WIL save**; failure risks extra Fatigue, spellbook destruction, injury, or death
- **Scrolls** are single-use, no Fatigue, no inventory slot
- **Relics** are magical items with limited charges and a recharge condition (no Fatigue)
- Fatigue clears after full rest
- No class restrictions — any character can cast any spell

#### Shortlist — Spells for Implementation

These spells map well to our current engine (combat encounters, room gates, inventory system):

**Combat spells:**

| Spell | Effect in Engine | Mechanic |
|-------|-----------------|----------|
| Cure Wounds | Restore 1d4 STR to target | Consumable-style combat choice |
| Shield | Target gains +2 Armor for encounter | Set flag, modify armor |
| Sleep | Enemy falls asleep, auto-victory | Set encounter state to :victory |
| Charm | Enemy becomes friendly, end encounter | New encounter state :charmed |
| Pacify | Enemy loses will to fight | Set encounter state :fled (enemy flees) |
| Frenzy | Next attack is Enhanced (roll d12) | Temporary damage die override |
| Web | Immobilize enemy, skip their attack 1 round | Flag on encounter, skip enemy turn |

**Exploration spells:**

| Spell | Effect in Engine | Mechanic |
|-------|-----------------|----------|
| Knock | Open a locked door/gate | Satisfy gate condition |
| Illuminate | Reveal hidden exits in current room | Unlock hidden gate |
| Detect Magic | Sense magical items/traps nearby | Unlock hidden gate or show info |
| Arcane Eye | Scout adjacent room before entering | Show room description without entering |
| Fog Cloud | Avoid or escape encounters | Auto-succeed flee or bypass combat room |
| Disguise | Bypass social/guard encounters | Satisfy gate condition |

#### Full Cairn Spell Reference (d100)

For future consideration. Spells marked with * are in the shortlist above.

| # | Spell | Description |
|---|-------|-------------|
| 1 | Adhere | Objects become extremely sticky |
| 2 | Anchor | Wire sprouts from arms, affixing to points within 50ft |
| 3 | Animate Object | Object obeys your commands |
| 4 | Anthropomorphize | Animal gains human intelligence or appearance |
| 5 | Arcane Eye* | See through a magical floating eyeball |
| 6 | Astral Prison | Freeze object in invulnerable crystal shell |
| 7 | Attract | Objects magnetically attract within 10ft |
| 8 | Auditory Illusion | Create illusory sounds from chosen direction |
| 9 | Babble | Creature repeats your thoughts aloud |
| 10 | Bait Flower | Plant emanates decaying flesh smell |
| 11 | Beast Form | Transform into a mundane animal |
| 12 | Befuddle | Creature cannot form short-term memories |
| 13 | Body Swap | Switch bodies with touched creature |
| 14 | Charm* | Target treats you as a friend |
| 15 | Command | Target obeys a single three-word command |
| 16 | Comprehend | Become fluent in all languages temporarily |
| 17 | Cone of Foam | Dense foam sprays from hand |
| 18 | Control Plants | Nearby plants obey and move slowly |
| 19 | Control Weather | Alter weather type at will |
| 20 | Cure Wounds* | Restore 1d4 STR per day via touch |
| 21 | Deafen | All nearby creatures lose hearing |
| 22 | Detect Magic* | See or hear nearby magical auras |
| 23 | Disassemble | Detach and reattach body parts at will |
| 24 | Disguise* | Alter one character's humanoid appearance |
| 25 | Displace | Object appears 15ft from actual position |
| 26 | Earthquake | Ground shakes violently, damaging structures |
| 27 | Elasticity | Body stretches up to 10ft |
| 28 | Elemental Wall | 50ft ice or fire wall rises from ground |
| 29 | Filch | Visible item teleports to your hands |
| 30 | Fish Lung | Target breathes underwater until surfacing |
| 31 | Flare | Bright energy ball reveals location |
| 32 | Fog Cloud* | Dense fog spreads from caster |
| 33 | Frenzy* | Nearby creature erupts in violence |
| 34 | Gate | Portal to random plane opens |
| 35 | Gravity Shift | Change gravity direction for self only |
| 36 | Greed | Creature desires visible item overwhelmingly |
| 37 | Haste | Movement speed tripled |
| 38 | Hatred | Creature develops deep hatred of target |
| 39 | Hear Whispers | Hear faint sounds clearly |
| 40 | Hover | Object hovers 2ft above ground frictionlessly |
| 41 | Hypnotize | Creature enters trance, answers yes/no question |
| 42 | Icy Touch | Ice layer spreads on touched surface (10ft radius) |
| 43 | Identify Owner | Letters appear spelling object's owners |
| 44 | Illuminate* | Floating light moves at command |
| 45 | Invisible Tether | Two objects cannot move >10ft apart |
| 46 | Knock* | Mundane or magical lock unlocks loudly |
| 47 | Leap | Jump up to 10ft high once |
| 48 | Liquid Air | Air becomes swimmable |
| 49 | Magic Dampener | Nearby magical effects halved in effectiveness |
| 50 | Manse | Sturdy furnished cottage appears for hours |
| 51 | Marble Craze | Pockets fill with marbles every 30 seconds |
| 52 | Masquerade | Appearance and voice match touched character |
| 53 | Miniaturize | Touched creature shrinks to mouse size |
| 54 | Mirror Image | Illusory controllable duplicate appears |
| 55 | Mirrorwalk | Mirror becomes gateway to another mirror |
| 56 | Multiarm | Gain temporary extra arm |
| 57 | Night Sphere | 50ft darkness sphere displaying night sky appears |
| 58 | Objectify | Become inanimate object (piano to apple sized) |
| 59 | Ooze Form | Become living jelly |
| 60 | Pacify* | Nearby creature develops aversion to violence |
| 61 | Passage | Creates temporary path through wood/stone/brick |
| 62 | Phobia | Creature becomes terrified of chosen object |
| 63 | Pit | 10ft wide, 10ft deep pit opens in ground |
| 64 | Primal Surge | Creature evolves into future species version |
| 65 | Push/Pull | Object pushed/pulled with one man's strength |
| 66 | Raise Dead | Skeleton rises to serve, follows simple orders |
| 67 | Raise Spirit | Corpse spirit manifests, answers 1 question |
| 68 | Read Mind | Hear surface thoughts of nearby creatures |
| 69 | Repel | Objects magnetically repel within 10ft |
| 70 | Scry | See through eyes of previously touched creature |
| 71 | Sculpt Elements | Inanimate material behaves like clay |
| 72 | Sense | Sense nearest example of chosen object type |
| 73 | Shield* | Touched creature protected from mundane attacks |
| 74 | Shroud | Touched creature invisible until moving |
| 75 | Shuffle | Two creatures instantly switch places |
| 76 | Skillful Repair | Make minor repairs to nonliving objects |
| 77 | Sleep* | Creature falls into light sleep |
| 78 | Slick | 30ft radius becomes extremely slippery |
| 79 | Smoke Form | Body becomes controllable living smoke |
| 80 | Sniff | Smell even faintest scent traces |
| 81 | Snuff | Mundane light sources instantly extinguish |
| 82 | Sort | Inanimate items sort by chosen categories |
| 83 | Spellsaw | Whirling blade clears plant material harmlessly |
| 84 | Spider Climb | Climb surfaces like spider |
| 85 | Swarm | Become swarm of crows, rats, or piranhas |
| 86 | Target Lure | Touched object becomes target of nearby spells |
| 87 | Telekinesis | Mentally move item under 60lbs |
| 88 | Telepathy | Two creatures hear each other's thoughts remotely |
| 89 | Teleport | Move object/person within 50ft radius |
| 90 | Thicket | Up to 50ft thicket of trees and brush sprouts |
| 91 | Time Control | 50ft bubble slows/increases time by 10% |
| 92 | True Sight | See through all nearby illusions |
| 93 | Upwell | Spring of seawater appears |
| 94 | Vision | Completely control what creature sees |
| 95 | Visual Illusion | Room-sized silent immobile illusion appears |
| 96 | Ward | 50ft silver circle prevents chosen species crossing |
| 97 | Web* | Wrists shoot thick webbing |
| 98 | Widget | Primitive drawn tool/item appears temporarily |
| 99 | Wizard Mark | Finger shoots ulfire-colored paint visible only to caster |
| 100 | X-Ray Vision | See through walls, dirt, clothing, etc. |

### Bestiary

Monsters use the engine's enemy-spec format: `("Name" HP ARMOR ATTACK-DIE :str STR :dex DEX :wil WIL)`. Cairn monsters with dual attacks (d8+d8) are simplified to a single die representing their strongest hit. Stat guidelines from Cairn: 3 = deficient, 6 = weak, 10 = average, 14 = noteworthy, 18 = legendary. HP: 3 = average, 6 = hardy, 10+ = serious threat.

#### Random Encounter Tables by Tier

Roll d8 on the appropriate table for the dungeon depth.

**Tier 1 — Shallow / Early Dungeon**

| d8 | Monster | HP | Armor | Atk | STR | DEX | WIL | Notes |
|----|---------|----|-------|-----|-----|-----|-----|-------|
| 1 | Goblin | 4 | 0 | d6 | 8 | 12 | 8 | Hit-and-run tactics |
| 2 | Skeleton | 5 | 1 | d6 | 8 | 13 | 0 | Reforms unless bones scattered |
| 3 | Zombie | 2 | 0 | d6 | 12 | 6 | 3 | Slow but tough; spreads infection |
| 4 | Kobold | 3 | 0 | d6 | 8 | 13 | 4 | Sets traps; avoids fair fights |
| 5 | Bandit | 4 | 1 | d6 | 12 | 12 | 9 | May negotiate or flee |
| 6 | Viper | 3 | 0 | d6 | 5 | 12 | 3 | Poisonous bite |
| 7 | Cave Locust | 2 | 0 | d6 | 6 | 12 | 3 | Swarming insects |
| 8 | Acolyte | 4 | 1 | d6 | 8 | 11 | 14 | Dark cultist; may cast spells |

**Tier 2 — Mid Dungeon**

| d8 | Monster | HP | Armor | Atk | STR | DEX | WIL | Notes |
|----|---------|----|-------|-----|-----|-----|-----|-------|
| 1 | Gnoll | 6 | 1 | d8 | 12 | 14 | 8 | Hyena-headed pack hunter |
| 2 | Hobgoblin | 6 | 2 | d8 | 14 | 8 | 11 | Disciplined; fights in formation |
| 3 | Bugbear | 8 | 1 | d8 | 14 | 12 | 11 | Ambush predator |
| 4 | Ghoul | 6 | 0 | d8 | 14 | 8 | 3 | Paralyzing claws; eats corpses |
| 5 | Ogre | 6 | 1 | d10 | 16 | 8 | 6 | Brute; easily bribed with treasure |
| 6 | Werewolf | 8 | 0 | d8 | 15 | 14 | 6 | Silver weapons enhanced; mundane impaired |
| 7 | Harpy | 8 | 0 | d8 | 7 | 12 | 14 | Charming song (WIL save) |
| 8 | Rust Monster | 5 | 0 | d6 | 16 | 13 | 5 | Destroys metal armor on critical |

**Tier 3 — Deep Dungeon**

| d8 | Monster | HP | Armor | Atk | STR | DEX | WIL | Notes |
|----|---------|----|-------|-----|-----|-----|-----|-------|
| 1 | Troll | 14 | 1 | d10 | 14 | 12 | 4 | Regenerates; only fire/acid kills |
| 2 | Owlbear | 9 | 0 | d10 | 16 | 12 | 5 | Ferocious; destroys armor on crit |
| 3 | Basilisk | 10 | 1 | d10 | 12 | 13 | 13 | Petrifying gaze |
| 4 | Wight | 12 | 3 | d10 | 16 | 8 | 12 | Drains STR permanently on crit |
| 5 | Gargoyle | 8 | 3 | d8 | 14 | 4 | 12 | Immune to charm/sleep; stone skin |
| 6 | Minotaur | 12 | 1 | d10 | 16 | 12 | 8 | Charging gore (d12) |
| 7 | Wyvern | 11 | 0 | d10 | 15 | 14 | 13 | Poisonous stinger |
| 8 | Vampire | 12 | 1 | d10 | 14 | 12 | 16 | Regenerates from blood; only sunlight kills |

#### Boss Encounters

Bosses are hand-placed in dungeon designs, not rolled randomly. They have higher stats, special mechanics, and narrative significance. Each should have a weakness or strategic angle the player can discover beforehand.

| Monster | HP | Armor | Atk | STR | DEX | WIL | Special |
|---------|----|-------|-----|-----|-----|-----|---------|
| Green Dragon | 12 | 2 | d12 | 14 | 15 | 18 | Chlorine breath (d4 STR damage); detachment |
| Lich | 14 | 1 | d8 | 8 | 8 | 18 | Casts up to 6 spells; bound to artifact (must destroy to kill) |
| Eye of Terror | 15 | 0 | d8 | 9 | 8 | 16 | Casts Charm, Sleep, Telekinesis at will |
| Hydra | 12 | 2 | d12 | 13 | 7 | 12 | Multi-headed; loses heads on critical but keeps fighting |
| Mind Lasher | 12 | 0 | d8 | 8 | 12 | 18 | Mind blast stuns (WIL save); extracts brains |
| Purple Worm | 18 | 1 | d12 | 18 | 8 | 6 | Swallows whole on critical (d8 STR acid) |
| Sphinx | 18 | 0 | d10 | 12 | 13 | 18 | Magic-immune; poses riddles; terrifying roar |
| Storm Giant | 18 | 2 | d12 | 18 | 16 | 18 | Lightning immune; thunderclap (4 STR, doubled vs metal) |
| Titan | 18 | 3 | d12 | 16 | 15 | 18 | Shape-shifts; controls elements; levitates |

**Boss design notes:**
- Bosses should be foreshadowed (NPC warnings, environmental clues, lore)
- Each boss should have at least one exploitable weakness discoverable through exploration
- Consider offering non-combat victory paths for high-WIL bosses (Sphinx riddle, Lich artifact destruction)
- Boss loot should be memorable: spellbooks, relics, or significant gold

#### Full Cairn Bestiary Reference

All creatures from the Cairn 2e Warden's Guide, for future use. Dual attacks shown as originally specified.

| Monster | HP | Armor | STR | DEX | WIL | Attack | Special |
|---------|----|-------|-----|-----|-----|--------|---------|
| Acolyte | 4 | 1 | 8 | 11 | 14 | Dagger d6 | Cultist |
| Aranea | 6 | 0 | 13 | 12 | 15 | Bite d8 | Fire enhanced; carries Charm & Command |
| Bandit | 4 | 1 | 12 | 12 | 9 | Short sword d6 | Leader: 2 Armor, d10 |
| Banshee | 8 | 0 | 6 | 12 | 15 | Touch d8 | Iron enhanced; wail stuns |
| Basilisk | 10 | 1 | 12 | 13 | 13 | Bite d10 | Petrifying gaze |
| Blink Dog | 5 | 0 | 11 | 14 | 5 | Bite d6 | Phases; melee impaired |
| Blood Elk | 4 | 0 | 12 | 13 | 5 | Horns d8 | Eviscerates on critical |
| Boggart | 3 | 0 | 4 | 17 | 13 | Special | Controlled by true name; magic abilities |
| Bone Construct | 8 | 3 | 15 | 5 | 3 | Arms d8+d8 | Mindless guardian |
| Bugbear | 8 | 1 | 14 | 12 | 11 | Club d8 | Ambush predator |
| Burrowing Horror | 6 | 1 | 16 | 11 | 4 | Bite d10, acid d8 blast | Severs on critical |
| Cave Locust | 2 | 0 | 6 | 12 | 3 | Bite d6 | Swarm insect |
| Centaur | 6 | 1 | 14 | 12 | 14 | Spear d8 | — |
| Cobblehounds | 12 | 2 | 14 | 1 | 8 | Bite d10 | Immobile guardian |
| Creeping Vines | 8 | 0 | 10 | 12 | 2 | Vines d4 blast | Asphyxiates on critical |
| Crypt Guardian | 12 | 0 | 12 | 11 | 14 | Claws d8+d8 | Non-magical impaired; teleports |
| Dryad | 4 | 0 | 8 | 12 | 14 | Arms d6 | Befuddles; bound to tree |
| Ettin | 10 | 0 | 16 | 8 | 6 | Club d10 | Two-headed; cannot be surprised |
| Eye of Terror | 15 | 0 | 9 | 8 | 16 | Bite d8 | Casts spells at will |
| Frost Elf | 14 | 1 | 8 | 13 | 14 | Dagger d6 | Magic-resistant; casts Sleep, Teleport |
| Gargoyle | 8 | 3 | 14 | 4 | 12 | Claws d8+d8 | Frozen by day; charm/sleep immune |
| Gelatinous Ooze | 8 | 1 | 15 | 6 | 3 | Touch d8 | Engulfs on critical |
| Ghost | 8 | 0 | 14 | 12 | 15 | Drain d6 | Possesses on critical |
| Ghoul | 6 | 0 | 14 | 8 | 3 | Claws d6+d6 | Paralyzes; reanimates corpses |
| Giant Scorpion | 8 | 1 | 11 | 12 | 4 | Claws d10+d10 | Poison: permanent d8 STR loss |
| Gnoll | 6 | 1 | 12 | 14 | 8 | Spear d8 | Pack hunter |
| Goblin | 4 | 0 | 8 | 12 | 8 | Dagger d6 | Hit-and-run |
| Green Dragon | 12 | 2 | 14 | 15 | 18 | Bite d12 | Chlorine breath d4 STR |
| Griffon | 7 | 0 | 14 | 15 | 12 | Claws d6+d6 | Tears flesh on critical |
| Grizzly Bear | 6 | 0 | 15 | 13 | 5 | Claws d8+d8 | Bleeds on critical |
| Harpy | 8 | 0 | 7 | 12 | 14 | Claws d6+d6 | Song charms (WIL save) |
| Hellhound | 8 | 0 | 12 | 15 | 9 | Bite d8, breath d6 blast | Fire immune |
| Hobgoblin | 6 | 2 | 14 | 8 | 11 | Mace d8 | Enhanced with allies |
| Hooded Men | 12 | 0 | 9 | 12 | 14 | Leystaff d8 | d4 WIL drain on crit; 2 spellbooks |
| Hydra | 12 | 2 | 13 | 7 | 12 | Bite d12 blast | 9 heads; loses heads on critical |
| Invisible Stalker | 8 | 0 | 12 | 12 | 15 | Fists d4+d4 | Invisible; ignores armor |
| Killer Bees | 6 | 0 | 6 | 14 | 8 | Sting d6 | Stinger lodges d4/round |
| Kobold | 3 | 0 | 8 | 13 | 4 | Bite d6 | Darkvision; traps |
| Lamia | 6 | 0 | 11 | 12 | 16 | Bite d8 | Charms; d6 WIL drain on crit |
| Lich | 14 | 1 | 8 | 8 | 18 | Soul dagger d8 | Up to 6 spellbooks; artifact-bound |
| Manticore | 6 | 0 | 15 | 14 | 12 | Claws d6+d6, spike d8 | Deprivation on critical |
| Mimic | 9 | 2 | 13 | 6 | 12 | Bite d8 | Disguises as objects |
| Mind Lasher | 12 | 0 | 8 | 12 | 18 | Tentacles d6 blast | Mind blast stuns; extracts brains |
| Minotaur | 12 | 1 | 16 | 12 | 8 | Axe d10, charge d12 | Tracker |
| Mummy | 6 | 0 | 12 | 8 | 6 | Touch d10 | Prevents recovery; deprivation |
| Naga | 6 | 1 | 14 | 12 | 14 | Sword d6, bite d10 | Hypnotic gaze |
| Night Cat | 6 | 0 | 9 | 14 | 5 | Claws d6+d6 | Nocturnal pack hunter |
| Night Hag | 8 | 0 | 9 | 11 | 16 | Talons d8+d8 | Carries 3 spellbooks |
| Nightmare | 8 | 0 | 15 | 12 | 8 | Hooves d8+d8 | Demonic horse; smoke obscures |
| Ogre | 6 | 1 | 16 | 8 | 6 | Club d10 | Bribable with treasure |
| Owlbear | 9 | 0 | 16 | 12 | 5 | Beak d10, claws d8+d8 | Destroys armor on critical |
| Phoenix | 4 | 0 | 15 | 13 | 12 | Talons d10+d10 | Explodes on death; reborn in d3 days |
| Pixie | 3 | 0 | 3 | 15 | 13 | — | Invisible; casts Sleep & Masquerade |
| Purple Worm | 18 | 1 | 18 | 8 | 6 | Bite d12 | Swallows whole; d8 STR acid |
| Red Cap | 6 | 0 | 6 | 12 | 8 | Sickles d6+d6 | Restores STR from blood |
| Reptilian | 5 | 1 | 14 | 12 | 5 | Spear d8 | Amphibious |
| Root Goblin | 4 | 0 | 8 | 14 | 8 | Spear d6 | Prizes spellbooks |
| Root Witch | 8 | 0 | 9 | 16 | 14 | Fingers d6 | Tunnels underground |
| Rust Monster | 5 | 0 | 16 | 13 | 5 | Bite d6 | Rusts metal; destroys armor on crit |
| Sea Hag | 6 | 0 | 11 | 15 | 14 | Claws d6+d6 | Magic-immune; gaze drops HP to 0 |
| Shadow | 14 | 0 | 1 | 18 | 14 | Touch d6 | Incorporeal; ignores armor; d4 STR drain |
| Shambling Mound | 9 | 0 | 15 | 6 | 8 | Tendrils d8+d8 | Swallows on critical |
| Skeleton | 5 | 1 | 8 | 13 | 0 | Sword d6 | Reforms unless scattered |
| Sky Giant | 12 | 1 | 16 | 12 | 14 | Mace d10 | Missiles impaired |
| Sphinx | 18 | 0 | 12 | 13 | 18 | Claws d8+d8 blast, beak d10 | Magic-immune; riddles; roar |
| Storm Giant | 18 | 2 | 18 | 16 | 18 | Sword d12 | Lightning immune; thunderclap |
| Swine Thing | 9 | 0 | 16 | 8 | 13 | Gore d6+d6 | Night shape-shifter; charms |
| Titan | 18 | 3 | 16 | 15 | 18 | Sword d12 | Shape-shifts; controls elements |
| Treant | 10 | 3 | 15 | 3 | 12 | Roots d8+d8 blast | Sentient tree; ancient |
| Triton | 6 | 0 | 12 | 15 | 12 | Trident d8 | Aquatic; commands fish |
| Troll | 14 | 1 | 14 | 12 | 4 | Bite d10, claws d8+d8 | Regenerates; fire/acid stops |
| Unicorn | 6 | 0 | 14 | 12 | 14 | Horn d10 | Ignores armor |
| Vampire | 12 | 1 | 14 | 12 | 16 | Bite d10 | Regen 6 HP from blood; d12 WIL drain |
| Viper | 3 | 0 | 5 | 12 | 3 | Bite d6 | Lethal poison |
| Warp Panther | 8 | 0 | 13 | 16 | 12 | Tentacles d8+d8 blast, bite d10 | Teleports; magic-resistant |
| Warrior Snail | 4 | 2 | 14 | 6 | 3 | Tentacles d8+d8 | Some reflect magic |
| Water Elemental | 14 | 0 | 15 | 16 | 4 | Spray d8 | Mundane impaired; drowns on crit |
| Werewolf | 8 | 0 | 15 | 14 | 6 | Claws d6+d6, bite d8 | Silver enhanced; mundane impaired |
| Wight | 12 | 3 | 16 | 8 | 12 | Sword d10 | Permanent STR drain on critical |
| Will-o-Wisp | 3 | 0 | 6 | 17 | 12 | — | Leads astray; nocturnal spirit |
| Wolf | 6 | 0 | 12 | 14 | 8 | Bite d8 | Trainable |
| Wood Troll | 10 | 0 | 15 | 12 | 7 | Bite d8, club d10 | Regenerates in forest |
| Wyvern | 11 | 0 | 15 | 14 | 13 | Stinger d10 | Impales on critical |
| Zombie | 2 | 0 | 12 | 6 | 3 | Nails d6 | Mind-immune; reforms; infection |

### Rest & Recovery

| Rest Type | Duration | Effect |
|-----------|----------|--------|
| Short rest | 10 minutes (1 turn) | Catch breath, no HP recovery unless safe |
| Long rest | Full night | Restore all HP, clear all Fatigue |
| Full recovery | Week of downtime | Restore all HP and damaged stats |

---

## Exploration Procedures (B/X-Based)

### The Dungeon Turn

Time in dungeons is tracked in **turns** (10 minutes each).

Each turn, the party can:
- Move through explored areas (fast)
- Explore new area carefully (120 feet, mapping)
- Search a room thoroughly
- Attempt a significant action (pick lock, disarm trap, etc.)
- Rest (required 1 turn per 6 turns of activity)

### Light

| Source | Duration | Radius |
|--------|----------|--------|
| Torch | 6 turns (1 hour) | 30 feet |
| Lantern | 24 turns (4 hours) | 30 feet |
| Candle | 12 turns (2 hours) | 5 feet |

**Darkness:** Cannot see, all checks impaired, easily surprised.

### Wandering Monsters

Every 2 turns, roll d6:
- **1:** Wandering monster encounter
- **2-6:** No encounter

When an encounter occurs, check for surprise and reaction.

### Surprise

When two groups meet unexpectedly, each side rolls d6:
- **1-2:** That side is surprised (cannot act first round)

### Reaction Rolls

Not everything attacks on sight. When encountering creatures, roll 2d6:

| 2d6 | Reaction |
|-----|----------|
| 2 | Hostile, attacks immediately |
| 3-5 | Unfriendly, may attack |
| 6-8 | Neutral, uncertain |
| 9-11 | Indifferent, open to talk |
| 12 | Friendly, helpful |

Modify by CHA... err, WIL in our system, and by circumstances.

### Morale

Most creatures don't fight to the death. Check morale (2d6 ≤ Morale score) when:
- First ally is killed
- Half the group is down

Failure = flee or surrender.

| Creature Type | Typical Morale |
|---------------|----------------|
| Cowardly (goblins) | 6 |
| Average (bandits) | 7 |
| Trained (soldiers) | 8 |
| Fearless (undead) | 12 |

### Doors

Dungeon doors are assumed:
- **Stuck:** 2-in-6 chance to force open (STR save if we adapt)
- **Locked:** Require key or lockpicks
- **Listened at:** 2-in-6 to hear noise behind (WIL save)

Doors opened by party tend to close/swing shut.
Doors opened by monsters tend to stay open.

### Searching

- Searching a room takes 1 turn
- 2-in-6 chance to find secret doors/hidden features (or WIL save)
- Describing specific actions may grant automatic success

---

## Choice-Based System

### Core Concept

The player interacts through **choices**, not free-form commands. The engine:

1. Evaluates the current scene
2. Runs automatic/passive checks behind the scenes
3. Generates available choices based on:
   - Scene properties (exits, features, NPCs)
   - Passed perception/skill checks
   - Inventory contents
   - Game state/flags
4. Presents choices to player
5. Resolves chosen action
6. Presents outcome and new choices

### Hidden Rolls Philosophy

Players don't see dice rolls by default. Results manifest as:
- **Choices that appear** (you passed a check)
- **Choices that don't appear** (you failed, but don't know it)
- **Outcomes** (combat damage, trap triggers, etc.)

### Roll Visibility Setting

Player preference controls roll display:

| Setting | Behavior |
|---------|----------|
| Hidden | No rolls shown, pure narrative |
| Visible | Rolls shown inline after relevant text |
| Log Only | Rolls hidden in narrative, viewable in separate log |

**Important:** Failed passive checks should remain hidden even in Visible mode to preserve mystery.

### Choice Categories

| Category | Examples | Gated By |
|----------|----------|----------|
| Navigation | "Go north", "Enter the cave" | Exit exists |
| Perception | "Examine the loose stone" | Passed WIL check |
| Interaction | "Talk to the merchant" | NPC present |
| Inventory | "Use rope to descend" | Have item |
| Skill | "Pick the lock" | Have tools (or bare hands with penalty) |
| Combat | "Attack the goblin" | Enemy present |
| Knowledge | "Recognize the symbol" | Prior exposure + check |
| Magic | "Cast Light" | Have spellbook |
| Rest | "Make camp", "Rest briefly" | Context appropriate |

### Choice Structure

Each choice has:
- **Label:** Display text ("Examine the scratches on the wall")
- **Conditions:** Requirements to appear (passed check, have item, flag set)
- **Action:** What happens when chosen
- **Outcome:** Result (new scene, damage, item gain, flag set, etc.)

---

## Oracle System

### When to Use Oracles

Oracles answer questions **not covered by procedures**:

| Question Type | Use |
|---------------|-----|
| "Is there a monster?" | Wandering monster check (procedure) |
| "Does it attack?" | Reaction roll (procedure) |
| "Does it flee?" | Morale check (procedure) |
| "Is the door stuck?" | 2-in-6 (procedure) |
| "Is the prisoner lying?" | **Oracle** |
| "Is there a secret passage?" | **Oracle** (or search procedure) |
| "Does the duke know about the cult?" | **Oracle** |

### Yes/No Oracle

Basic probability-shifted oracle:

| Likelihood | d20 Target (Yes if ≤) |
|------------|----------------------|
| Nearly Certain | 18 |
| Very Likely | 15 |
| Likely | 12 |
| 50/50 | 10 |
| Unlikely | 7 |
| Very Unlikely | 4 |
| Nearly Impossible | 2 |

### Twist/Complication System

On certain rolls, add complications:

| d20 Roll | Modifier |
|----------|----------|
| 1 | No, and... (additional negative) |
| 2-7 | No |
| 8-10 | No, but... (silver lining) |
| 11-13 | Yes, but... (complication) |
| 14-19 | Yes |
| 20 | Yes, and... (additional positive) |

### Random Events

Periodically (or when triggered by oracle rolls), introduce unexpected events:

| d6 | Event Type |
|----|------------|
| 1 | New entity appears |
| 2 | Environment change |
| 3 | Complication for PC |
| 4 | Opportunity for PC |
| 5 | Advance a thread/plot |
| 6 | Reveal information |

### Spark Tables

For open-ended questions, combine two random words:

**Action Table (d20):**
1. Seek, 2. Create, 3. Destroy, 4. Protect, 5. Abandon,
6. Reveal, 7. Hide, 8. Oppose, 9. Assist, 10. Transform,
11. Capture, 12. Release, 13. Deceive, 14. Communicate, 15. Move,
16. Rest, 17. Investigate, 18. Celebrate, 19. Mourn, 20. Prepare

**Subject Table (d20):**
1. Treasure, 2. Weapon, 3. Knowledge, 4. Ally, 5. Enemy,
6. Path, 7. Trap, 8. Secret, 9. Power, 10. Weakness,
11. Home, 12. Stranger, 13. Beast, 14. Magic, 15. Faith,
16. Memory, 17. Promise, 18. Danger, 19. Safety, 20. Change

Example: Roll 7 (Hide) + 8 (Secret) = Someone is hiding a secret.

---

## Dungeon Generation

### Room Contents

When entering an unexplored room, determine contents:

| d6 | Contents |
|----|----------|
| 1-2 | Empty |
| 3 | Trap |
| 4 | Monster (no treasure) |
| 5 | Monster with treasure |
| 6 | Special (puzzle, feature, NPC, unique) |

### Room Exits

| d6 | Exits (besides entrance) |
|----|--------------------------|
| 1 | Dead end (0) |
| 2-3 | One exit |
| 4-5 | Two exits |
| 6 | Three or more exits |

### Monster Activity

If a monster is present, what is it doing?

| d6 | Activity |
|----|----------|
| 1 | Sleeping |
| 2 | Eating/feeding |
| 3 | Guarding something |
| 4 | Fighting (internal conflict) |
| 5 | Patrolling/alert |
| 6 | Performing ritual/task |

### Room Features

Roll or choose evocative features:

| d12 | Feature |
|-----|---------|
| 1 | Rubble and debris |
| 2 | Water (pool, stream, flooded) |
| 3 | Fungi/vegetation |
| 4 | Bones/remains |
| 5 | Abandoned equipment |
| 6 | Religious iconography |
| 7 | Furniture (broken or intact) |
| 8 | Unusual architecture |
| 9 | Light source (natural or magical) |
| 10 | Sound (echo, dripping, distant noise) |
| 11 | Smell (decay, sulfur, flowers) |
| 12 | Environmental hazard (unstable, cold, hot) |

---

## Character Sheet

This is the target Cairn-style character sheet for play. It includes current/max stat tracking, a 10-slot inventory grid, Fatigue boxes, and the Deprived flag. The implementation can grow toward this shape incrementally, but this is the player-facing model the rest of the design assumes.

The current engine foundation supports a declarative `:player` form on
`:game`, plus runtime save/load for the player record. Character creation,
inventory slots, item use, and combat mutation are still later phases.

### Core Stats

```
Name: _______________
Background: _______________

STR: __ / __  (current / max)
DEX: __ / __
WIL: __ / __

HP:  __ / __
Armor: __

Gold: __
```

### Inventory (10 Slots)

```
Slot 1: _______________
Slot 2: _______________
Slot 3: _______________
Slot 4: _______________
Slot 5: _______________
Slot 6: _______________
Slot 7: _______________
Slot 8: _______________
Slot 9: _______________
Slot 10: ______________

Fatigue: [ ] [ ] [ ] (takes inventory slots)
```

### Status

```
Deprived: [ ] (cannot recover HP)
Conditions: _______________
```

---

## Core Game Loop

The target loop is a scene-based choice cycle. Each scene presents prose, reveals any context-sensitive options, accepts one player choice, resolves consequences, advances time when appropriate, and then moves to the next scene or sub-loop.

```
┌─────────────────────────────────────────────────────────┐
│                     GAME START                          │
│  Initialize player state, load content tables, choose   │
│  a starting scene, and begin the main play loop.        │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                CHARACTER CREATION                       │
│  Name prompt → background pick → 3d6 stat rolls → swap  │
│  → starting equipment → character summary → town.       │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                SCENE RESOLUTION                         │
│  Each scene contributes:                                │
│    1. Title and prose                                   │
│    2. Visible exits, actions, item uses, and checks     │
│    3. Consequences for the chosen option                │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                 ACTION DISPATCH                         │
│  A choice can:                                          │
│    • Move to another scene                              │
│    • Enter combat or another sub-loop                   │
│    • Mutate player, inventory, or world state           │
│    • Consume an item or spend a resource                │
│    • Branch on a hidden check or known flag             │
│  Inapplicable actions stay hidden.                      │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                   NEXT SCENE                            │
│  The chosen action returns the next scene or terminal   │
│  result. The implementation should keep long sessions   │
│  bounded and avoid growing control stack over time.     │
└─────────────────────────────────────────────────────────┘
```

Future loop features include dungeon-turn advance, wandering-monster checks on scene entry, passed-check / flag tracking, roll-log persistence, and roll-visibility settings. These are tracked in [TODOs.org](TODOs.org) and described in the "Future: Game State" subsection below.

### Combat Loop (Sub-Loop)

Combat is a sub-loop that runs one encounter to a terminal result. An encounter may contain a single foe or a group modeled as one pre-scaled enemy profile. The player chooses an action each round; enemies retaliate or react according to the encounter rules.

```
┌─────────────────────────────────────────────────────────┐
│                  COMBAT START                           │
│  Create encounter state and present opening narration.  │
│  First round: PC makes a DEX save.                      │
│    Pass → "You react quickly!"; normal round order.     │
│    Fail → "Caught off guard!" enemy attacks unopposed,  │
│           then normal rounds.                           │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                  COMBAT ROUND                           │
│  1. Drain encounter-log (if any) to the display.        │
│  2. If the state is no longer active, exit.             │
│  3. Display enemy HP/STR and player HP/STR.             │
│  4. Build and display combat choices from inventory:    │
│       • Each weapon → "Attack with <name> (dN)"         │
│       • Healing Herb → "Use Healing Herb" (if HP < max) │
│       • Unarmed d4 (only if no weapon is carried)       │
│       • Flee (always available)                         │
│  5. Resolve the player's effect, enemy retaliation,     │
│     and the resulting encounter state.                  │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              STATE PRIORITY (per round)                 │
│  update-encounter-state applies:                        │
│    victory > death > incapacitated > fled > active      │
│                                                         │
│  • victory        — enemy STR = 0 or failed STR save    │
│  • death          — player STR = 0                      │
│  • incapacitated  — player failed a critical STR save   │
│  • fled           — player chose Flee and DEX succeeded │
│                     (parting blow on fail)              │
│  • active         — loop back to COMBAT ROUND           │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                 TERMINAL STATE                          │
│  Return victory, death, incapacitated, or fled to the   │
│  caller. Later versions can add morale, surrender,      │
│  pursuit, and more varied enemy behavior here.          │
└─────────────────────────────────────────────────────────┘
```

---

## Data Structures

### Rooms (Scenes/Vignettes)

A room or scene is the smallest authored unit of play. It has a title, descriptive text, exits/actions, and any local state needed for dynamic descriptions or one-time events. "Room" can mean a literal dungeon chamber, a town location, a wilderness waypoint, or a focused narrative vignette.

### Choice

A choice has a player-facing label, an effect, and optional visibility conditions. Choices are rebuilt from the current situation each time the scene is shown so the menu can reflect hidden checks, inventory, resources, NPC disposition, and prior actions.

### Condition guards

Condition guards decide whether a choice is currently visible. Common guards include having an item, passing a hidden stat check, knowing a rumor, having enough light, having already searched a feature, or being in a strong fictional position. A failed guard usually hides the option rather than showing a disabled command.

### Character

The player character tracks name, background, STR/DEX/WIL, HP and max HP, armor, gold, fate points, inventory, fatigue, and conditions. Saves and damage use the same rules for player characters and monsters: roll under the relevant stat for saves, armor absorbs damage, HP absorbs next, and overflow wounds STR.

### Game State

A full game state should collect persistent player data, current scene, dungeon turn, light duration, encounter state, global flags, scene flags, passed hidden checks, roll log, and roll-visibility settings. This gives the game one place to save/load and one place for procedures like wandering monsters and rest to inspect time and risk.

#### Future: Game State (Aspirational)

The saveable state model should support:

- Character and inventory
- Current town/dungeon/scene location
- Dungeon-turn counters and light timers
- Wandering-monster cadence
- Global story flags and per-scene flags
- Previously passed hidden checks
- Recent roll log
- Roll visibility mode: hidden, visible, or log-only

---

## UI Components

### Main Display

```
┌────────────────────────────────────────────────────────┐
│ THE DUSTY ANTECHAMBER                                  │
├────────────────────────────────────────────────────────┤
│                                                        │
│ Broken furniture litters this chamber. Cobwebs hang    │
│ thick in the corners, and dust motes dance in the      │
│ thin light from cracks above.                          │
│                                                        │
│ A wooden door leads north. A stone archway opens to    │
│ the east.                                              │
│                                                        │
├────────────────────────────────────────────────────────┤
│ What do you do?                                        │
│                                                        │
│ > Examine the thin wire near the north door            │
│ > Search through the debris                            │
│ > Listen at the north door                             │
│ > Go through the north door                            │
│ > Go through the east archway                          │
│ > Check your inventory                                 │
└────────────────────────────────────────────────────────┘

┌─ CHARACTER ────────────────────────────────────────────┐
│ Aldric the Bold          HP: 4/6    Armor: 1          │
│ STR: 12  DEX: 10  WIL: 14          Turn: 7            │
│ Inventory: 6/10 slots              Light: 4 turns     │
└────────────────────────────────────────────────────────┘
```

### Roll Log (when enabled)

```
┌─ ROLL LOG ─────────────────────────────────────────────┐
│ [Turn 7] WIL check: needed ≤14, rolled 8 ✓            │
│ [Turn 7] Hear noise: needed 1-2, rolled 4 ✗           │
│ [Turn 5] Combat: Goblin deals 3 damage (d6=4, -1 arm) │
│ [Turn 5] STR save: needed ≤12, rolled 7 ✓             │
└────────────────────────────────────────────────────────┘
```

---

## Design Decisions

1. **Character Progression:** Pure Cairn - no XP or leveling. Characters grow through:
   - Better equipment (weapons, armor)
   - Spellbooks (each is a new capability)
   - Relics and artifacts (unique magic items)
   - Fictional positioning (reputation, allies, secrets, resources)

2. **Magic System:** Cairn Fatigue-based casting
   - Spellbooks are permanent items (1 inventory slot each)
   - Cast any held spell at any time
   - After casting, WIL save or gain 1 Fatigue
   - Fatigue takes inventory slots
   - Full inventory = Deprived (can't recover HP)
   - Rest overnight to clear all Fatigue

3. **Dungeon Structure:** Authored Skeleton + Procedural Flesh

   **Authored (Designer creates):**
   - Dungeon layout / room graph (which rooms connect to which)
   - Room types and purposes (entrance, guard room, boss room, secret vault)
   - Theming and atmosphere (crypt, cave, fortress, etc.)
   - Key narrative beats and set-pieces
   - Themed encounter/loot tables for this dungeon

   **Procedural (Engine generates):**
   - Specific monsters from themed tables
   - Monster activity (sleeping, eating, patrolling, etc.)
   - Treasure and loot from tables
   - Room features and details (furniture, debris, lighting)
   - Additional complications (extra traps, wandering monsters)
   - NPC dispositions and secrets

   **Example Dungeon Skeleton:**
   ```
   GOBLIN WARRENS (Theme: Goblin-infested caves)

   1. Cave Entrance [entrance]
      → leads to: 2, 3

   2. Guard Post [monster]
      → leads to: 1, 4
      → monster: goblin_table (1d4 goblins)

   3. Refuse Pit [hazard]
      → leads to: 1, 5 (hidden)
      → hazard: difficult terrain, disease risk

   4. Chieftain's Cave [boss]
          → leads to: 2, 5
          → monster: goblin_chief + 1d2 guards
          → treasure: boss_loot_table

   5. Hidden Shrine [secret, treasure]
          → leads to: 3 (hidden), 4 (hidden)
          → treasure: shrine_loot_table
          → special: ancient idol (relic?)
   ```

   **At Runtime:**
   - Engine loads skeleton
   - Rolls on tables to populate specific monsters, loot, features
   - Generates room descriptions combining authored + procedural elements
   - Tracks which rooms visited, which secrets found

4. **Party Structure:** Solo PC

   - Player controls a single character
   - All choices, resources, and consequences belong to one character
   - Cleaner narrative and faster play
   - Death is personal - Fate Points are the safety net

   **Future Expansion (not for initial build):**
   - Retainers/companions could be added later
   - Would be simpler than full PCs (basic stats, limited choices)
   - Main PC death still ends the game

5. **Overworld:** Simple Hub (Town)

   A single safe location between dungeon delves.

   **Core Town Locations:**
   - **Blacksmith** - Buy/sell weapons and armor
   - **General Store** - Supplies (torches, rope, rations, etc.)
   - **Inn** - Rest and full recovery (costs gold)
   - **Tavern** - Hear rumors, get quest hooks, learn about dungeons

   **Town Flow:**
   ```
   Return from dungeon
                 ↓
   Town hub (choose location)
                 ↓
   Shop / Rest / Gather info
                 ↓
   Choose next dungeon
                 ↓
   Depart for adventure
   ```

   **Design Notes:**
   - Town is safe - no combat, no random events (initially)
   - Gold matters here - it buys survival
   - Rumors give hints about dungeon contents/secrets
   - Can expand later (factions, more services, town events)

   **Future Expansion:**
   - Temple (healing, curse removal)
   - Thieves' Guild (fences, shady jobs)
   - Wizard's Tower (identify items, spellbooks)
   - Faction reputation system
   - Town events/changes based on player actions

6. **Death & Recovery:** Combined system with three safety nets

   **Layer 1 - Scars (Critical Damage)**
   When you take Critical Damage and survive the STR save, roll on Scars table:
   | d6 | Scar |
   |----|------|
   | 1 | Lasting injury - reduce one stat by 1d4 permanently |
   | 2 | Disfigured - visible mark, -1 on reaction rolls with strangers |
   | 3 | Broken gear - one random item is destroyed |
   | 4 | Hardened - gain +1d4 max HP |
   | 5 | Reoriented - swap any two stat values |
   | 6 | Vision - glimpse something useful (secret, weakness, location) |

   **Layer 2 - Fate Points**
   - Start with 2 Fate Points
   - Spend 1 to avoid death: wake up later, stripped of gear and gold, in a "safe" location
   - Can also spend to reroll a catastrophic outcome (once per situation)
   - Fate Points do NOT regenerate (except possibly as rare rewards)
   - When Fate is empty, death is permanent

   **Layer 3 - Desperate Escape**
   When death is imminent but escape is fictionally plausible, offer a choice:
   - Flee (lose all carried treasure, dungeon alerts to your presence)
   - Surrender (captured - loss of gear, but potential rescue/escape scenario)
   - Fight on (no escape, accept the outcome)

   **True Death**
   Occurs when:
   - STR reaches 0 AND no Fate Points remain
   - Player chooses "Fight on" and loses
   - No escape is fictionally possible (surrounded, trapped, etc.)

---

## Example: Character Creation

### Step 1: Name & Background

```
=== CREATE YOUR ADVENTURER ===

Before the stats, before the gear - who are you?

What is your name?
> [Text input field]
```

Player enters: **Aldric**

```
What were you before you became an adventurer?

> Soldier (trained in combat, disciplined)
> Scholar (educated, curious, physically weak)
> Criminal (streetwise, light-fingered, untrustworthy)
> Pilgrim (faithful, traveled, poor)
> Hunter (survivalist, patient, rural)
> Merchant (wealthy, connected, soft)
```

Background affects starting gear and gives narrative flavor, not stat bonuses.

Player chooses: **Soldier**

### Step 2: Rolling Stats

```
ALDRIC, former Soldier

Now, fate determines your natural abilities.
The dice will be cast for Strength, Dexterity, and Willpower.

[Roll for stats]
> Roll all stats at once
> Roll one at a time (see each before the next)
```

Player chooses: **Roll all stats at once**

*[Hidden rolls: STR 3d6 = 4+3+5 = 12, DEX 3d6 = 2+4+4 = 10, WIL 3d6 = 6+5+3 = 14]*

```
The bones are cast...

STRENGTH:     12  (capable, sturdy)
DEXTERITY:    10  (average reflexes)
WILLPOWER:    14  (sharp-minded, perceptive)

[If rolls visible: STR: 4+3+5=12 | DEX: 2+4+4=10 | WIL: 6+5+3=14]

You are physically capable and mentally sharp, though
no faster than most.

> Accept these stats
> Swap two stats (one time only)
```

The "swap two stats" option adds player agency without full rerolling.

### Step 3: Hit Protection

```
ALDRIC
STR 12 | DEX 10 | WIL 14

Now for Hit Protection - your buffer against death.
This represents luck, instinct, and the will to survive.

[Roll for HP]
> Cast the die
```

*[Hidden roll: 1d6 = 4]*

```
HIT PROTECTION: 4

[If rolls visible: HP roll: d6 = 4]

Not the hardiest, but enough to survive a few blows
if you're careful.

> Continue to equipment
```

### Step 4: Starting Equipment

```
ALDRIC, former Soldier
STR 12 | DEX 10 | WIL 14 | HP 4

As a soldier, you begin with military-issue gear:

STARTING EQUIPMENT:
  [1] Sword (d8, 1 slot)
  [2] Gambeson (Armor 1, 1 slot)
  [3] Helm (+1 Armor vs head blows, 1 slot)
  [4] Rations, 3 days (1 slot)
  [5] Torch x2 (1 slot)
  [6] Waterskin (1 slot)

  Slots used: 6/10
  Gold: 8

You may also choose one additional item:

> Shield (+1 Armor, 1 slot)
> Bow + 20 arrows (d6 ranged, 2 slots)
> Healing herbs x2 (restore d6 HP each, 1 slot)
> Rope, 50ft (1 slot)
> Lantern + oil flask (lasts longer than torch, 2 slots)
```

Player chooses: **Shield (+1 Armor, 1 slot)**

```
You take a sturdy wooden shield, battered but reliable.

INVENTORY:
  [1] Sword (d8)
  [2] Gambeson (Armor 1)
  [3] Helm
  [4] Shield (+1 Armor)
  [5] Rations, 3 days
  [6] Torch x2
  [7] Waterskin

  Slots: 7/10 | Armor: 2 | Gold: 8

> Continue
```

### Step 5: Fate Points

```
ALDRIC, former Soldier
STR 12 | DEX 10 | WIL 14 | HP 4 | Armor 2

Finally, you are granted the blessing of Fate.

FATE POINTS: 2

When death seems certain, you may spend a Fate Point
to survive - though you will lose everything you carry
and awaken somewhere else.

Fate is precious. It does not return easily.

> Continue
```

### Step 6: Final Summary

```
══════════════════════════════════════════════════════
             YOUR ADVENTURER IS READY
══════════════════════════════════════════════════════

  ALDRIC
  Former Soldier

  ATTRIBUTES
  ──────────
  Strength:     12
  Dexterity:    10
  Willpower:    14

  DEFENSES
  ──────────
  Hit Protection: 4/4
  Armor:          2
  Fate Points:    2

  INVENTORY (7/10 slots)
  ──────────
  1. Sword (d8)
  2. Gambeson (Armor 1)
  3. Helm
  4. Shield (+1 Armor)
  5. Rations, 3 days
  6. Torch x2
  7. Waterskin

  Gold: 8

══════════════════════════════════════════════════════

A soldier's training prepared you for battle, but not
for what lies beneath the earth. The dungeon does not
care about rank or discipline.

> Begin your adventure
> Adjust settings (roll visibility, etc.)
```

### Background Starting Gear

| Background | Key Gear | Flavor |
|------------|----------|--------|
| **Soldier** | Sword, gambeson, helm | Combat-ready |
| **Scholar** | Spellbook (random), dagger, ink & quill | One spell, fragile |
| **Criminal** | Lockpicks, dagger, dark cloak, grappling hook | Stealth tools |
| **Pilgrim** | Staff, holy symbol, healing herbs x3 | Survival/healing |
| **Hunter** | Bow, arrows, knife, snare kit, furs | Ranged, traps |
| **Merchant** | Dagger, fine clothes, 30 extra gold | Wealthy but soft |

---

## Example: Combat Encounter

### Setup

- **Player:** Aldric (STR 12, DEX 10, WIL 14, HP 5/6, Armor 1, sword d8)
- **Enemy:** 2 Goblins (STR 8, HP 3 each, Armor 0, rusty blade d6)

### Scene Entry

*[Hidden roll: Surprise check - Player rolls 4, Goblins roll 2]*
*[Goblins are surprised - player gets a free action]*
*[Hidden roll: WIL check to notice the loose stones - rolled 11 vs WIL 14, pass]*

```
GUARD POST

Two goblins crouch around a small fire, gnawing on something
unidentifiable. They haven't noticed you yet. Rusty blades
lie within their reach.

A pile of loose stones near the entrance looks unstable.

What do you do?
> Attack while they're distracted (free strike)
> Kick the loose stones onto them (free action)
> Try to sneak past to the northern passage
> Retreat back the way you came
```

**Note:** "Kick the loose stones" only appears because the player passed the WIL check. A player who failed wouldn't see that option.

### Player Chooses: "Attack while they're distracted"

*[Player has surprise - attacks first, goblins can't respond this round]*
*[Damage roll: d8 = 6, minus 0 armor = 6 damage to Goblin A]*
*[Goblin A has 3 HP, takes 3 to HP (now 0), remaining 3 to STR (now 5)]*
*[Goblin A must make STR save: d20 = 14 vs STR 5 - FAIL, Critical Damage]*

```
You lunge from the shadows, blade flashing. Your sword catches
the first goblin across the chest before it can react. It
collapses with a wet gurgle, out of the fight.

The second goblin shrieks and scrambles for its weapon.

[If rolls visible: Damage: 6 (d8). Goblin takes 3 HP + 3 STR.
STR save failed - Critical Damage]

COMBAT - Round 1

Goblin (HP 3, STR 8)
You (HP 5/6, Armor 1)

What do you do?
> Attack the goblin
> Grab a torch from the fire (improvised weapon)
> Kick the fire at the goblin
> Flee north (they may pursue)
> Flee back south (they may pursue)
```

### Round 1: Player Attacks

*[Initiative: Player d6 = 4, Goblin d6 = 2 - Player goes first]*
*[Player damage: d8 = 3, minus 0 armor = 3]*
*[Goblin HP 3 → 0, no STR damage, but must make STR save]*
*[Goblin STR save: d20 = 7 vs STR 8 - PASS, still fighting but HP gone]*

```
You press the attack. Your blade slices the goblin's arm -
it yelps but keeps its feet, desperation in its eyes.

The goblin slashes back wildly.

[If rolls visible: You deal 3 damage. Goblin HP: 0. STR save
passed - still up but wounded]
```

*[Goblin attacks: d6 = 5, minus 1 armor = 4 damage]*
*[Player HP 5 → 1]*

```
Its rusty blade rakes across your side. You feel the sting
of torn flesh.

[If rolls visible: Goblin deals 5, your armor blocks 1.
You take 4 damage. HP: 5 → 1]

COMBAT - Round 2

Goblin (HP 0, STR 8) - wounded, desperate
You (HP 1/6, Armor 1) - bloodied

What do you do?
> Attack the goblin
> Use your healing herbs (restore 1d6 HP)
> Flee north
> Flee back south
```

**Note:** "Use healing herbs" only appears if the player has them in inventory.

### Round 2: Goblin Wins Initiative

*[Initiative: Player d6 = 2, Goblin d6 = 5 - Goblin goes first!]*
*[Goblin damage: d6 = 2, minus 1 armor = 1]*
*[Player HP 1 → 0, no STR damage yet]*

```
The goblin is faster - its blade catches your shoulder.

[If rolls visible: Goblin deals 2, armor blocks 1. You take 1.
HP: 1 → 0]
```

*[Player damage: d8 = 5, minus 0 armor = 5]*
*[Goblin has 0 HP, 5 damage goes to STR: 8 → 3]*
*[Goblin STR save: d20 = 15 vs STR 3 - FAIL, Critical Damage]*

```
You drive your sword into its chest. The goblin crumples.

[If rolls visible: You deal 5 STR damage. Goblin STR save
failed - Critical Damage, down]

The guard room falls silent except for the crackle of the fire.
You're wounded but alive. Blood drips from your side.

You (HP 0/6, Armor 1) - battered, exhausted

What do you do?
> Search the goblins
> Search the room
> Rest briefly and bind your wounds
> Continue north (dangerous while wounded)
> Retreat south to recover
```

### After Combat: Attempting Rest

```
You slump against the wall, catching your breath. The
dungeon is not safe enough for true rest - you remain
on edge, wounds still fresh.

[You cannot recover HP here. Use supplies or find safety.]

What do you do?
> Use your healing herbs (restore 1d6 HP)
> Search the goblins
> Search the room
> Continue north
> Retreat south
```

### Using Healing Herbs

*[Healing herbs: restore 1d6 HP, consumable]*
*[Roll: d6 = 4, HP 0 → 4]*

```
You crush the herbs into your wound and feel the bleeding
slow. Some strength returns.

[If rolls visible: Healing herbs restore 4 HP. HP: 0 → 4/6]
[Healing herbs removed from inventory]

What do you do?
> Search the goblins
> Search the room
> Continue north
> Retreat south
```

### Combat Summary

| Round | What Happened |
|-------|---------------|
| Surprise | Player spotted goblins, got free attack, downed one |
| Round 1 | Player won initiative, wounded second goblin, took 4 damage |
| Round 2 | Goblin won initiative, hit player (HP to 0), player killed goblin |
| After | Player used healing herbs to recover |

### Key Mechanics Demonstrated

- **Surprise** gives free action
- **No attack rolls** - damage is automatic
- **HP is a buffer**, then STR takes damage
- **STR save on STR damage** = Critical check
- **Initiative** determines who strikes first each round
- **Choices adapt** to situation (flee options, item use)
- **Hidden checks gate options** (loose stones only visible if WIL check passed)

---

## References

- [Cairn SRD](https://cairnrpg.com/cairn-srd/)
- [Knave](https://www.drivethrurpg.com/product/250888/Knave)
- [B/X Essentials / Old School Essentials](https://necroticgnome.com/)
- [Ironsworn](https://www.ironswornrpg.com/) (solo oracle reference)
- [Mythic GME](https://www.wordmillgames.com/mythic.html) (oracle reference)
- [MUNE](https://empaitirern.itch.io/mune) (minimal oracle)
