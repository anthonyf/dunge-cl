(in-package #:dunge)

(defclass enemy (combatant)
  ((name       :initarg :name       :accessor enemy-name)
   (attack-die :initarg :attack-die :accessor enemy-attack-die)))

(defclass encounter ()
  ((enemy         :initarg :enemy         :accessor encounter-enemy)
   (first-round-p :initarg :first-round-p :accessor encounter-first-round-p :initform t)
   (log           :initarg :log           :accessor encounter-log           :initform nil)
   (state         :initarg :state         :accessor encounter-state         :initform :active)))

(defun current-encounter ()
  (room-local "encounter"))

(defun encounter-active ()
  (not (null (current-encounter))))

(defun setup-encounter (name hp armor attack-die &key (str 10) (dex 10) (wil 10))
  (let* ((e (make-instance 'enemy
			   :name name
			   :hp hp
			   :hp-max hp
			   :armor armor
			   :attack-die attack-die
			   :str str
			   :dex dex
			   :wil wil))
	 (enc (make-instance 'encounter :enemy e)))
    (setf (room-local "encounter") enc)))

(defun resolve-attack (attacker-die target)
  "Resolve an attack against TARGET. Returns a plist:
   :damage — HP damage dealt
   :str-damage — STR damage dealt (spillover)
   :critical-save — t if STR save passed, nil if failed, :none if no save needed
   :dead — t if target's STR reached 0"
  (let* ((roll (first (roll-dice attacker-die)))
	 (armor (combatant-armor target))
	 (damage (max 0 (- roll armor)))
	 (hp (combatant-hp target))
	 (hp-damage (min damage hp))
	 (remainder (- damage hp-damage))
	 (str-damage 0)
	 (critical-save :none)
	 (dead nil))
    ;; Apply HP damage
    (setf (combatant-hp target) (- hp hp-damage))
    ;; Spillover to STR
    (when (> remainder 0)
      (setf str-damage remainder)
      (let ((new-str (max 0 (- (combatant-str target) remainder))))
	(setf (combatant-str target) new-str)
	(if (zerop new-str)
	    (setf dead t)
	    (setf critical-save (str-save target)))))
    (list :damage hp-damage
	  :str-damage str-damage
	  :critical-save critical-save
	  :dead dead)))

(defun resolve-player-attack (damage-die)
  (resolve-attack damage-die (encounter-enemy (current-encounter))))

(defun resolve-enemy-attack ()
  (resolve-attack (enemy-attack-die (encounter-enemy (current-encounter))) *player*))

(defun format-attack-lines (result &key glance-msg damage-fmt critical-fmt
                                         dead-msg fail-msg endure-msg)
  "Return a list of strings describing an attack from RESULT plist."
  (let ((lines nil)
	(dmg (getf result :damage))
	(str-dmg (getf result :str-damage))
	(crit (getf result :critical-save))
	(dead (getf result :dead)))
    (if (and (zerop dmg) (zerop str-dmg))
	(push glance-msg lines)
	(progn
	  (when (> dmg 0)
	    (push (format nil damage-fmt dmg) lines))
	  (when (> str-dmg 0)
	    (push (format nil critical-fmt str-dmg) lines)
	    (cond
	      (dead (push dead-msg lines))
	      ((eq crit nil) (push fail-msg lines))
	      ((eq crit t) (push endure-msg lines))))))
    (nreverse lines)))

(defun format-player-attack-lines (result)
  "Return a list of strings describing the player's attack."
  (format-attack-lines result
    :glance-msg "Your attack glances off harmlessly."
    :damage-fmt "You deal ~a damage."
    :critical-fmt "A critical blow! ~a STR damage!"
    :dead-msg "The enemy collapses, dead!"
    :fail-msg "The enemy fails its STR save and is slain!"
    :endure-msg "The enemy endures the wound."))

(defun format-enemy-attack-lines (result)
  "Return a list of strings describing the enemy's attack on the player."
  (format-attack-lines result
    :glance-msg "The enemy's attack glances off harmlessly."
    :damage-fmt "The enemy deals ~a damage."
    :critical-fmt "A devastating hit! ~a STR damage!"
    :dead-msg "You collapse. Your wounds are fatal."
    :fail-msg "You fail your STR save and fall unconscious!"
    :endure-msg "You grit your teeth and endure."))

(defun format-combat-log (player-result enemy-result)
  "Build a combat log string from attack result plists."
  (format nil "~{~a~^ ~}"
	  (append (format-player-attack-lines player-result)
		  (format-enemy-attack-lines enemy-result))))

;;; Heal

(defun resolve-heal ()
  "Restore player HP to max (Cairn short rest). Returns a plist."
  (let ((old-hp (combatant-hp *player*))
	(max-hp (combatant-hp-max *player*)))
    (setf (combatant-hp *player*) max-hp)
    (list :healed (- max-hp old-hp)
	  :old-hp old-hp
	  :new-hp max-hp)))

(defun format-heal-log (heal-result enemy-result)
  "Build a log string for a heal + enemy attack round."
  (format nil "~{~a~^ ~}"
	  (cons (format nil "You use Healing Herbs and restore ~a HP. (~a/~a)"
			(getf heal-result :healed)
			(getf heal-result :new-hp)
			(getf heal-result :new-hp))
		(format-enemy-attack-lines enemy-result))))

;;; Flee

(defun resolve-flee ()
  "Attempt to flee. DEX save; on fail, enemy gets a parting blow.
Returns a plist (:success t/nil :enemy-result ...)."
  (if (dex-save *player*)
      (list :success t :enemy-result nil)
      (list :success nil :enemy-result (resolve-enemy-attack))))

(defun format-flee-log (flee-result)
  "Build a log string for a flee attempt."
  (if (getf flee-result :success)
      "You turn and flee! You escape cleanly."
      (format nil "~{~a~^ ~}"
              (cons "You try to flee but the enemy lands a parting blow!"
                    (format-enemy-attack-lines (getf flee-result :enemy-result))))))

;;; Healing-herb combat methods (defined here where *player* is accessible)

(defmethod usable-p ((item healing-herb))
  (and *player*
       (< (combatant-hp *player*) (combatant-hp-max *player*))))

(defmethod consume ((item healing-herb))
  (resolve-heal))

;;; Combat choices

(defun update-encounter-state (enc &key player-attack-result enemy-attack-result fled)
  "Determine and set encounter state from round results.
   player-attack-result: result of player's attack on the enemy.
   enemy-attack-result: result of enemy's attack on the player.
   Priority: victory > death > incapacitated > fled > active."
  (setf (encounter-state enc)
        (cond
          ;; Enemy killed (STR=0 or failed STR save)
          ((and player-attack-result
                (or (getf player-attack-result :dead)
                    (and (not (eq (getf player-attack-result :critical-save) :none))
                         (not (getf player-attack-result :critical-save)))))
           :victory)
          ;; Player dead (STR=0)
          ((and enemy-attack-result (getf enemy-attack-result :dead))
           :death)
          ;; Player incapacitated (failed STR save)
          ((and enemy-attack-result
                (not (getf enemy-attack-result :dead))
                (not (eq (getf enemy-attack-result :critical-save) :none))
                (not (getf enemy-attack-result :critical-save)))
           :incapacitated)
          ;; Fled
          (fled :fled)
          ;; Still fighting
          (t :active))))

(defun combat-choices ()
  "Build combat choices from *player* inventory. Returns a list of choices."
  (let ((choices nil)
	(has-weapon nil))
    ;; Scan inventory for usable items
    (dolist (item (char-inventory *player*))
      (when (usable-p item)
	(let ((it item))
	  (cond
	    ;; Weapon → attack
	    ((typep it 'weapon)
	     (setf has-weapon t)
	     (push (make-instance 'choice
		     :label (item-use-label it)
		     :action (lambda ()
			       (let* ((enc (current-encounter))
				      (player-result (resolve-player-attack (item-damage-die it)))
				      (enemy-result (resolve-enemy-attack)))
				 (update-encounter-state enc
				   :player-attack-result player-result
				   :enemy-attack-result enemy-result)
				 (setf (encounter-log enc)
				       (format-combat-log player-result enemy-result)))))
		   choices))
	    ;; Consumable → consume + enemy attacks
	    ((typep it 'consumable)
	     (push (make-instance 'choice
		     :label (item-use-label it)
		     :action (lambda ()
			       (let* ((enc (current-encounter))
				      (heal-result (consume it))
				      (enemy-result (resolve-enemy-attack)))
				 (setf (char-inventory *player*)
				       (consume-item it (char-inventory *player*)))
				 (update-encounter-state enc
				   :enemy-attack-result enemy-result)
				 (setf (encounter-log enc)
				       (format-heal-log heal-result enemy-result)))))
		   choices))))))
    ;; Unarmed fallback (Cairn: d4 unarmed)
    (unless has-weapon
      (push (make-instance 'choice
	      :label "Unarmed Attack (d4)"
	      :action (lambda ()
			(let* ((enc (current-encounter))
			       (player-result (resolve-player-attack 4))
			       (enemy-result (resolve-enemy-attack)))
			  (update-encounter-state enc
			    :player-attack-result player-result
			    :enemy-attack-result enemy-result)
			  (setf (encounter-log enc)
				(format-combat-log player-result enemy-result)))))
	    choices))
    ;; Flee (always last)
    (push (make-instance 'choice
	    :label "Flee"
	    :action (lambda ()
		      (let* ((enc (current-encounter))
			     (flee-result (resolve-flee)))
			(update-encounter-state enc
			  :enemy-attack-result (getf flee-result :enemy-result)
			  :fled t)
			(setf (encounter-log enc)
			      (format-flee-log flee-result)))))
	  choices)
    (nreverse choices)))

(defun clear-encounter ()
  (setf (room-local "encounter") nil))

;;; Combat encounter — state-machine room element

(defclass combat-encounter ()
  ((enemy          :initarg :enemy          :accessor ce-enemy-spec)
   (intro          :initarg :intro          :accessor ce-intro)
   (victory        :initarg :victory        :accessor ce-victory)
   (death          :initarg :death          :accessor ce-death)
   (incapacitated  :initarg :incapacitated  :accessor ce-incapacitated)
   (fled           :initarg :fled           :accessor ce-fled)))

(defun combat-encounter (&key enemy intro victory death incapacitated fled)
  (make-instance 'combat-encounter
    :enemy enemy
    :intro intro
    :victory victory
    :death death
    :incapacitated incapacitated
    :fled fled))

(defun cleanup-combat (state)
  "Reset player stats after combat ends if needed."
  (when (member state '(:death :incapacitated))
    (setf (combatant-hp *player*) (combatant-hp-max *player*))
    (setf (combatant-str *player*) 10))
  (clear-encounter))

(defmethod perform (ctx (ce combat-encounter))
  ;; Setup on first visit: create encounter + show intro
  (when (not (encounter-active))
    (apply #'setup-encounter (ce-enemy-spec ce))
    (when (ce-intro ce)
      (perform ctx (ce-intro ce))))
  ;; Active encounter
  (let* ((enc (current-encounter))
	 (state (encounter-state enc)))
       ;; Drain combat log
       (when (encounter-log enc)
	 (out ctx (format nil "~a~%" (encounter-log enc)))
	 (setf (encounter-log enc) nil))
       ;; First-round DEX save
       (when (and (eq state :active) (encounter-first-round-p enc))
	 (setf (encounter-first-round-p enc) nil)
	 (if (dex-save *player*)
	     (out ctx (format nil "You react quickly!~%"))
	     (let* ((enemy-result (resolve-enemy-attack))
		    (lines (cons "Caught off guard! The enemy strikes first."
				 (format-enemy-attack-lines enemy-result))))
	       (out ctx (format nil "~{~a~^ ~}~%" lines))
	       (update-encounter-state enc :enemy-attack-result enemy-result)
	       (setf state (encounter-state enc)))))
       (if (eq state :active)
	   ;; Show stats + return combat choices
	   (let ((e (encounter-enemy enc)))
	     (out ctx (format nil "  ~a HP: ~a/~a  STR: ~a~%"
			      (enemy-name e)
			      (combatant-hp e)
			      (combatant-hp-max e)
			      (combatant-str e)))
	     (out ctx (format nil "  Your HP: ~a/~a  STR: ~a~%~%"
			      (combatant-hp *player*)
			      (combatant-hp-max *player*)
			      (combatant-str *player*)))
	     (combat-choices))
	   ;; Terminal state: cleanup + show outcome elements
	   (let ((outcome (case state
			    (:victory       (ce-victory ce))
			    (:death         (ce-death ce))
			    (:incapacitated (ce-incapacitated ce))
			    (:fled          (ce-fled ce)))))
	     (cleanup-combat state)
	     (when outcome (perform ctx outcome))))))
