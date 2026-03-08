## MODIFIED Requirements

### Requirement: Inventory display uses item-display-name
The character summary and equipment rooms SHALL display items using `item-display-name` instead of raw strings. Display functions SHALL use ECE string interpolation and the `lines` function for multi-line output blocks.

#### Scenario: Equipment room shows formatted items
- **WHEN** the equipment room renders a Pilgrim's inventory
- **THEN** it SHALL display "Staff (d6)", "Holy Symbol", "Healing Herbs x3", "Rations x3", "Torch x2", "Waterskin"

#### Scenario: Character summary uses lines for stat block
- **WHEN** the character summary is displayed
- **THEN** it SHALL render name, background, stats, HP, armor, gold, fate, and inventory using `lines` and string interpolation, producing identical output to the current implementation
