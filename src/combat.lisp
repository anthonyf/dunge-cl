(uiop:define-package #:dunge/combat
  (:use #:cl)
  (:import-from #:dunge/room #:room-local)
  (:mix #:dunge/data-store
	#:dunge/dice)
  (:export #:setup-encounter
	   #:resolve-player-attack
	   #:resolve-enemy-attack
	   #:clear-encounter
	   #:enemy-alive-p
	   #:player-alive-p))

(in-package #:dunge/combat)

(defun setup-encounter (name hp armor attack-die)
  (setf (room-local "enemy-name") name)
  (setf (room-local "enemy-hp") hp)
  (setf (room-local "enemy-hp-max") hp)
  (setf (room-local "enemy-armor") armor)
  (setf (room-local "enemy-attack") attack-die)
  (setf (room-local "active") t))

(defun resolve-player-attack (damage-die)
  (let* ((roll (first (roll-dice damage-die)))
	 (armor (room-local "enemy-armor"))
	 (damage (max 0 (- roll armor)))
	 (new-hp (max 0 (- (room-local "enemy-hp") damage))))
    (setf (room-local "enemy-hp") new-hp)
    damage))

(defun resolve-enemy-attack ()
  (let* ((attack-die (room-local "enemy-attack"))
	 (roll (first (roll-dice attack-die)))
	 (armor (lookup "character" "armor"))
	 (damage (max 0 (- roll armor)))
	 (new-hp (max 0 (- (lookup "character" "hp") damage))))
    (setf (lookup "character" "hp") new-hp)
    damage))

(defun clear-encounter ()
  (setf (room-local "active") nil))

(defun enemy-alive-p ()
  (> (room-local "enemy-hp") 0))

(defun player-alive-p ()
  (> (lookup "character" "hp") 0))
