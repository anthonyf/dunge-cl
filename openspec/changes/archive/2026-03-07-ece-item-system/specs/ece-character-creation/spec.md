## MODIFIED Requirements

### Requirement: Backgrounds produce starting equipment
Each background SHALL define an equipment function that returns a list of item records (weapons, stackable items, plain items, healing herbs) instead of plain strings. Common base equipment (Rations x3, Torch x2, Waterskin) SHALL also be real item objects.

#### Scenario: Soldier background equipment
- **WHEN** the Soldier background equipment is generated
- **THEN** it SHALL include a weapon "Sword" with damage-die 8, and plain items "Gambeson (Armor 1)" and "Helm (+1 Armor)"

#### Scenario: Pilgrim background includes healing herbs
- **WHEN** the Pilgrim background equipment is generated
- **THEN** it SHALL include a healing-herb with quantity 3

#### Scenario: Base equipment is stackable
- **WHEN** base equipment is generated for any background
- **THEN** Rations SHALL be a stackable-item with quantity 3 and Torch SHALL be a stackable-item with quantity 2

### Requirement: Inventory display uses item-display-name
The character summary and equipment rooms SHALL display items using `item-display-name` instead of raw strings.

#### Scenario: Equipment room shows formatted items
- **WHEN** the equipment room renders a Pilgrim's inventory
- **THEN** it SHALL display "Staff (d6)", "Holy Symbol", "Healing Herbs x3", "Rations x3", "Torch x2", "Waterskin"
