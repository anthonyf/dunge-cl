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

(defclass enter ()
  ((target :reader enter-target :initarg :target :initform nil)))

(defun enter (target)
  (make-instance 'enter :target target))

(defclass back ()
  ())

(defun back ()
  (make-instance 'back))

(defclass choice ()
  ((label :accessor label :initarg :label :initform nil)
   (target :accessor target :initarg :target :initform nil)))

(defclass choices ()
  ((options :accessor options :initarg :options :initform nil)))

(defun option (label target)
  (make-instance 'choice :label label :target target))

(defmacro choice (&body options)
  `(make-instance 'choices
		  :options (list
			    ,@(mapcar (lambda (option)
					(destructuring-bind (label target) option
					  `(option ,label ,target)))
				      options))))

(defclass placement ()
  ((thing :reader placed-thing :initarg :thing :initform nil)
   (description :reader placement-description :initarg :description :initform nil)
   (interaction-label :reader interaction-label
		      :initarg :interaction-label
		      :initform nil)
   (interaction-target :reader interaction-target
		       :initarg :interaction-target
		       :initform nil)))

(defun placed (thing &key description interaction-label interaction-target)
  (make-instance 'placement
		 :thing thing
		 :description description
		 :interaction-label interaction-label
		 :interaction-target interaction-target))

(defclass item ()
  ((name :reader name :initarg :name :initform nil)
   (description :reader description :initarg :description :initform nil)))

(defun item (name &key description)
  (make-instance 'item :name name :description description))

(defclass container ()
  ((name :reader name :initarg :name :initform nil)
   (description :reader description :initarg :description :initform nil)
   (open-choice :reader open-choice :initarg :open-choice :initform nil)
   (close-choice :reader close-choice :initarg :close-choice :initform nil)
   (contents :accessor contents :initarg :contents :initform nil)))

(defmacro container (name &key description open-choice contents close-choice)
  `(make-instance 'container
		  :name ,name
		  :description ,description
		  :open-choice ,open-choice
		  :contents (list ,@contents)
		  :close-choice ,close-choice))

(defclass container-view ()
  ((container :reader viewed-container :initarg :container :initform nil)))

(defun container-view (container)
  (make-instance 'container-view :container container))

(defclass p ()
  ((text :reader text :initarg :text :initform nil))
  (:documentation "A paragraph of descriptive text."))

(defun p (text)
  (make-instance 'p :text text))

(defclass quit ()
  ())

(defun quit ()
  (make-instance 'quit))
