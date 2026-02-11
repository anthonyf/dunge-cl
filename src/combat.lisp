(uiop:define-package #:dunge/combat
  (:use #:cl)
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
  (setf (lookup "combat" "enemy-name") name)
  (setf (lookup "combat" "enemy-hp") hp)
  (setf (lookup "combat" "enemy-hp-max") hp)
  (setf (lookup "combat" "enemy-armor") armor)
  (setf (lookup "combat" "enemy-attack") attack-die)
  (setf (lookup "combat" "active") t))

(defun resolve-player-attack (damage-die)
  (let* ((roll (first (roll-dice damage-die)))
	 (armor (lookup "combat" "enemy-armor"))
	 (damage (max 0 (- roll armor)))
	 (new-hp (max 0 (- (lookup "combat" "enemy-hp") damage))))
    (setf (lookup "combat" "enemy-hp") new-hp)
    damage))

(defun resolve-enemy-attack ()
  (let* ((attack-die (lookup "combat" "enemy-attack"))
	 (roll (first (roll-dice attack-die)))
	 (armor (lookup "character" "armor"))
	 (damage (max 0 (- roll armor)))
	 (new-hp (max 0 (- (lookup "character" "hp") damage))))
    (setf (lookup "character" "hp") new-hp)
    damage))

(defun clear-encounter ()
  (setf (lookup "combat" "active") nil))

(defun enemy-alive-p ()
  (> (lookup "combat" "enemy-hp") 0))

(defun player-alive-p ()
  (> (lookup "character" "hp") 0))
