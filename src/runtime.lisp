(in-package #:dunge)

;;; Evaluator and console runtime

(defvar *input* *standard-input*)
(defvar *output* *standard-output*)

(defgeneric evaluate (thing)
  (:documentation "Evaluate a Dunge CLOS AST node."))

(defgeneric describe-entity (thing)
  (:documentation "Describe an AST node as part of a room."))

(defgeneric collect-choices (thing)
  (:documentation "Collect choice objects contributed by an AST node."))

(defun control-result-p (thing)
  (or (eq thing :quit)
      (typep thing 'goto)
      (typep thing 'gosub)
      (typep thing 'enter)
      (typep thing 'back)
      (typep thing 'room)))

(defun immediate-control-result (thing)
  (cond
    ((typep thing 'quit) :quit)
    ((control-result-p thing) thing)))

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
  (loop with context = (find-room game (game-start game))
	with return-stack = nil
	do (let ((result (evaluate context)))
	     (cond
	       ((eq result :quit)
		(return :quit))
	       ((typep result 'goto)
		(setf context (find-room game (room-name result))))
	       ((typep result 'gosub)
		(push context return-stack)
		(setf context (find-room game (room-name result))))
	       ((typep result 'enter)
		(push context return-stack)
		(setf context (enter-target result)))
	       ((typep result 'back)
		(if return-stack
		    (setf context (pop return-stack))
		    (return result)))
	       (return-stack
		(setf context (pop return-stack)))
	       (t
		(return result))))))

(defmethod evaluate ((room room))
  (format *output* "~&~A~%" (name room))
  (let ((collected-options nil))
    (dolist (entity (entities room))
      (let ((result (or (immediate-control-result entity)
			(describe-entity entity))))
	(when (control-result-p result)
	  (return-from evaluate result)))
      (setf collected-options
	    (append collected-options (copy-list (collect-choices entity)))))
    (if collected-options
	(evaluate (make-instance 'choices :options collected-options))
	room)))

(defmethod describe-entity ((thing t))
  nil)

(defmethod collect-choices ((thing t))
  nil)

(defmethod evaluate ((paragraph p))
  (format *output* "~A~%" (text paragraph)))

(defmethod describe-entity ((paragraph p))
  (evaluate paragraph))

(defmethod evaluate ((choices choices))
  (let ((options (options choices)))
    (loop for option in options
	  for index from 1
	  do (format *output* "~D. ~A~%" index (label option)))
    (let ((index (and options (read-choice-index (length options)))))
      (if index
	  (evaluate (target (nth (1- index) options)))
	  :quit))))

(defmethod collect-choices ((choices choices))
  (options choices))

(defmethod describe-entity ((item item))
  (format *output* "~A~%" (or (description item) (name item))))

(defmethod describe-entity ((container container))
  (when (description container)
    (format *output* "~A~%" (description container))))

(defmethod collect-choices ((container container))
  (when (open-choice container)
    (list (option (open-choice container)
		  (enter (container-view container))))))

(defmethod evaluate ((view container-view))
  (let* ((container (viewed-container view))
	 (collected-options nil))
    (format *output* "~&~A~%" (name container))
    (if (contents container)
	(dolist (entity (contents container))
	  (let ((result (or (immediate-control-result entity)
			    (describe-entity entity))))
	    (when (control-result-p result)
	      (return-from evaluate result)))
	  (setf collected-options
		(append collected-options (copy-list (collect-choices entity)))))
	(format *output* "There is nothing here.~%"))
    (setf collected-options
	  (append collected-options
		  (list (option (or (close-choice container) "Back")
				(back)))))
    (evaluate (make-instance 'choices :options collected-options))))

(defmethod describe-entity ((placement placement))
  (when (placement-description placement)
    (format *output* "~A~%" (placement-description placement))))

(defmethod collect-choices ((placement placement))
  (if (and (interaction-label placement)
	   (interaction-target placement))
      (list (option (interaction-label placement)
		    (interaction-target placement)))
      nil))

;;; Control nodes evaluate to the result object consumed by the game loop.
(defmethod evaluate ((goto goto))
  goto)

(defmethod evaluate ((gosub gosub))
  gosub)

(defmethod evaluate ((enter enter))
  enter)

(defmethod evaluate ((back back))
  back)

(defmethod evaluate ((quit quit))
  :quit)
