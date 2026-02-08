(uiop:define-package #:dunge
  (:use #:cl)
  (:shadowing-import-from #:dunge/room #:room)
  (:mix-reexport #:dunge/data-store
		 #:dunge/utils
		 #:dunge/engine
		 #:dunge/room
		 #:dunge/text-layout)
  
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

;;;;;;;;;; testing ;;;;;;;;;;;;

(make-room 'start "Welcome to Dunge!"
  (exit "Continue" 'character-info))

(make-room 'character-info "Character Creation"
  (gate (ref "character" "name")
    :then (list
	   (p "Welcome " (ref "character" "name") "!")
	   (exit "Start your adventure!" 'town-square))
    :else (list
	   (p "Let's gather some information about your character.")
	   (prompt "What is your name?"
		   :validate-fn #'validate-non-empty-string
		   :action (lambda (text)
			     (setf (lookup "character" "name") text)
			     (set-vignette (room 'character-info)))))))

(make-room 'town-square "Town Square"
  (p "This is the town square")
  (exit "Go to the blacksmith" 'blacksmith))


(make-room 'blacksmith "Blacksmith"
  (p "This is the blacksmith.")
  (exit "back to town square" 'town-square))

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
