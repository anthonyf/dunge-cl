## Why

Character creation currently stores inventory as flat strings (`"Sword (d8)"`, `"Healing Herbs x3"`). The CL engine has a full CLOS item system with weapon damage dice, stackable quantities, consumables, and display name formatting. To support combat in ECE, items need to be real objects with typed behavior — weapons need damage dice, stackable items need quantities, and consumables need use/consume logic.

## What Changes

- Define ECE records for item types: `item`, `weapon`, `stackable-item`, `healing-herb`
- Implement `item-display-name` dispatching on item type (base name, weapon "Name (dN)", stackable "Name xN")
- Implement `usable?` and `item-use-label` for combat integration
- Implement `consume-item` that decrements stackable quantity and removes depleted items
- Create item constructor helpers: `make-item`, `make-weapon`, `make-healing-herb`
- Update backgrounds to produce real item objects instead of strings
- Update character creation and inventory display to use `item-display-name`
- Add `game/items.scm` for the item system

## Capabilities

### New Capabilities
- `ece-items`: Item records with type-based display, usage, and consumption behavior

### Modified Capabilities
- `ece-character-creation`: Backgrounds produce real item objects instead of strings; inventory display uses `item-display-name`

## Impact

- New file: `game/items.scm`
- Modified: `game/content.scm` — backgrounds, equipment room, character summary, inventory display
- Modified: `game/main.scm` — load items.scm
