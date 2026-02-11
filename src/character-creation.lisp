(uiop:define-package #:dunge/character-creation
  (:use #:cl)
  (:shadowing-import-from #:dunge/room #:room)
  (:mix #:dunge/room
	#:dunge/item
	#:dunge/data-store
	#:dunge/engine
	#:dunge/dice)
  (:export #:character-info
	   #:town-square))

(in-package #:dunge/character-creation)

;;; Background data

(defparameter *backgrounds*
  `(("Soldier"  :description "trained in combat, disciplined"
		:equipment (,(make-item "Sword (d8)")
			    ,(make-item "Gambeson (Armor 1)")
			    ,(make-item "Helm (+1 Armor)"))
		:armor 2  :gold 8)
    ("Scholar"  :description "educated, curious, physically weak"
		:equipment (,(make-item "Spellbook")
			    ,(make-item "Dagger (d6)")
			    ,(make-item "Ink & Quill"))
		:armor 0  :gold 8)
    ("Criminal" :description "streetwise, light-fingered, untrustworthy"
		:equipment (,(make-item "Lockpicks")
			    ,(make-item "Dagger (d6)")
			    ,(make-item "Dark Cloak")
			    ,(make-item "Grappling Hook"))
		:armor 0  :gold 8)
    ("Pilgrim"  :description "faithful, traveled, poor"
		:equipment (,(make-item "Staff (d6)")
			    ,(make-item "Holy Symbol")
			    ,(make-item "Healing Herbs" :stackable t :stack-limit 10 :quantity 3))
		:armor 0  :gold 8)
    ("Hunter"   :description "survivalist, patient, rural"
		:equipment (,(make-item "Bow (d6)")
			    ,(make-item "Arrows")
			    ,(make-item "Knife (d6)")
			    ,(make-item "Snare Kit")
			    ,(make-item "Furs"))
		:armor 0  :gold 8)
    ("Merchant" :description "wealthy, connected, soft"
		:equipment (,(make-item "Dagger (d6)")
			    ,(make-item "Fine Clothes"))
		:armor 0  :gold 38)))

(defun background-prop (name prop)
  (getf (cdr (assoc name *backgrounds* :test #'string=)) prop))

;;; Character creation rooms

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
				   (list (make-item "Rations" :stackable t :stack-limit 10 :quantity 3)
					 (make-item "Torch" :stackable t :stack-limit 5 :quantity 2)
					 (make-item "Waterskin")))))
	       (setf (lookup "character" "inventory") items)
	       (setf (lookup "character" "armor") (background-prop bg :armor))
	       (setf (lookup "character" "gold") (background-prop bg :gold))
	       (setf (lookup "character" "equipped") t))
	     nil)))
  (p "As a " (ref "character" "background") " you receive:")
  (p "")
  (lambda (ctx)
    (dolist (i (lookup "character" "inventory"))
      (out ctx (format nil "  - ~a~%" (item-display-name i))))
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
    (dolist (i (lookup "character" "inventory"))
      (out ctx (format nil "    - ~a~%" (item-display-name i))))
    nil)
  (p "")
  (exit "Begin your adventure!" 'town-square))
