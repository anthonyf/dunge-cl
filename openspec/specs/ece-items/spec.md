## ADDED Requirements

### Requirement: Item types are defined as ECE records
The system SHALL define records for: `item` (name), `weapon` (name, damage-die), `stackable-item` (name, quantity, stack-limit), and `healing-herb` (quantity, stack-limit).

#### Scenario: Create a plain item
- **WHEN** `(make-item "Lockpicks")` is called
- **THEN** `(item? result)` SHALL be true and `(item-name result)` SHALL return "Lockpicks"

#### Scenario: Create a weapon
- **WHEN** `(make-weapon "Sword" 8)` is called
- **THEN** `(weapon? result)` SHALL be true and `(weapon-damage-die result)` SHALL return 8

#### Scenario: Create a stackable item
- **WHEN** `(make-stackable-item "Rations" 3 10)` is called
- **THEN** `(stackable-item? result)` SHALL be true and `(stackable-item-quantity result)` SHALL return 3

#### Scenario: Create a healing herb
- **WHEN** `(make-healing-herb 3 10)` is called
- **THEN** `(healing-herb? result)` SHALL be true and `(healing-herb-quantity result)` SHALL return 3

### Requirement: item-display-name formats names by type
The system SHALL provide an `item-display-name` function that returns a human-readable string based on item type.

#### Scenario: Plain item display
- **WHEN** `(item-display-name (make-item "Lockpicks"))` is called
- **THEN** the result SHALL be "Lockpicks"

#### Scenario: Weapon display includes damage die
- **WHEN** `(item-display-name (make-weapon "Sword" 8))` is called
- **THEN** the result SHALL be "Sword (d8)"

#### Scenario: Stackable display includes quantity when > 1
- **WHEN** `(item-display-name (make-stackable-item "Rations" 3 10))` is called
- **THEN** the result SHALL be "Rations x3"

#### Scenario: Stackable display omits quantity when 1
- **WHEN** `(item-display-name (make-stackable-item "Torch" 1 5))` is called
- **THEN** the result SHALL be "Torch"

#### Scenario: Healing herb display
- **WHEN** `(item-display-name (make-healing-herb 3 10))` is called
- **THEN** the result SHALL be "Healing Herbs x3"

### Requirement: usable? identifies combat-usable items
The system SHALL provide a `usable?` function that returns true for weapons and healing herbs, nil for other items.

#### Scenario: Weapon is usable
- **WHEN** `(usable? (make-weapon "Sword" 8))` is called
- **THEN** the result SHALL be true

#### Scenario: Plain item is not usable
- **WHEN** `(usable? (make-item "Lockpicks"))` is called
- **THEN** the result SHALL be nil

### Requirement: item-use-label provides combat choice text
The system SHALL provide an `item-use-label` function that returns choice text for using an item in combat.

#### Scenario: Weapon use label
- **WHEN** `(item-use-label (make-weapon "Sword" 8))` is called
- **THEN** the result SHALL be "Attack with Sword (d8)"

#### Scenario: Healing herb use label
- **WHEN** `(item-use-label (make-healing-herb 3 10))` is called
- **THEN** the result SHALL be "Use Healing Herbs x3"

### Requirement: consume-item decrements or removes items
The system SHALL provide a `consume-item` function that decrements stackable quantity and removes items from inventory when exhausted.

#### Scenario: Consume one of a stack
- **WHEN** `(consume-item herb inventory)` is called on a healing-herb with quantity 3
- **THEN** the herb's quantity SHALL be 2 and the inventory SHALL still contain the herb

#### Scenario: Consume last of a stack
- **WHEN** `(consume-item herb inventory)` is called on a healing-herb with quantity 1
- **THEN** the herb SHALL be removed from the returned inventory

#### Scenario: Consume non-stackable item
- **WHEN** `(consume-item item inventory)` is called on a plain item
- **THEN** the item SHALL be removed from the returned inventory
