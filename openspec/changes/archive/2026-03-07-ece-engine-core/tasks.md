## 1. Project Setup

- [x] 1.1 Create `game/` directory
- [x] 1.2 Create CL bootstrap function that sets `*default-pathname-defaults*` to project root and evaluates `(load "game/main.scm")` via ECE

## 2. Game State

- [x] 2.1 Implement `*state*` global hash table, `state-get`, `state-set!`, and `state-ref` in `game/engine.scm`

## 3. Room System

- [x] 3.1 Implement `*rooms*` registry and `define-room` macro that stores room records (title + body thunks) in the registry
- [x] 3.2 Implement `text` element that displays concatenated arguments
- [x] 3.3 Implement `exit` element that produces a choice for room navigation
- [x] 3.4 Implement `gate` element for conditional content rendering (condition, then-branch, else-branch)
- [x] 3.5 Implement `prompt` element for text input with validation and action

## 4. Choice System

- [x] 4.1 Implement choice display (numbered menu), input reading, and validation loop
- [x] 4.2 Implement guard-based choice filtering

## 5. Game Loop

- [x] 5.1 Implement `goto` function and main game loop (render room → collect choices/prompt → handle input → repeat)

## 6. Dice

- [x] 6.1 Implement `roll-die` and `roll-dice` functions in `game/dice.scm`

## 7. Game Content

- [x] 7.1 Define backgrounds data (Soldier, Scholar, Criminal, Pilgrim, Hunter, Merchant) with equipment, armor, gold
- [x] 7.2 Port character creation rooms: start, character-info (name prompt), choose-background
- [x] 7.3 Port stat rolling room with swap options
- [x] 7.4 Port HP rolling, equipment assignment, fate points rooms
- [x] 7.5 Port character summary room
- [x] 7.6 Port town rooms: town-square, adventure-board, blacksmith

## 8. Bootstrap and Verify

- [x] 8.1 Create `game/main.scm` that loads engine, dice, and content, then starts the game loop at the start room
- [x] 8.2 Verify full playthrough: character creation → town navigation works in terminal
