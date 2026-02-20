(in-package #:dunge)

;;; Base class — all items have a name

(defclass item ()
  ((name :initarg :name :accessor item-name)))

;;; Mixins — orthogonal behaviors composed via multiple inheritance

(defclass stackable ()
  ((stack-limit :initarg :stack-limit :accessor item-stack-limit :initform 10)
   (quantity    :initarg :quantity    :accessor item-quantity    :initform 1)))

(defclass weapon ()
  ((damage-die :initarg :damage-die :accessor item-damage-die)))

(defclass consumable () ())

;;; Display name — mixin specialization overrides the base method

(defgeneric item-display-name (item)
  (:documentation "Return a human-readable display string for the item."))

(defmethod item-display-name ((item item))
  (item-name item))

(defmethod item-display-name ((item stackable))
  (if (> (item-quantity item) 1)
      (format nil "~A x~A" (call-next-method) (item-quantity item))
      (call-next-method)))

(defmethod item-display-name ((item weapon))
  (format nil "~A (d~A)" (item-name item) (item-damage-die item)))

;;; Usable — can this item be used in combat?

(defgeneric usable-p (item)
  (:documentation "Can this item be used right now in combat?"))

(defmethod usable-p ((item item)) nil)
(defmethod usable-p ((item weapon)) t)

;;; Item use label — choice text for using this item in combat

(defgeneric item-use-label (item)
  (:documentation "Choice text for using this item in combat."))

(defmethod item-use-label ((item weapon))
  (format nil "Attack with ~A" (item-display-name item)))

(defmethod item-use-label ((item consumable))
  (format nil "Use ~A" (item-display-name item)))

;;; Consume — apply the effect of consuming an item

(defgeneric consume (item)
  (:documentation "Apply the effect of consuming ITEM. Specialize per type."))

;;; Concrete classes — combine base + mixins

(defclass stackable-item (stackable item) ())
(defclass weapon-item (weapon item) ())
(defclass healing-herb (consumable stackable item) ())

;;; Constructors

(defun make-item (name &key (quantity 1) (stack-limit 10) stackable)
  "Create an item. When STACKABLE is true, creates a stackable-item
with quantity clamped to stack-limit. Otherwise creates a plain item."
  (if stackable
      (make-instance 'stackable-item
	:name name
	:stack-limit stack-limit
	:quantity (min quantity stack-limit))
      (make-instance 'item
	:name name)))

(defun weapon (name &key damage-die)
  "Create a weapon-item with the given NAME and DAMAGE-DIE (integer sides)."
  (make-instance 'weapon-item
    :name name
    :damage-die damage-die))

(defun healing-herb (&key (quantity 3) (stack-limit 10))
  "Create a healing-herb item."
  (make-instance 'healing-herb
    :name "Healing Herbs"
    :stack-limit stack-limit
    :quantity (min quantity stack-limit)))

;;; Consume-item — decrement stackable quantity, remove from inventory at 0

(defun consume-item (item inventory)
  "Consume one of ITEM from INVENTORY. Decrements stackable quantity,
removes from inventory when exhausted. Returns the new inventory list."
  (if (typep item 'stackable)
      (progn (decf (item-quantity item))
	     (if (<= (item-quantity item) 0)
		 (remove item inventory)
		 inventory))
      (remove item inventory)))

;;; print-object — works for both item and stackable-item via item-display-name

(defmethod print-object ((item item) stream)
  (print-unreadable-object (item stream :type t)
    (princ (item-display-name item) stream)))

;;; Serialization

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

(define-deserializer :weapon (plist)
  (weapon (getf plist :name)
          :damage-die (getf plist :damage-die)))

(define-deserializer :healing-herb (plist)
  (healing-herb :quantity (getf plist :quantity)
                :stack-limit (getf plist :stack-limit)))

(define-deserializer :stackable (plist)
  (make-item (getf plist :name)
             :stackable t
             :quantity (getf plist :quantity)
             :stack-limit (getf plist :stack-limit)))

(define-deserializer :item (plist)
  (make-item (getf plist :name)))

