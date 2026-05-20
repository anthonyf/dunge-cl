(in-package #:dunge)

;;; Evaluator and console runtime

(defvar *input* *standard-input*)
(defvar *output* *standard-output*)

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
