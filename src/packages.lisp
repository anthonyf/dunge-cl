(defpackage #:dunge
  (:use #:cl)
  (:shadow #:room #:char-name #:item)
  (:export
   ;; utils
   #:trim-whitespace
   #:validate-non-empty-string

   ;; data-store
   #:lookup
   #:*data-store*

   ;; dice
   #:roll-dice
   #:roll-d20

   ;; serialize
   #:serialize
   #:deserialize
   #:define-deserializer

   ;; text-layout
   #:nl
   #:text

   ;; engine
   #:*vignette-stack*
   #:current-vignette
   #:set-vignette
   #:perform
   #:menu
   #:choice
   #:choice-label
   #:choice-action
   #:execute-action
   #:goto-choice
   #:gosub-choice
   #:return-choice
   #:print-context
   #:out
   #:prompt
   #:prompt-question
   #:prompt-validate-fn
   #:prompt-action
   #:game-repl

   ;; room
   #:room
   #:room-id
   #:make-room
   #:exit
   #:gate
   #:group
   #:p
   #:room-local
   #:local-ref
   #:set-lookup

   ;; item
   #:item
   #:item-name
   #:item-display-name
   #:item-actions
   #:stackable
   #:item-stack-limit
   #:item-quantity
   #:usable-p
   #:item-use-label
   #:weapon
   #:weapon-item
   #:item-damage-die
   #:consumable
   #:consume
   #:healing-herb
   #:stackable-item
   #:consume-item
   #:make-item

   ;; character
   #:combatant
   #:combatant-hp
   #:combatant-hp-max
   #:combatant-armor
   #:combatant-str
   #:combatant-dex
   #:combatant-wil
   #:player-character
   #:char-name
   #:char-background
   #:char-gold
   #:char-fate
   #:char-inventory
   #:*player*
   #:player-ref
   #:str-save
   #:dex-save
   #:wil-save

   ;; character-creation
   #:character-info
   #:quick-start
   #:town-square

   ;; combat
   #:enemy
   #:encounter
   #:encounter-active-p
   #:encounter-first-round-p
   #:encounter-log
   #:encounter-state
   #:combat-encounter

   ;; bestiary
   #:make-goblin
   #:make-skeleton
   #:make-zombie
   #:make-kobold
   #:make-bandit
   #:make-viper
   #:make-cave-locust
   #:make-acolyte
   #:make-gnoll
   #:make-hobgoblin
   #:make-bugbear
   #:make-ghoul
   #:make-ogre
   #:make-werewolf
   #:make-harpy
   #:make-rust-monster
   #:make-troll
   #:make-owlbear
   #:make-basilisk
   #:make-wight
   #:make-gargoyle
   #:make-minotaur
   #:make-wyvern
   #:make-vampire
   #:make-green-dragon
   #:make-lich
   #:make-eye-of-terror
   #:make-hydra
   #:make-mind-lasher
   #:make-purple-worm
   #:make-sphinx
   #:make-storm-giant
   #:make-titan

   ;; container
   #:make-container))

(defpackage #:dunge-user
  (:use #:cl #:dunge)
  (:shadowing-import-from #:dunge #:room #:char-name #:item))
