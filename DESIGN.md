# Dunge - Game Design Document

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

**Impaired:** Attacking from a bad position or while wounded → roll d4 instead
**Enhanced:** Attacking from advantage or exploiting weakness → roll d12 instead

### Inventory

- **10 inventory slots** (can be modified by STR)
- Most items: 1 slot
- Bulky items: 2 slots
- Tiny items (coins, gems): 100 per slot
- **Fatigue** from spellcasting or exhaustion takes slots
- **Deprived:** All slots full → cannot recover HP

### Magic

- Spells contained in **Spellbooks** (1 slot each)
- Anyone can cast by holding the book
- After casting, make WIL save or gain 1 Fatigue
- Fatigue clears after full rest

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

```
┌─────────────────────────────────────────────────────────┐
│                     GAME START                          │
│            Character Creation / Load Game               │
└─────────────────────┬───────────────────────────────────┘
					  │
					  ▼
┌─────────────────────────────────────────────────────────┐
│                   SCENE ENTRY                           │
│  1. Load/generate scene content                         │
│  2. Run automatic checks (perception, hearing, etc.)    │
│  3. Update game state based on check results            │
│  4. Advance dungeon turn if applicable                  │
│  5. Check for wandering monsters (every 2 turns)        │
└─────────────────────┬───────────────────────────────────┘
					  │
					  ▼
┌─────────────────────────────────────────────────────────┐
│                CHOICE GENERATION                        │
│  For each potential choice:                             │
│    - Check conditions (items, flags, passed checks)     │
│    - If conditions met, add to available choices        │
│  Always include: navigation, basic actions              │
└─────────────────────┬───────────────────────────────────┘
					  │
					  ▼
┌─────────────────────────────────────────────────────────┐
│                  PRESENT SCENE                          │
│  - Display scene description                            │
│  - Show available choices                               │
│  - (Optional) Show roll log                             │
│  - Wait for player input                                │
└─────────────────────┬───────────────────────────────────┘
					  │
					  ▼
┌─────────────────────────────────────────────────────────┐
│                RESOLVE CHOICE                           │
│  Based on choice type:                                  │
│    Navigation → Load new scene                          │
│    Combat → Enter combat loop                           │
│    Skill use → Roll, determine outcome                  │
│    Item use → Apply effect                              │
│    Interaction → Dialogue/reaction                      │
│  Update game state (HP, inventory, flags, turns)        │
└─────────────────────┬───────────────────────────────────┘
					  │
					  ▼
┌─────────────────────────────────────────────────────────┐
│               OUTCOME DISPLAY                           │
│  - Show result of action                                │
│  - Show any rolls (if visibility enabled)               │
│  - Update displayed stats if changed                    │
└─────────────────────┬───────────────────────────────────┘
					  │
					  ▼
┌─────────────────────────────────────────────────────────┐
│                CHECK GAME STATE                         │
│  - Player dead? → Game Over                             │
│  - Objective complete? → Victory/Progression            │
│  - Otherwise → Return to Scene Entry or Choice Gen      │
└─────────────────────┴───────────────────────────────────┘
```

### Combat Loop (Sub-Loop)

```
┌─────────────────────────────────────────────────────────┐
│                  COMBAT START                           │
│  First round: PC makes DEX save                        │
│    Pass → PC acts first (normal round)                  │
│    Fail → enemy attacks unopposed, then normal rounds   │
│  Rounds 2+: PC always acts first, then enemy            │
└─────────────────────┬───────────────────────────────────┘
					  │
					  ▼
┌─────────────────────────────────────────────────────────┐
│                  COMBAT ROUND                           │
│  PC acts, then enemy acts                               │
└─────────────────────┬───────────────────────────────────┘
					  │
		  ┌───────────┴───────────┐
		  ▼                       ▼
┌─────────────────────┐ ┌─────────────────────┐
│   PLAYER TURN       │ │   ENEMY TURN        │
│ Present choices:    │ │ AI determines action│
│  - Attack [target]  │ │ Resolve attack/act  │
│  - Use item         │ │ Apply damage to PC  │
│  - Flee             │ │ Check for Critical  │
│  - Special action   │ │                     │
│ Resolve chosen      │ │                     │
│ Apply damage        │ │                     │
│ Check for Critical  │ │                     │
└─────────┬───────────┘ └──────────┬──────────┘
		  │                        │
		  └───────────┬────────────┘
					  ▼
┌─────────────────────────────────────────────────────────┐
│                 END OF ROUND                            │
│  - Check if all enemies dead → Victory                  │
│  - Check if player dead → Defeat                        │
│  - Check morale (first death, 50% down) → Flee?         │
│  - Otherwise → Next round                               │
└─────────────────────────────────────────────────────────┘
```

---

## Data Structures

### Scene/Vignette

```common-lisp
(defclass vignette ()
  ((id          :initarg :id          :accessor vignette-id)
   (title       :initarg :title       :accessor vignette-title)
   (description :initarg :description :accessor vignette-description)
   (choices     :initarg :choices     :accessor vignette-choices     :initform nil)
   ;; Automatic checks to run on entry
   (perception-checks :initarg :perception-checks
                      :accessor vignette-perception-checks
                      :initform nil)
   ;; Scene state
   (visited-p   :accessor vignette-visited-p   :initform nil)
   (flags       :accessor vignette-flags       :initform (make-hash-table :test 'equal))))

(defmethod get-description ((v vignette))
  ;; May vary based on flags, visited status, etc.
  (vignette-description v))

(defmethod get-available-choices ((v vignette) game-state)
  (remove-if-not (lambda (choice)
                   (conditions-met-p choice game-state))
                 (vignette-choices v)))
```

### Choice

```common-lisp
(defclass choice ()
  ((label      :initarg :label      :accessor choice-label)
   (conditions :initarg :conditions :accessor choice-conditions :initform nil)
   (action     :initarg :action     :accessor choice-action)))

(defmethod conditions-met-p ((c choice) game-state)
  (every (lambda (condition)
           (evaluate condition game-state))
         (choice-conditions c)))

(defmethod execute-choice ((c choice) game-state)
  (perform (choice-action c) game-state))
```

### Condition Types

```common-lisp
;; Base condition — generic function
(defgeneric evaluate (condition game-state)
  (:documentation "Return T if the condition is satisfied."))

;; Specific conditions
(defclass has-item-condition ()
  ((item-id :initarg :item-id :accessor condition-item-id)))

(defclass passed-check-condition ()
  ((check-id :initarg :check-id :accessor condition-check-id)))

(defclass flag-condition ()
  ((flag-name      :initarg :flag-name      :accessor condition-flag-name)
   (expected-value :initarg :expected-value  :accessor condition-expected-value)))

(defclass stat-condition ()
  ((stat    :initarg :stat    :accessor condition-stat)    ; :str, :dex, or :wil
   (minimum :initarg :minimum :accessor condition-minimum)))
```

### Character

```common-lisp
(defconstant +max-slots+ 10)

(defclass character ()
  ((name       :initarg :name       :accessor character-name)
   (background :initarg :background :accessor character-background)

   (str-current :initarg :str :accessor character-str-current)
   (str-max     :initarg :str :accessor character-str-max)
   (dex-current :initarg :dex :accessor character-dex-current)
   (dex-max     :initarg :dex :accessor character-dex-max)
   (wil-current :initarg :wil :accessor character-wil-current)
   (wil-max     :initarg :wil :accessor character-wil-max)

   (hp-current  :initarg :hp  :accessor character-hp-current)
   (hp-max      :initarg :hp  :accessor character-hp-max)

   (armor     :initarg :armor     :accessor character-armor     :initform 0)
   (gold      :initarg :gold      :accessor character-gold      :initform 0)
   (inventory :initarg :inventory :accessor character-inventory  :initform nil)
   (fatigue   :accessor character-fatigue  :initform 0)))

(defun used-slots (character)
  (+ (character-fatigue character)
     (reduce #'+ (character-inventory character)
             :key #'item-slots :initial-value 0)))

(defun deprived-p (character)
  (>= (used-slots character) +max-slots+))

(defun stat-value (character stat)
  "Return the current value of STAT (:str, :dex, or :wil)."
  (ecase stat
    (:str (character-str-current character))
    (:dex (character-dex-current character))
    (:wil (character-wil-current character))))

(defun make-save (character stat)
  "Roll d20 against STAT. Returns a plist with :stat, :target, :roll, :success."
  (let* ((target (stat-value character stat))
         (roll   (1+ (random 20)))
         (success (<= roll target)))
    (list :stat stat :target target :roll roll :success success)))

(defun take-damage (character amount)
  "Apply AMOUNT damage (after armor). Mutates CHARACTER.
Returns a plist with :damage, :hp-damage, :str-damage, :critical, :dead."
  (let* ((remaining (- amount (character-armor character)))
         (hp-dmg 0) (str-dmg 0) (critical nil) (dead nil))
    (when (plusp remaining)
      ;; Absorb with HP first
      (when (plusp (character-hp-current character))
        (let ((absorbed (min remaining (character-hp-current character))))
          (decf (character-hp-current character) absorbed)
          (decf remaining absorbed)
          (setf hp-dmg absorbed)))
      ;; Overflow to STR
      (when (plusp remaining)
        (decf (character-str-current character) remaining)
        (setf str-dmg remaining)
        ;; Critical damage check
        (let ((save (make-save character :str)))
          (unless (getf save :success)
            (setf critical t)))
        (when (<= (character-str-current character) 0)
          (setf dead t))))
    (list :damage amount :hp-damage hp-dmg :str-damage str-dmg
          :critical critical :dead dead)))
```

### Game State

```common-lisp
(defclass game-state ()
  ((character       :initarg :character   :accessor game-character)
   (current-scene-id :initarg :scene-id   :accessor game-current-scene-id)
   (dungeon-turn     :accessor game-dungeon-turn     :initform 0)
   (turns-since-rest :accessor game-turns-since-rest :initform 0)
   (turns-since-wandering-check :accessor game-turns-since-wandering-check
                                :initform 0)
   (global-flags   :accessor game-global-flags   :initform (make-hash-table :test 'equal))
   (scene-flags    :accessor game-scene-flags    :initform (make-hash-table :test 'equal))
   (passed-checks  :accessor game-passed-checks  :initform nil)  ; list of check IDs
   (roll-log       :accessor game-roll-log       :initform nil)
   ;; Settings: :hidden, :visible, or :log
   (show-rolls     :accessor game-show-rolls     :initform :hidden)))

(defmethod advance-turn ((gs game-state))
  (incf (game-dungeon-turn gs))
  (incf (game-turns-since-rest gs))
  (incf (game-turns-since-wandering-check gs)))

(defmethod check-wandering-monster ((gs game-state))
  (when (>= (game-turns-since-wandering-check gs) 2)
    (setf (game-turns-since-wandering-check gs) 0)
    (= (1+ (random 6)) 1)))

(defmethod needs-rest-p ((gs game-state))
  (>= (game-turns-since-rest gs) 6))

(defmethod log-roll ((gs game-state) roll-data)
  (push roll-data (game-roll-log gs)))
```

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

## Implementation Phases

### Phase 1: Core Engine
- [x] Character data structure and creation
- [x] Basic scene/vignette system
- [x] Choice display and selection
- [x] Simple navigation between scenes

### Phase 2: Mechanics
- [x] Dice rolling utilities
- [ ] Save system (d20 ≤ stat)
- [ ] Damage and HP/STR tracking
- [ ] Death and critical damage

### Phase 3: Exploration
- [ ] Turn tracking
- [ ] Light source duration
- [ ] Wandering monster checks
- [ ] Rest mechanics

### Phase 4: Combat
- [ ] Initiative system
- [ ] Combat choices (attack, flee, item)
- [ ] Enemy AI (simple)
- [ ] Morale checks

### Phase 5: Procedural Generation
- [ ] Room content generation
- [ ] Room exit generation
- [ ] Monster placement
- [ ] Treasure generation

### Phase 6: Oracle System
- [ ] Yes/No oracle with probability
- [ ] Twist/complication system
- [ ] Spark tables
- [ ] Random events

### Phase 7: Polish
- [ ] Roll visibility settings
- [ ] Roll log UI
- [ ] Save/load game state
- [ ] Character progression (if any)

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
