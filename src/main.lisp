(uiop:define-package #:dunge
  (:use #:cl)
  (:shadowing-import-from #:dunge/room #:room)
  (:shadowing-import-from #:dunge/item #:item)
  (:shadowing-import-from #:dunge/character #:char-name)
  (:mix-reexport #:dunge/combat
		 #:dunge/character-creation
		 #:dunge/character
		 #:dunge/data-store
		 #:dunge/utils
		 #:dunge/engine
		 #:dunge/room
		 #:dunge/item
		 #:dunge/text-layout
		 #:dunge/dice)
  
  (:shadow #:write)
  (:export #:set-vignette
	   #:push-vignette
	   #:pop-vignette

	   #:perform
	   #:menu
	   #:choice
	   #:choice-label
	   #:choice-action
	   #:execute-action

	   #:print-context
	   #:out

	   #:game-repl))

(uiop:define-package #:dunge-user
  (:mix #:cl #:dunge))

(in-package #:dunge)

;;; Start

(make-room 'start "Welcome to Dunge!"
  (exit "Continue" 'character-info))

;;; World rooms

(make-room 'town-square "Town Square"
  (p "This is the town square, the central hub of this very small, unnamed town.")
  (exit "Look at the Adventure Board" 'adventure-board :description "You see an adventure board here where the townsfolk have posted their bounties.  Perfect for an adventurer like yourself.")
  (exit "Go to the blacksmith" 'blacksmith :description "To the east you see smoke from the forge of the town blacksmith."))

(make-room 'adventure-board "Adventure Board"
  (p "The board is covered in tattered notices. One catches your eye:")
  (p "")
  (p "  \"GOBLIN SPOTTED near the old watchtower. Reward for its removal.\"")
  (p "")
  (exit "Investigate the goblin sighting" 'test-combat)
  (exit "Back" 'town-square))

;;; Combat encounter

(make-room 'test-combat "Combat!"
  ;; Setup: if combat not active, initialize the encounter
  (gate (lambda () (not (encounter-active)))
    :then (list
	   (lambda (ctx)
	     (declare (ignore ctx))
	     (setup-encounter "Goblin" 4 0 6)
	     nil)
	   (p "A goblin leaps out of the shadows!")
	   (p "")))

  ;; Show last round's results if log exists
  (gate (lambda () (let ((enc (current-encounter)))
		     (and enc (encounter-log enc))))
    :then (list
	   (lambda (ctx)
	     (let ((enc (current-encounter)))
	       (out ctx (format nil "~a~%" (encounter-log enc)))
	       (setf (encounter-log enc) nil))
	     nil)))

  ;; Victory: enemy HP <= 0
  (gate (lambda () (and (encounter-active)
			(not (enemy-alive-p))))
    :then (list
	   (lambda (ctx)
	     (declare (ignore ctx))
	     (clear-encounter)
	     nil)
	   (p "The goblin crumples to the ground. Victory!")
	   (p "")
	   (exit "Return to Adventure Board" 'adventure-board)))

  ;; Defeat: player HP <= 0
  (gate (lambda () (and (encounter-active)
			(not (player-alive-p))))
    :then (list
	   (lambda (ctx)
	     (declare (ignore ctx))
	     (setf (combatant-hp *player*) (combatant-hp-max *player*))
	     (clear-encounter)
	     nil)
	   (p "The goblin knocks you unconscious. You wake up back in town.")
	   (p "")
	   (exit "Return to Town Square" 'town-square)))

  ;; Active combat: show status and attack option
  (gate (lambda () (and (encounter-active)
			(enemy-alive-p)
			(player-alive-p)))
    :then (list
	   (lambda (ctx)
	     (let ((e (encounter-enemy (current-encounter))))
	       (out ctx (format nil "  Goblin HP: ~a/~a~%"
				(combatant-hp e)
				(combatant-hp-max e))))
	     (out ctx (format nil "  Your HP:   ~a/~a~%"
			      (combatant-hp *player*)
			      (combatant-hp-max *player*)))
	     nil)
	   (p "")
	   (lambda (ctx)
	     (declare (ignore ctx))
	     (list
	      (make-instance 'choice
		:label "Attack"
		:action (lambda ()
			  (let ((player-dmg (resolve-player-attack 6))
				(enemy-dmg (resolve-enemy-attack)))
			    (setf (encounter-log (current-encounter))
				  (format nil "You deal ~a damage. The goblin deals ~a damage."
					  player-dmg enemy-dmg)))
			  (set-vignette (room 'test-combat)))))))))


(make-room 'blacksmith "Blacksmith"
  (p "This is the blacksmith.")
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
