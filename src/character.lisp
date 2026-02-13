(uiop:define-package #:dunge/character
  (:use #:cl)
  (:mix #:dunge/serialize
	#:dunge/dice)
  (:shadow #:char-name)
  (:export #:combatant
	   #:combatant-hp
	   #:combatant-hp-max
	   #:combatant-armor
	   #:combatant-str
	   #:combatant-dex
	   #:combatant-wil

	   #:player-character
	   #:char-name
	   #:char-background
	   #:char-gold
	   #:char-fate
	   #:char-inventory

	   #:*player*
	   #:player-ref
	   #:str-save
	   #:dex-save
	   #:wil-save))

(in-package #:dunge/character)

(defclass combatant ()
  ((hp     :initarg :hp     :accessor combatant-hp     :initform 0)
   (hp-max :initarg :hp-max :accessor combatant-hp-max :initform 0)
   (armor  :initarg :armor  :accessor combatant-armor  :initform 0)
   (str    :initarg :str    :accessor combatant-str    :initform 10)
   (dex    :initarg :dex    :accessor combatant-dex    :initform 10)
   (wil    :initarg :wil    :accessor combatant-wil    :initform 10)))

(defclass player-character (combatant)
  ((name          :initarg :name          :accessor char-name       :initform nil)
   (background    :initarg :background    :accessor char-background :initform nil)
   (gold          :initarg :gold          :accessor char-gold       :initform 0)
   (fate          :initarg :fate          :accessor char-fate       :initform 0)
   (inventory     :initarg :inventory     :accessor char-inventory  :initform nil)))

(defparameter *player* nil)

(defun player-ref (accessor)
  "Lazy slot reader for gate conditions — returns nil when *player* is nil."
  (lambda () (when *player* (funcall accessor *player*))))

(defun str-save (combatant)
  "STR save: roll d20 <= current STR to pass. Returns t on success."
  (<= (roll-d20) (combatant-str combatant)))

(defun dex-save (combatant)
  "DEX save: roll d20 <= current DEX to pass. Returns t on success."
  (<= (roll-d20) (combatant-dex combatant)))

(defun wil-save (combatant)
  "WIL save: roll d20 <= current WIL to pass. Returns t on success."
  (<= (roll-d20) (combatant-wil combatant)))

;;; Serialization

(defmethod serialize ((p player-character))
  (list :type :player
        :name (char-name p)
        :background (char-background p)
        :hp (combatant-hp p)
        :hp-max (combatant-hp-max p)
        :armor (combatant-armor p)
        :str (combatant-str p)
        :dex (combatant-dex p)
        :wil (combatant-wil p)
        :gold (char-gold p)
        :fate (char-fate p)
        :inventory (mapcar #'serialize (char-inventory p))))

(define-deserializer :player (plist)
  (let ((p (make-instance 'player-character :name (getf plist :name))))
    (setf (char-background p) (getf plist :background))
    (setf (combatant-hp p) (getf plist :hp))
    (setf (combatant-hp-max p) (getf plist :hp-max))
    (setf (combatant-armor p) (getf plist :armor))
    (setf (combatant-str p) (getf plist :str))
    (setf (combatant-dex p) (getf plist :dex))
    (setf (combatant-wil p) (getf plist :wil))
    (setf (char-gold p) (getf plist :gold))
    (setf (char-fate p) (getf plist :fate))
    (setf (char-inventory p)
          (mapcar (lambda (item-plist)
                    (deserialize (getf item-plist :type) item-plist))
                  (getf plist :inventory)))
    (setf *player* p)
    p))

