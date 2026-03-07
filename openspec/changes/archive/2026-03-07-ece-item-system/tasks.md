## 1. Item Records

- [x] 1.1 Create `game/items.scm` with `define-record` for `item`, `weapon`, `stackable-item`, and `healing-herb`
- [x] 1.2 Implement `item-display-name` with type-dispatched formatting (weapon "Name (dN)", stackable "Name xN", healing herb, plain)
- [x] 1.3 Implement `usable?` (true for weapons and healing herbs) and `item-use-label` (combat choice text)
- [x] 1.4 Implement `consume-item` that decrements stackable quantity and removes exhausted items from inventory

## 2. Update Backgrounds

- [x] 2.1 Update `*backgrounds*` in content.scm to produce real item objects (weapons with damage-die, plain items, healing herbs) instead of strings
- [x] 2.2 Add `base-equipment` function returning stackable Rations, Torch, and plain Waterskin

## 3. Update Content

- [x] 3.1 Update equipment room to use `item-display-name` for inventory display
- [x] 3.2 Update character-summary room to use `item-display-name` for inventory display

## 4. Bootstrap and Verify

- [x] 4.1 Add `(load "game/items.scm")` to main.scm (before content.scm)
- [x] 4.2 Test full playthrough — verify item display names show correctly (e.g., "Sword (d8)", "Healing Herbs x3", "Rations x3")
