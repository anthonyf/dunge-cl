(uiop:define-package #:dunge/serialize
  (:use #:cl)
  (:shadowing-import-from #:dunge/character #:char-name)
  (:shadowing-import-from #:dunge/item #:item)
  (:mix #:dunge/item
	#:dunge/character)
  (:export #:serialize
	   #:deserialize))

(in-package #:dunge/serialize)

;;; Generic functions

(defgeneric serialize (object)
  (:documentation "Serialize OBJECT to a type-tagged plist."))

(defgeneric deserialize (type plist)
  (:documentation "Reconstruct an object from TYPE keyword and PLIST data."))

;;; Item serialization

(defmethod serialize ((item weapon-item))
  (list :type :weapon
        :name (item-name item)
        :damage-die (item-damage-die item)))

(defmethod serialize ((item healing-herb))
  (list :type :healing-herb
        :quantity (item-quantity item)
        :stack-limit (item-stack-limit item)))

(defmethod serialize ((item stackable-item))
  (list :type :stackable
        :name (item-name item)
        :quantity (item-quantity item)
        :stack-limit (item-stack-limit item)))

(defmethod serialize ((item item))
  (list :type :item
        :name (item-name item)))

;;; Item deserialization

(defmethod deserialize ((type (eql :weapon)) plist)
  (weapon (getf plist :name)
          :damage-die (getf plist :damage-die)))

(defmethod deserialize ((type (eql :healing-herb)) plist)
  (healing-herb :quantity (getf plist :quantity)
                :stack-limit (getf plist :stack-limit)))

(defmethod deserialize ((type (eql :stackable)) plist)
  (make-item (getf plist :name)
             :stackable t
             :quantity (getf plist :quantity)
             :stack-limit (getf plist :stack-limit)))

(defmethod deserialize ((type (eql :item)) plist)
  (make-item (getf plist :name)))

;;; Player serialization

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

(defmethod deserialize ((type (eql :player)) plist)
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
