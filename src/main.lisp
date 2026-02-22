(in-package #:dunge)

;;; Start

(make-room 'start "Welcome to Dunge!"
           (p "A text-based dungeon crawler. Prepare to explore, fight, and survive.")
           (exit "Quick Start (random character)" 'quick-start)
           (exit "Create a custom character" 'character-info))

;;; World rooms

(make-room 'town-square "Town Square"
           (run-once (init-overflow-menu))
           (set-lookup "game" "save-enabled" t)
           (p "This is the town square, the central hub of this very small, unnamed town.")
           (exit "Look at the Adventure Board" 'adventure-board :description "You see an adventure board here where the townsfolk have posted their bounties.  Perfect for an adventurer like yourself.")
           (exit "Go to the blacksmith" 'blacksmith :description "To the east you see smoke from the forge of the town blacksmith."))

(make-room 'adventure-board "Adventure Board"
           (p "The board is covered in tattered notices. One catches your eye:")
           (p "  \"GOBLIN SPOTTED near the old watchtower. Reward for its removal.\"")
           (exit "Investigate the goblin sighting" 'test-combat)
           (exit "Back" 'town-square))

;;; Combat encounter

(make-room 'test-combat "Combat!"
           (combat-encounter
            :enemy (make-enemy "Goblin")
            :intro (p "A goblin leaps out of the shadows!")
            :victory (group
                      (p "The goblin crumples to the ground. Victory!")
                      (exit "Return to Adventure Board" 'adventure-board))
            :death (group
                    (p "Your wounds are fatal. You collapse and breathe your last.")
                    (exit "Return to Town Square" 'town-square))
            :incapacitated (group
                            (p "You fall unconscious from your wounds. You wake up back in town, battered but alive.")
                            (exit "Return to Town Square" 'town-square))
            :fled (group
                   (p "You flee the scene, putting distance between you and the goblin.")
                   (exit "Return to Adventure Board" 'adventure-board))))


(make-room 'blacksmith "Blacksmith"
           (p "The forge glows hot. Weapons and armor line the walls.")
           (make-container "Storage Chest" "An old wooden chest sits in the corner, its iron hinges rusted with age." "Open the chest"
                           (list
                            (p "Inside the chest you find:")
                            (p "  - A rusty key")
                            (p "  - A tattered map")))
           (exit "Return to town square" 'town-square))

#+nil(defun run-game ()
       (game
        (text "Your majesty, your people are starving in the streets, and threaten revolution.
Our enemies to the west are weak, but they threaten soon to invade.  What will you do?")

        (choice
         ("Make pre-emptive war on the western lands."
          (text "If you can seize their territory, your kingdom will flourish.  But your army's morale is low and the kingdom's armory is empty.  How will you win the war?")
          (choice
           ("Drive the peasants like slaves"
            ;; if we work hard enough, we'll win.
            (text "Unfortunately, morale doesn't work like that.  Your army soon turns against you and the kingdom falls to the western barbarians.")
            (finish))
           ("Appoint charismatic knights and give them land, peasants, and resources."
            (text "Your majesty's people are eminently resourceful.  Your knights win the day, but take care: they may soon demand a convention of parliament.")
            (finish))
           ("Steal food and weapons from the enemy in the dead of night."
            (text "A cunning plan.  Soon your army is a match for the westerners; they choose not to invade for now, but how long can your majesty postpone the inevitable?")
            (finish))))
         ("Beat swords to plowshares and trade food to the westerners for protection."
          (text "The westerners have you at the point of a sword.  They demand unfair terms from you.")
          (choice
           ("Accept the terms for now."
            (text "Eventually, the barbarian westerners conquer you anyway, destroying their bread basket, and the entire region starves.")
            (finish))
           ("Threaten to salt our fields if they don't offer better terms."
            (text "They blink.  Your majesty gets a fair price for wheat.")
            (finish))))
         ("Abdicate the throne. I have clearly mismanaged this kingdom!"
          (text "The kingdom descends into chaos, but you manage to escape with your own hide.  Perhaps in time you can return to restore order to this fair land.")
          (finish)))))
