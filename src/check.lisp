(in-package #:dunge)

;;; Value checks
;;;
;;; One layer for checking values that come from sources, saves, and build
;;; procedures: CHECK-VALUE returns a value of the expected type or signals an
;;; error naming what was expected.

(defun proper-list-p (value)
  (and (listp value)
       (handler-case (list-length value)
         (type-error () nil))
       t))

(defun property-list-p (value)
  (and (proper-list-p value)
       (evenp (length value))))

(deftype positive-integer () '(integer 1))
(deftype non-negative-integer () '(integer 0))
(deftype proper-list () '(satisfies proper-list-p))
(deftype property-list () '(satisfies property-list-p))

(defparameter *type-descriptions*
  '((positive-integer . "a positive integer")
    (non-negative-integer . "a non-negative integer")
    (proper-list . "a proper, non-circular list")
    (property-list . "a proper property list, with an even number of entries")
    (string . "a string")
    (keyword . "a keyword")))

(defun check-value (value type label)
  "Return VALUE when it is of TYPE; otherwise signal an error saying LABEL
must be one."
  (unless (typep value type)
    (error "~A"
           ;; Print circular values safely.
           (let ((*print-circle* t))
             (format nil "~A must be ~A; got ~S."
                     label
                     (or (cdr (assoc type *type-descriptions*))
                         (format nil "of type ~S" type))
                     value))))
  value)
