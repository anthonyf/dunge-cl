(uiop:define-package #:dunge
  (:use #:cl)
  (:shadowing-import-from #:dunge/room #:room)
  (:mix-reexport #:dunge/data-store
		 #:dunge/utils
		 #:dunge/engine
		 #:dunge/room
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

;;; Background data

(defparameter *backgrounds*
  '(("Soldier"  :description "trained in combat, disciplined"
		:equipment ("Sword (d8)" "Gambeson (Armor 1)" "Helm (+1 Armor)")
		:armor 2  :gold 8)
    ("Scholar"  :description "educated, curious, physically weak"
		:equipment ("Spellbook" "Dagger (d6)" "Ink & Quill")
		:armor 0  :gold 8)
    ("Criminal" :description "streetwise, light-fingered, untrustworthy"
		:equipment ("Lockpicks" "Dagger (d6)" "Dark Cloak" "Grappling Hook")
		:armor 0  :gold 8)
    ("Pilgrim"  :description "faithful, traveled, poor"
		:equipment ("Staff (d6)" "Holy Symbol" "Healing Herbs x3")
		:armor 0  :gold 8)
    ("Hunter"   :description "survivalist, patient, rural"
		:equipment ("Bow (d6)" "Arrows" "Knife (d6)" "Snare Kit" "Furs")
		:armor 0  :gold 8)
    ("Merchant" :description "wealthy, connected, soft"
		:equipment ("Dagger (d6)" "Fine Clothes")
		:armor 0  :gold 38)))

(defun background-prop (name prop)
  (getf (cdr (assoc name *backgrounds* :test #'string=)) prop))

;;; Character creation rooms

(make-room 'start "Welcome to Dunge!"
  (exit "Continue" 'character-info))

(make-room 'character-info "Character Creation"
  (gate (ref "character" "name")
    :then (list
	   (p "Welcome " (ref "character" "name") "!")
	   (exit "Continue" 'choose-background))
    :else (list
	   (p "Let's gather some information about your character.")
	   (prompt "What is your name?"
		   :validate :non-empty-string
		   :store '("character" "name")
		   :goto 'character-info))))

(make-room 'choose-background "Choose Your Background"
  (p "Your background determines your starting equipment and skills.")
  (p "")
  (lambda (ctx)
    (declare (ignore ctx))
    (loop for (bg-name . props) in *backgrounds*
	  collect (let ((n bg-name))
		    (make-instance 'choice
		      :label (format nil "~a - ~a" n (getf props :description))
		      :action (lambda ()
				(setf (lookup "character" "background") n)
				(set-vignette (room 'roll-stats))))))))

(make-room 'roll-stats "Roll Ability Scores"
  (gate (ref "character" "stats-rolled")
    :else (list
	   (lambda (ctx)
	     (declare (ignore ctx))
	     (setf (lookup "character" "str") (apply #'+ (roll-dice 6 6 6)))
	     (setf (lookup "character" "dex") (apply #'+ (roll-dice 6 6 6)))
	     (setf (lookup "character" "wil") (apply #'+ (roll-dice 6 6 6)))
	     (setf (lookup "character" "stats-rolled") t)
	     nil)))
  (p "You rolled:")
  (p "  STR: " (ref "character" "str"))
  (p "  DEX: " (ref "character" "dex"))
  (p "  WIL: " (ref "character" "wil"))
  (p "")
  (p "You may swap two ability scores, or keep them as they are.")
  (lambda (ctx)
    (declare (ignore ctx))
    (let ((str (lookup "character" "str"))
	  (dex (lookup "character" "dex"))
	  (wil (lookup "character" "wil")))
      (list
       (make-instance 'choice
	 :label (format nil "Swap STR (~a) and DEX (~a)" str dex)
	 :action (lambda ()
		   (setf (lookup "character" "str") dex)
		   (setf (lookup "character" "dex") str)
		   (set-vignette (room 'roll-hp))))
       (make-instance 'choice
	 :label (format nil "Swap STR (~a) and WIL (~a)" str wil)
	 :action (lambda ()
		   (setf (lookup "character" "str") wil)
		   (setf (lookup "character" "wil") str)
		   (set-vignette (room 'roll-hp))))
       (make-instance 'choice
	 :label (format nil "Swap DEX (~a) and WIL (~a)" dex wil)
	 :action (lambda ()
		   (setf (lookup "character" "dex") wil)
		   (setf (lookup "character" "wil") dex)
		   (set-vignette (room 'roll-hp))))
       (make-instance 'choice
	 :label "Keep as they are"
	 :action (lambda ()
		   (set-vignette (room 'roll-hp))))))))

(make-room 'roll-hp "Roll Hit Points"
  (gate (ref "character" "hp-rolled")
    :else (list
	   (lambda (ctx)
	     (declare (ignore ctx))
	     (let ((hp (first (roll-dice 6))))
	       (setf (lookup "character" "hp") hp)
	       (setf (lookup "character" "hp-max") hp)
	       (setf (lookup "character" "hp-rolled") t))
	     nil)))
  (p "Your hit points: " (ref "character" "hp"))
  (exit "Continue" 'equipment))

(make-room 'equipment "Equipment"
  (gate (ref "character" "equipped")
    :else (list
	   (lambda (ctx)
	     (declare (ignore ctx))
	     (let* ((bg (lookup "character" "background"))
		    (items (append (background-prop bg :equipment)
				   '("Rations x3" "Torch x2" "Waterskin"))))
	       (setf (lookup "character" "inventory") items)
	       (setf (lookup "character" "armor") (background-prop bg :armor))
	       (setf (lookup "character" "gold") (background-prop bg :gold))
	       (setf (lookup "character" "equipped") t))
	     nil)))
  (p "As a " (ref "character" "background") " you receive:")
  (p "")
  (lambda (ctx)
    (dolist (item (lookup "character" "inventory"))
      (out ctx (format nil "  - ~a~%" item)))
    nil)
  (p "")
  (lambda (ctx)
    (out ctx (format nil "  Armor: ~a~%" (lookup "character" "armor")))
    (out ctx (format nil "  Gold:  ~a~%" (lookup "character" "gold")))
    nil)
  (p "")
  (exit "Continue" 'fate-points))

(make-room 'fate-points "Fate Points"
  (gate (ref "character" "fate")
    :else (list
	   (lambda (ctx)
	     (declare (ignore ctx))
	     (setf (lookup "character" "fate") 2)
	     nil)))
  (p "You begin with 2 Fate Points.")
  (p "Fate Points can be spent to narrowly avoid death or reroll a critical save.")
  (p "Use them wisely — they are hard to come by.")
  (exit "Continue" 'character-summary))

(make-room 'character-summary "Character Summary"
  (lambda (ctx)
    (out ctx (format nil "  Name:       ~a~%" (lookup "character" "name")))
    (out ctx (format nil "  Background: ~a~%" (lookup "character" "background")))
    (out ctx (format nil "~%"))
    (out ctx (format nil "  STR: ~a   DEX: ~a   WIL: ~a~%"
		     (lookup "character" "str")
		     (lookup "character" "dex")
		     (lookup "character" "wil")))
    (out ctx (format nil "~%"))
    (out ctx (format nil "  HP:    ~a/~a~%"
		     (lookup "character" "hp")
		     (lookup "character" "hp-max")))
    (out ctx (format nil "  Armor: ~a~%" (lookup "character" "armor")))
    (out ctx (format nil "  Gold:  ~a~%" (lookup "character" "gold")))
    (out ctx (format nil "  Fate:  ~a~%" (lookup "character" "fate")))
    (out ctx (format nil "~%"))
    (out ctx (format nil "  Inventory:~%"))
    (dolist (item (lookup "character" "inventory"))
      (out ctx (format nil "    - ~a~%" item)))
    nil)
  (p "")
  (exit "Begin your adventure!" 'town-square))

(make-room 'town-square "Town Square"
  (p "This is the town square, the central hub of this very small, unnamed town.")
  (exit "Look at the Adventure Board" 'adventure-board :description "You see an adventure board here where the townsfolk have posted their bounties.  Perfect for an adventurer like yourself.")
  (exit "Go to the blacksmith" 'blacksmith :description "To the east you see smoke from the forge of the town blacksmith."))

(make-room 'adventure-board "Adventure Board"
  (p "Todo random adventures will be generated and posted here.")
  (exit "Back" 'town-square))


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
