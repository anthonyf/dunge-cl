
(in-package #:dunge)

;;; generics

(defvar *rooms* (make-hash-table :test 'equal))

(defclass room ()
  ((name :reader name :initarg :name :initform nil)
   (entities :accessor entities :initform nil :initarg :entities)))

(defmethod initialize-instance :after ((room room) &key)
  (setf (gethash (name room) *rooms*) room))

(defun room (name &rest entities)
  (make-instance 'room :name name :entities entities))

(defclass choice ()
  ((label :accessor label :initarg :label :initform nil)
   (target :accessor target :initarg :target :initform nil)))

(defclass choices ()
  ((options :accessor options :initarg :options :initform nil)))

(defun choice (choices)
  (make-instance 'choices
		 :options (loop for option in options
				collect (make-instance 'choice :label (first option) :target (second option)))))

(defclass p ()
  ((text :reader text :initarg :text :initform nil))
  (:documentation "A paragraph of descriptive text."))

(defun p (text)
  (make-instance 'p :text text))

(defun quit ()
  :quit)

(defun evaluate (thing)
  (let ((stack nil))
    (match thing
      ((room :name name :entities entities)
       (format t "~a~%" name)
       )
      ((choices )
       (p ))
      (:quit ))))



#+nil
(evaluate (rooms (room "entrance"
		       (p "You stand at the entrance of a dark dungeon.")
		       (choice ("Enter the dungeon" (goto "hallway"))
			       ("Leave" (quit))))
		 (room "hallway"
		       (p "You are on a long dark hallway."))))
