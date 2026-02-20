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
   #:run-once
   #:set-lookup

   ;; item
   #:item
   #:item-name
   #:item-display-name
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
   #:print-character-sheet
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
   #:encounter-first-round-p
   #:encounter-log
   #:encounter-state
   #:combat-encounter

   ;; bestiary
   #:*bestiary*
   #:make-enemy

   ;; container
   #:make-container

   ;; overflow
   #:*overflow-choices*
   #:init-overflow-menu
   #:append-overflow-choice))

(defpackage #:dunge-user
  (:use #:cl #:dunge)
  (:shadowing-import-from #:dunge #:room #:char-name #:item))
