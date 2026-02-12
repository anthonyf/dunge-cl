(uiop:define-package #:dunge/character-creation
  (:use #:cl)
  (:shadowing-import-from #:dunge/room #:room)
  (:shadowing-import-from #:dunge/character #:char-name)
  (:mix #:dunge/room
	#:dunge/item
	#:dunge/character
	#:dunge/engine
	#:dunge/dice)
  (:export #:character-info
	   #:town-square))

(in-package #:dunge/character-creation)

;;; Background data

(defparameter *backgrounds*
  (list
   (list "Soldier"  :description "trained in combat, disciplined"
	 :equipment (lambda ()
		      (list (weapon "Sword" :damage-die 8)
			    (make-item "Gambeson (Armor 1)")
			    (make-item "Helm (+1 Armor)")))
	 :armor 2  :gold 8)
   (list "Scholar"  :description "educated, curious, physically weak"
	 :equipment (lambda ()
		      (list (make-item "Spellbook")
			    (weapon "Dagger" :damage-die 6)
			    (make-item "Ink & Quill")))
	 :armor 0  :gold 8)
   (list "Criminal" :description "streetwise, light-fingered, untrustworthy"
	 :equipment (lambda ()
		      (list (make-item "Lockpicks")
			    (weapon "Dagger" :damage-die 6)
			    (make-item "Dark Cloak")
			    (make-item "Grappling Hook")))
	 :armor 0  :gold 8)
   (list "Pilgrim"  :description "faithful, traveled, poor"
	 :equipment (lambda ()
		      (list (weapon "Staff" :damage-die 6)
			    (make-item "Holy Symbol")
			    (healing-herb :quantity 3)))
	 :armor 0  :gold 8)
   (list "Hunter"   :description "survivalist, patient, rural"
	 :equipment (lambda ()
		      (list (weapon "Bow" :damage-die 6)
			    (make-item "Arrows")
			    (weapon "Knife" :damage-die 6)
			    (make-item "Snare Kit")
			    (make-item "Furs")))
	 :armor 0  :gold 8)
   (list "Merchant" :description "wealthy, connected, soft"
	 :equipment (lambda ()
		      (list (weapon "Dagger" :damage-die 6)
			    (make-item "Fine Clothes")))
	 :armor 0  :gold 38)))

(defun background-prop (name prop)
  (getf (cdr (assoc name *backgrounds* :test #'string=)) prop))

;;; Character creation rooms

(make-room 'character-info "Character Creation"
  (gate (player-ref #'char-name)
    :then (list
	   (p "Welcome " (player-ref #'char-name) "!")
	   (exit "Continue" 'choose-background))
    :else (list
	   (p "Let's gather some information about your character.")
	   (prompt "What is your name?"
		   :validate :non-empty-string
		   :action (lambda (input)
			     (setf *player* (make-instance 'player-character :name input)))
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
				(setf (char-background *player*) n)
				(set-vignette (room 'roll-stats))))))))

(make-room 'roll-stats "Roll Ability Scores"
  (gate (local-ref "stats-rolled")
    :else (list
	   (lambda (ctx)
	     (declare (ignore ctx))
	     (setf (combatant-str *player*) (apply #'+ (roll-dice 6 6 6)))
	     (setf (combatant-dex *player*) (apply #'+ (roll-dice 6 6 6)))
	     (setf (combatant-wil *player*) (apply #'+ (roll-dice 6 6 6)))
	     (setf (room-local "stats-rolled") t)
	     nil)))
  (p "You rolled:")
  (p "  STR: " (player-ref #'combatant-str))
  (p "  DEX: " (player-ref #'combatant-dex))
  (p "  WIL: " (player-ref #'combatant-wil))
  (p "")
  (p "You may swap two ability scores, or continue.")
  (lambda (ctx)
    (declare (ignore ctx))
    (let ((str (combatant-str *player*))
	  (dex (combatant-dex *player*))
	  (wil (combatant-wil *player*)))
      (list
       (make-instance 'choice
	 :label (format nil "Swap STR (~a) and DEX (~a)" str dex)
	 :action (lambda ()
		   (setf (combatant-str *player*) dex)
		   (setf (combatant-dex *player*) str)
		   (set-vignette (room 'roll-stats))))
       (make-instance 'choice
	 :label (format nil "Swap STR (~a) and WIL (~a)" str wil)
	 :action (lambda ()
		   (setf (combatant-str *player*) wil)
		   (setf (combatant-wil *player*) str)
		   (set-vignette (room 'roll-stats))))
       (make-instance 'choice
	 :label (format nil "Swap DEX (~a) and WIL (~a)" dex wil)
	 :action (lambda ()
		   (setf (combatant-dex *player*) wil)
		   (setf (combatant-wil *player*) dex)
		   (set-vignette (room 'roll-stats))))
       (make-instance 'choice
	 :label "Continue"
	 :action (lambda ()
		   (set-vignette (room 'roll-hp))))))))

(make-room 'roll-hp "Roll Hit Points"
  (gate (local-ref "hp-rolled")
    :else (list
	   (lambda (ctx)
	     (declare (ignore ctx))
	     (let ((hp (first (roll-dice 6))))
	       (setf (combatant-hp *player*) hp)
	       (setf (combatant-hp-max *player*) hp)
	       (setf (room-local "hp-rolled") t))
	     nil)))
  (p "Your hit points: " (player-ref #'combatant-hp))
  (exit "Continue" 'equipment))

(make-room 'equipment "Equipment"
  (gate (local-ref "equipped")
    :else (list
	   (lambda (ctx)
	     (declare (ignore ctx))
	     (let* ((bg (char-background *player*))
		    (items (append (funcall (background-prop bg :equipment))
				   (list (make-item "Rations" :stackable t :stack-limit 10 :quantity 3)
					 (make-item "Torch" :stackable t :stack-limit 5 :quantity 2)
					 (make-item "Waterskin")))))
	       (setf (char-inventory *player*) items)
	       (setf (combatant-armor *player*) (background-prop bg :armor))
	       (setf (char-gold *player*) (background-prop bg :gold))
	       (setf (room-local "equipped") t))
	     nil)))
  (p "As a " (player-ref #'char-background) " you receive:")
  (p "")
  (lambda (ctx)
    (dolist (i (char-inventory *player*))
      (out ctx (format nil "  - ~a~%" (item-display-name i))))
    nil)
  (p "")
  (lambda (ctx)
    (out ctx (format nil "  Armor: ~a~%" (combatant-armor *player*)))
    (out ctx (format nil "  Gold:  ~a~%" (char-gold *player*)))
    nil)
  (p "")
  (exit "Continue" 'fate-points))

(make-room 'fate-points "Fate Points"
  (gate (local-ref "fate-set")
    :else (list
	   (lambda (ctx)
	     (declare (ignore ctx))
	     (setf (char-fate *player*) 2)
	     (setf (room-local "fate-set") t)
	     nil)))
  (p "You begin with 2 Fate Points.")
  (p "Fate Points can be spent to narrowly avoid death or reroll a critical save.")
  (p "Use them wisely — they are hard to come by.")
  (exit "Continue" 'character-summary))

(make-room 'character-summary "Character Summary"
  (lambda (ctx)
    (out ctx (format nil "  Name:       ~a~%" (char-name *player*)))
    (out ctx (format nil "  Background: ~a~%" (char-background *player*)))
    (out ctx (format nil "~%"))
    (out ctx (format nil "  STR: ~a   DEX: ~a   WIL: ~a~%"
		     (combatant-str *player*)
		     (combatant-dex *player*)
		     (combatant-wil *player*)))
    (out ctx (format nil "~%"))
    (out ctx (format nil "  HP:    ~a/~a~%"
		     (combatant-hp *player*)
		     (combatant-hp-max *player*)))
    (out ctx (format nil "  Armor: ~a~%" (combatant-armor *player*)))
    (out ctx (format nil "  Gold:  ~a~%" (char-gold *player*)))
    (out ctx (format nil "  Fate:  ~a~%" (char-fate *player*)))
    (out ctx (format nil "~%"))
    (out ctx (format nil "  Inventory:~%"))
    (dolist (i (char-inventory *player*))
      (out ctx (format nil "    - ~a~%" (item-display-name i))))
    nil)
  (p "")
  (exit "Begin your adventure!" 'town-square))
