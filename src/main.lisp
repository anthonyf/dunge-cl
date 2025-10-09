(uiop:define-package #:dunge
  (:use #:cl)
  (:shadow #:room)
  (:mix-reexport #:dunge/generics)
  (:local-nicknames (#:i #:dunge/capi/interface))
  (:export #:main))

(in-package #:dunge)

(defclass simple-command ()
  ((text :initarg :text
	 :accessor text)
   (execute-fn :initarg :execute-fn
	       :accessor execute-fn)))

(defmethod execute ((command simple-command))
  (with-accessors ((execute-fn execute-fn)) command
    (funcall execute-fn)))

(defclass game-state ()
  ((current-room-id :accessor current-room-id
		    :initarg current-room-id
		    :initform nil)
   (rooms :accessor rooms :initarg rooms)))

(defun new-game-state ()
  (setf *game-state* (make-instance 'game-state)))

(defclass room ()
  ((description :initarg :description
		:initform (error "must supply room description!"))
   (contents :accessor contents
	     :initarg :contents
	     :initform nil)))

(defun add-room (&key room-id description (contents nil))
  (let ((room (make-instance 'room
			     :description description
			     :contents contents)))
    (setf (getf (rooms *game-state*) room-id)
	  room)))

(defun get-room (room-id)
  (getf (rooms *game-state*) room-id))

(defclass path ()
  ((command :initarg :command
	    :accessor command)
   (description :accessor description
		:initarg :description)
   (room-id :accessor room-id
	    :initarg :room-id)))

(defun add-path (from-room-id to-room-id description command)
  (push (make-instance 'path
		       :command command
		       :description description
		       :room-id to-room-id)
	(contents (get-room from-room-id))))

(defmethod text ((gs game-state))
  )

(defmethod commands ((gs game-state))
  )

(defun main ()
  (new-game-state)
  (add-room :room-id :start :description "Welcome to Dunge!")
  (add-path :start :town-center
	    :description "Click continue to play"
	    :command "Continue")
  
  (add-room :room-id :town-center :description "Town Center")
  (add-room :room-id :blacksmith :description "Blacksmith")
  (add-room :room-id :blacksmith :description "General Store")
  (add-room :room-id :adventurers-guild :description "Adventurer's Guild")
  (i:run-capi-game))

