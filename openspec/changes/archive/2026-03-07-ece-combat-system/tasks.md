## 1. Dice and Saves

- [x] 1.1 Add `roll-d20` to `game/dice.scm`
- [x] 1.2 Implement `str-save`, `dex-save`, `wil-save` in `game/combat.scm` using generic `(hash-ref target 'str)` for both character and enemy records

## 2. Enemy and Encounter Records

- [x] 2.1 Define `enemy` record (name hp hp-max armor str dex wil attack-die) in `game/combat.scm`
- [x] 2.2 Define `encounter` record (enemy first-round log state) in `game/combat.scm`
- [x] 2.3 Add `*current-encounter*` global and `setup-encounter` / `clear-encounter` helpers

## 3. Attack Resolution

- [x] 3.1 Implement `resolve-attack` — roll damage die, subtract armor, apply HP damage, spillover to STR, critical save, death check. Returns hash table with damage/str-damage/critical-save/dead.
- [x] 3.2 Implement `resolve-player-attack` and `resolve-enemy-attack` wrappers

## 4. Heal and Flee

- [x] 4.1 Implement `resolve-heal` — restore player HP to max, return hash table with healed/old-hp/new-hp
- [x] 4.2 Implement `resolve-flee` — DEX save, parting blow on failure

## 5. Combat Log Formatting

- [x] 5.1 Implement `format-player-attack-lines`, `format-enemy-attack-lines` (return list of strings)
- [x] 5.2 Implement `format-combat-log`, `format-heal-log`, `format-flee-log`

## 6. Encounter State Machine

- [x] 6.1 Implement `update-encounter-state` — determine victory/death/incapacitated/fled/active from round results
- [x] 6.2 Implement `combat-choices` — scan player inventory, build attack/consume/unarmed/flee choices
- [x] 6.3 Implement `cleanup-combat` — reset player stats after death/incapacitation, clear encounter

## 7. Combat Encounter Element

- [x] 7.1 Add `combat-encounter` macro to engine.scm for room definitions
- [x] 7.2 Add `'combat-encounter` case to `render-element` in engine.scm — handle setup, first-round DEX save, active combat choices, and terminal state outcomes

## 8. Bestiary

- [x] 8.1 Create `game/bestiary.scm` with ~33 enemies across 4 tiers
- [x] 8.2 Implement `make-enemy-from-bestiary` lookup function

## 9. Content and Bootstrap

- [x] 9.1 Add test-combat room to content.scm (Goblin encounter with intro/victory/death/incapacitated/fled outcomes), wire into town adventure board
- [x] 9.2 Add `(load "game/combat.scm")` and `(load "game/bestiary.scm")` to main.scm
- [x] 9.3 Test full playthrough — character creation → town → adventure board → goblin fight → victory/death paths
