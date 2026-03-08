## MODIFIED Requirements

### Requirement: Backgrounds produce starting equipment
Each background SHALL be a `background` record with fields: name, description, equipment-thunk, armor, and gold. The equipment-thunk SHALL return a list of item records. Common base equipment (Rations x3, Torch x2, Waterskin) SHALL also be real item objects.

#### Scenario: Soldier background equipment
- **WHEN** the Soldier background equipment is generated
- **THEN** it SHALL include a weapon "Sword" with damage-die 8, and plain items "Gambeson (Armor 1)" and "Helm (+1 Armor)"

#### Scenario: Pilgrim background includes healing herbs
- **WHEN** the Pilgrim background equipment is generated
- **THEN** it SHALL include a healing-herb with quantity 3

#### Scenario: Base equipment is stackable
- **WHEN** base equipment is generated for any background
- **THEN** Rations SHALL be a stackable-item with quantity 3 and Torch SHALL be a stackable-item with quantity 2

#### Scenario: Background accessed by record accessor
- **WHEN** a background record is retrieved
- **THEN** its fields SHALL be accessible via `background-name`, `background-description`, `background-equipment-thunk`, `background-armor`, and `background-gold`
