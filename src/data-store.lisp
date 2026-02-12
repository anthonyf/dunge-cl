(uiop:define-package #:dunge/data-store
  (:use #:cl)
  (:export #:lookup
	   #:*data-store*))

(in-package #:dunge/data-store)

(defparameter *data-store* nil)

(defun lookup (&rest keys)
  (let ((current *data-store*))
    (dolist (key keys current)
      (if (hash-table-p current)
	  (setf current (gethash key current))
	  (return nil)))))

(defun (setf lookup) (value &rest keys)
  (when (null *data-store*)
    (setf *data-store* (make-hash-table :test 'equal)))
  (let ((current *data-store*))
    ;; Traverse/create intermediate hash tables for all but the last key
    (loop for key in (butlast keys)
	  do (let ((next (gethash key current)))
	       (unless (hash-table-p next)
		 (setf next (make-hash-table :test 'equal))
		 (setf (gethash key current) next))
	       (setf current next)))
    ;; Set or remove the final key
    (let ((final-key (car (last keys))))
      (if (null value)
	  (remhash final-key current)
	  (setf (gethash final-key current) value))))
  value)

