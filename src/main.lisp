
(in-package #:dunge)

;;; AST nodes

(defvar *rooms* (make-hash-table :test 'equal)
  "Room registry for the most recently constructed game.")

(defvar *input* *standard-input*)
(defvar *output* *standard-output*)

(defclass game ()
  ((rooms :reader game-rooms :initarg :rooms :initform nil)
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

(defun rooms (&rest rooms)
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

(defgeneric evaluate (thing)
  (:documentation "Evaluate a Dunge CLOS AST node."))

(defun control-result-p (thing)
  (or (eq thing :quit)
      (typep thing 'goto)
      (typep thing 'gosub)
      (typep thing 'room)))

(defun find-room (game room-name)
  (multiple-value-bind (room present-p) (gethash room-name (room-index game))
    (if present-p
	room
	(error "No room named ~S." room-name))))

(defun read-choice-index (count)
  (loop
    (format *output* "> ")
    (finish-output *output*)
    (let* ((line (read-line *input* nil nil))
	   (index (and line (parse-integer line :junk-allowed t))))
      (unless line
	(return nil))
      (when (and index (<= 1 index count))
	(return index))
      (format *output* "Choose 1-~D.~%" count))))

(defmethod evaluate ((game game))
  (unless (game-start game)
    (error "Cannot evaluate a game with no rooms."))
  (loop with room = (find-room game (game-start game))
	with return-stack = nil
	do (let ((result (evaluate room)))
	     (cond
	       ((eq result :quit)
		(return :quit))
	       ((typep result 'goto)
		(setf room (find-room game (room-name result))))
	       ((typep result 'gosub)
		(push room return-stack)
		(setf room (find-room game (room-name result))))
	       (return-stack
		(setf room (pop return-stack)))
	       (t
		(return result))))))

(defmethod evaluate ((room room))
  (format *output* "~&~A~%" (name room))
  (dolist (entity (entities room) room)
    (let ((result (evaluate entity)))
      (when (control-result-p result)
	(return result)))))

(defmethod evaluate ((paragraph p))
  (format *output* "~A~%" (text paragraph)))

(defmethod evaluate ((choices choices))
  (let ((options (options choices)))
    (loop for option in options
	  for index from 1
	  do (format *output* "~D. ~A~%" index (label option)))
    (let ((index (and options (read-choice-index (length options)))))
      (if index
	  (evaluate (target (nth (1- index) options)))
	  :quit))))

(defmethod evaluate ((goto goto))
  goto)

(defmethod evaluate ((gosub gosub))
  gosub)

(defmethod evaluate ((quit quit))
  :quit)



#+nil
(evaluate (rooms (room "entrance"
		       (p "You stand at the entrance of a dark dungeon.")
		       (choice ("Look in the chest" (gosub "chest"))
			       ("Enter the dungeon" (goto "hallway"))
			       ("Leave" (quit))))
		 (room "chest"
		       (p "Inside the chest is a brass key."))
		 (room "hallway"
		       (p "You are on a long dark hallway."))))
