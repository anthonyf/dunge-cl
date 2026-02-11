(uiop:define-package #:dunge/combat
  (:use #:cl)
  (:import-from #:dunge/room #:room-local)
  (:import-from #:dunge/character
		#:combatant
		#:combatant-hp
		#:combatant-hp-max
		#:combatant-armor
		#:combatant-str
		#:combatant-dex
		#:combatant-wil
		#:*player*)
  (:mix #:dunge/dice)
  (:export #:enemy
	   #:enemy-name
	   #:enemy-attack-die

	   #:encounter
	   #:encounter-enemy
	   #:encounter-active-p
	   #:encounter-log
	   #:encounter-enemy-dead
	   #:encounter-player-down

	   #:current-encounter
	   #:encounter-active
	   #:setup-encounter
	   #:resolve-attack
	   #:resolve-player-attack
	   #:resolve-enemy-attack
	   #:format-combat-log
	   #:clear-encounter
	   #:enemy-alive-p
	   #:player-alive-p
	   #:str-save))

(in-package #:dunge/combat)

(defclass enemy (combatant)
  ((name       :initarg :name       :accessor enemy-name)
   (attack-die :initarg :attack-die :accessor enemy-attack-die)))

(defclass encounter ()
  ((enemy       :initarg :enemy       :accessor encounter-enemy)
   (active-p    :initarg :active-p    :accessor encounter-active-p    :initform t)
   (log         :initarg :log         :accessor encounter-log         :initform nil)
   (enemy-dead  :initarg :enemy-dead  :accessor encounter-enemy-dead  :initform nil)
   (player-down :initarg :player-down :accessor encounter-player-down :initform nil)))

(defun current-encounter ()
  (room-local "encounter"))

(defun encounter-active ()
  (let ((enc (current-encounter)))
    (and enc (encounter-active-p enc))))

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

(defun str-save (combatant)
  "STR save: roll d20 <= current STR to pass. Returns t on success."
  (<= (roll-d20) (combatant-str combatant)))

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

(defun format-combat-log (player-result enemy-result)
  "Build a combat log string from attack result plists."
  (let ((lines nil))
    ;; Player's attack
    (let ((dmg (getf player-result :damage))
	  (str-dmg (getf player-result :str-damage))
	  (crit (getf player-result :critical-save))
	  (dead (getf player-result :dead)))
      (if (and (zerop dmg) (zerop str-dmg))
	  (push "Your attack glances off harmlessly." lines)
	  (progn
	    (when (> dmg 0)
	      (push (format nil "You deal ~a damage." dmg) lines))
	    (when (> str-dmg 0)
	      (push (format nil "A critical blow! ~a STR damage!" str-dmg) lines)
	      (cond
		(dead (push "The enemy collapses, dead!" lines))
		((eq crit nil) (push "The enemy fails its STR save and is slain!" lines))
		((eq crit t) (push "The enemy endures the wound." lines)))))))
    ;; Enemy's attack
    (let ((dmg (getf enemy-result :damage))
	  (str-dmg (getf enemy-result :str-damage))
	  (crit (getf enemy-result :critical-save))
	  (dead (getf enemy-result :dead)))
      (if (and (zerop dmg) (zerop str-dmg))
	  (push "The enemy's attack glances off harmlessly." lines)
	  (progn
	    (when (> dmg 0)
	      (push (format nil "The enemy deals ~a damage." dmg) lines))
	    (when (> str-dmg 0)
	      (push (format nil "A devastating hit! ~a STR damage!" str-dmg) lines)
	      (cond
		(dead (push "You collapse. Your wounds are fatal." lines))
		((eq crit nil) (push "You fail your STR save and fall unconscious!" lines))
		((eq crit t) (push "You grit your teeth and endure." lines)))))))
    (format nil "~{~a~^ ~}" (nreverse lines))))

(defun clear-encounter ()
  (let ((enc (current-encounter)))
    (when enc
      (setf (encounter-active-p enc) nil))))

(defun enemy-alive-p ()
  (let ((enc (current-encounter)))
    (and enc
	 (not (encounter-enemy-dead enc))
	 (> (combatant-str (encounter-enemy enc)) 0))))

(defun player-alive-p ()
  (> (combatant-str *player*) 0))
