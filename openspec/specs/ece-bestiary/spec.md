## ADDED Requirements

### Requirement: Bestiary contains enemy data
The system SHALL maintain a bestiary list of enemy definitions with name, hp, armor, attack-die, str, dex, and wil stats.

#### Scenario: Bestiary has enemies across tiers
- **WHEN** the bestiary is loaded
- **THEN** it SHALL contain enemies from Tier 1 (Goblin, Skeleton, etc.), Tier 2 (Gnoll, Ogre, etc.), Tier 3 (Troll, Vampire, etc.), and Bosses (Dragon, Lich, etc.)

### Requirement: Enemy lookup by name
The system SHALL provide a function to look up an enemy by name and create an enemy record from the bestiary data.

#### Scenario: Look up Goblin
- **WHEN** `(make-enemy-from-bestiary "Goblin")` is called
- **THEN** it SHALL return an enemy record with hp 4, armor 0, attack-die 6, str 8, dex 12, wil 8
