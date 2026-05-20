(in-package #:dunge)

;;; Game model and DSL constructors

(defvar *rooms* (make-hash-table :test 'equal)
  "Room registry for the most recently constructed game.")

(defclass game ()
  ((rooms :reader game-rooms :initarg :rooms :initform nil)
   (player :accessor game-player :initarg :player :initform nil)
   (room-index :reader room-index :initform (make-hash-table :test 'equal))
   (start :accessor game-start :initarg :start :initform nil)))

(defmethod initialize-instance :after ((game game) &key)
  (clrhash (room-index game))
  (dolist (room (game-rooms game))
    (multiple-value-bind (existing-room present-p) (gethash (name room) (room-index game))
      (declare (ignore existing-room))
      (when present-p
	(error "Duplicate room named ~S." (name room))))
    (setf (gethash (name room) (room-index game)) room))
  (unless (game-start game)
    (setf (game-start game) (and (game-rooms game)
				 (name (first (game-rooms game)))))))

(defun game (&rest rooms)
  (let ((game (make-instance 'game :rooms rooms)))
    (clrhash *rooms*)
    (maphash (lambda (name room)
	       (setf (gethash name *rooms*) room))
	     (room-index game))
    game))

(defclass room ()
  ((name :reader name :initarg :name :initform nil)
   (entities :accessor entities :initform nil :initarg :entities)))

(defun room (name &rest entities)
  (make-instance 'room :name name :entities entities))

(defclass goto ()
  ((room-name :reader room-name :initarg :room-name :initform nil)))

(defun goto (room-name)
  (make-instance 'goto :room-name room-name))

(defclass gosub ()
  ((room-name :reader room-name :initarg :room-name :initform nil)))

(defun gosub (room-name)
  (make-instance 'gosub :room-name room-name))

(defclass choice ()
  ((label :accessor label :initarg :label :initform nil)
   (target :accessor target :initarg :target :initform nil)))

(defclass choices ()
  ((options :accessor options :initarg :options :initform nil)))

(defmacro choice (&body options)
  `(make-instance 'choices
		  :options (list
			    ,@(mapcar (lambda (option)
					(destructuring-bind (label target) option
					  `(make-instance 'choice
							  :label ,label
							  :target ,target)))
				      options))))

(defclass p ()
  ((text :reader text :initarg :text :initform nil))
  (:documentation "A paragraph of descriptive text."))

(defun p (text)
  (make-instance 'p :text text))

(defclass quit ()
  ())

(defun quit ()
  (make-instance 'quit))
