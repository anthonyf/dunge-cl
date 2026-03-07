## ADDED Requirements

### Requirement: Name entry
The character creation flow SHALL prompt the player for a name and store it in game state.

#### Scenario: Player enters a name
- **WHEN** the player is at the character-info room and enters "Aragorn"
- **THEN** `(state-get 'character 'name)` SHALL return "Aragorn" and the game SHALL proceed

#### Scenario: Returning with name already set
- **WHEN** the player returns to character-info and a name is already stored
- **THEN** the room SHALL greet them by name and offer to continue

### Requirement: Background selection
The game SHALL present a list of backgrounds (Soldier, Scholar, Criminal, Pilgrim, Hunter, Merchant) with descriptions. The player's selection SHALL be stored in game state.

#### Scenario: Player chooses a background
- **WHEN** the player selects "Soldier" from the background menu
- **THEN** `(state-get 'character 'background)` SHALL be "Soldier"

### Requirement: Stat rolling
The game SHALL roll 3d6 for each of STR, DEX, and WIL. The player SHALL be offered the option to swap any two stats or keep them.

#### Scenario: Stats are rolled
- **WHEN** the player reaches the stat rolling room
- **THEN** three stats (STR, DEX, WIL) SHALL be rolled as 3d6 sums and displayed

#### Scenario: Player swaps two stats
- **WHEN** the player chooses to swap STR and DEX
- **THEN** the values of STR and DEX SHALL be exchanged in game state

### Requirement: HP rolling
The game SHALL roll 1d6 for hit points and store both current and max HP.

#### Scenario: HP is rolled and stored
- **WHEN** the player reaches the HP room
- **THEN** a d6 SHALL be rolled and stored as both `hp` and `hp-max` in game state

### Requirement: Equipment assignment
The game SHALL assign starting equipment based on the chosen background, plus universal items (rations, torches, waterskin). Equipment, armor, and gold SHALL be stored in game state.

#### Scenario: Soldier receives combat equipment
- **WHEN** the player chose "Soldier" background
- **THEN** equipment SHALL include "Sword (d8)", "Gambeson (Armor 1)", "Helm (+1 Armor)" plus universal items

### Requirement: Fate points assignment
The game SHALL assign 2 fate points and display explanatory text.

#### Scenario: Fate points set
- **WHEN** the player reaches the fate points room
- **THEN** `(state-get 'character 'fate)` SHALL be 2

### Requirement: Character summary
The game SHALL display a full summary of the created character including name, background, stats, HP, armor, gold, fate, and inventory.

#### Scenario: Summary displays all character data
- **WHEN** the player reaches the summary room
- **THEN** all character attributes (name, background, STR, DEX, WIL, HP, armor, gold, fate, inventory) SHALL be displayed

### Requirement: Town navigation
After character creation, the player SHALL enter a town square with exits to an adventure board and blacksmith, each with return navigation.

#### Scenario: Town square has exits
- **WHEN** the player is in the town square
- **THEN** choices SHALL include "Look at the Adventure Board" and "Go to the blacksmith"
