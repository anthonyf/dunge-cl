(in-package #:dunge)

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

(defun print-character-sheet (ctx &key inventory)
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
  (when inventory
    (out ctx (format nil "~%"))
    (out ctx (format nil "  Inventory:~%"))
    (dolist (i (char-inventory *player*))
      (out ctx (format nil "    - ~a~%" (item-display-name i))))))

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

