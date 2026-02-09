(uiop:define-package #:dunge/item
  (:use #:cl)
  (:shadow #:item)
  (:export #:item
	   #:item-name
	   #:item-display-name
	   #:item-actions

	   #:stackable
	   #:item-stack-limit
	   #:item-quantity

	   #:make-item))

(in-package #:dunge/item)

;;; Base class — all items have a name

(defclass item ()
  ((name :initarg :name :accessor item-name)))

;;; Mixins — orthogonal behaviors composed via multiple inheritance

(defclass stackable ()
  ((stack-limit :initarg :stack-limit :accessor item-stack-limit :initform 10)
   (quantity    :initarg :quantity    :accessor item-quantity    :initform 1)))

;;; Display name — mixin specialization overrides the base method

(defgeneric item-display-name (item)
  (:documentation "Return a human-readable display string for the item."))

(defmethod item-display-name ((item item))
  (item-name item))

(defmethod item-display-name ((item stackable))
  (if (> (item-quantity item) 1)
      (format nil "~A x~A" (item-name item) (item-quantity item))
      (item-name item)))

;;; Actions — stub for future mixin specialization (consumable, equippable, etc.)

(defgeneric item-actions (item)
  (:documentation "Return a list of available actions for the item."))

(defmethod item-actions ((item item))
  nil)

;;; Concrete classes — combine base + mixins

(defclass stackable-item (stackable item) ())

;;; Constructor — picks the right class based on keywords

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

;;; print-object — works for both item and stackable-item via item-display-name

(defmethod print-object ((item item) stream)
  (print-unreadable-object (item stream :type t)
    (princ (item-display-name item) stream)))
