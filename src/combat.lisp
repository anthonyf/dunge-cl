(uiop:define-package #:dunge/combat
  (:use #:cl)
  (:import-from #:dunge/room #:room-local)
  (:import-from #:dunge/character
		#:combatant
		#:combatant-hp
		#:combatant-hp-max
		#:combatant-armor
		#:*player*)
  (:mix #:dunge/dice)
  (:export #:enemy
	   #:enemy-name
	   #:enemy-attack-die

	   #:encounter
	   #:encounter-enemy
	   #:encounter-active-p
	   #:encounter-log

	   #:current-encounter
	   #:encounter-active
	   #:setup-encounter
	   #:resolve-player-attack
	   #:resolve-enemy-attack
	   #:clear-encounter
	   #:enemy-alive-p
	   #:player-alive-p))

(in-package #:dunge/combat)

(defclass enemy (combatant)
  ((name       :initarg :name       :accessor enemy-name)
   (attack-die :initarg :attack-die :accessor enemy-attack-die)))

(defclass encounter ()
  ((enemy    :initarg :enemy    :accessor encounter-enemy)
   (active-p :initarg :active-p :accessor encounter-active-p :initform t)
   (log      :initarg :log      :accessor encounter-log      :initform nil)))

(defun current-encounter ()
  (room-local "encounter"))

(defun encounter-active ()
  (let ((enc (current-encounter)))
    (and enc (encounter-active-p enc))))

(defun setup-encounter (name hp armor attack-die)
  (let* ((e (make-instance 'enemy
			   :name name
			   :hp hp
			   :hp-max hp
			   :armor armor
			   :attack-die attack-die))
	 (enc (make-instance 'encounter :enemy e)))
    (setf (room-local "encounter") enc)))

(defun resolve-player-attack (damage-die)
  (let* ((e (encounter-enemy (current-encounter)))
	 (roll (first (roll-dice damage-die)))
	 (armor (combatant-armor e))
	 (damage (max 0 (- roll armor)))
	 (new-hp (max 0 (- (combatant-hp e) damage))))
    (setf (combatant-hp e) new-hp)
    damage))

(defun resolve-enemy-attack ()
  (let* ((e (encounter-enemy (current-encounter)))
	 (roll (first (roll-dice (enemy-attack-die e))))
	 (armor (combatant-armor *player*))
	 (damage (max 0 (- roll armor)))
	 (new-hp (max 0 (- (combatant-hp *player*) damage))))
    (setf (combatant-hp *player*) new-hp)
    damage))

(defun clear-encounter ()
  (let ((enc (current-encounter)))
    (when enc
      (setf (encounter-active-p enc) nil))))

(defun enemy-alive-p ()
  (let ((enc (current-encounter)))
    (and enc (> (combatant-hp (encounter-enemy enc)) 0))))

(defun player-alive-p ()
  (> (combatant-hp *player*) 0))
