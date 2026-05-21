(in-package #:dunge)

;;; Evaluator and console runtime

(defvar *input* *standard-input*)
(defvar *output* *standard-output*)
(defvar *game* nil)
(defvar *scene* nil)
(defvar *self* nil)

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
      (typep thing 'refresh)
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
  (let ((*game* game))
    (loop with context = (find-room game (game-start game))
	  with return-stack = nil
	  do (let ((result (evaluate context)))
	       (cond
		 ((eq result :quit)
		  (return :quit))
		 ((typep result 'refresh)
		  nil)
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
		  (return result)))))))

(defmethod evaluate ((room room))
  (let ((*scene* room)
	(*self* nil))
    (format *output* "~&~A~%" (name room))
    (dolist (entity (entities room))
      (let ((result (or (immediate-control-result entity)
			(describe-entity entity))))
	(when (control-result-p result)
	  (return-from evaluate result))))
    (let ((collected-options (collect-options-from (entities room))))
      (if collected-options
	  (evaluate (make-instance 'choices :options collected-options))
	  room))))

(defmethod describe-entity ((thing t))
  nil)

(defmethod collect-choices ((thing t))
  nil)

(defun collect-options-from (things)
  (loop for thing in things
	append (copy-list (collect-choices thing))))

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

(defmethod describe-entity ((entity entity))
  (let ((*self* entity))
    (dolist (child (entities entity))
      (let ((result (or (immediate-control-result child)
			(describe-entity child))))
	(when (control-result-p result)
	  (return-from describe-entity result)))))
  nil)

(defmethod collect-choices ((entity entity))
  (let ((*self* entity))
    (collect-options-from (entities entity))))

(defmethod describe-entity ((conditional conditional))
  (when (evaluate-condition (conditional-condition conditional))
    (dolist (child (entities conditional))
      (let ((result (or (immediate-control-result child)
			(describe-entity child))))
	(when (control-result-p result)
	  (return-from describe-entity result)))))
  nil)

(defmethod collect-choices ((conditional conditional))
  (when (evaluate-condition (conditional-condition conditional))
    (collect-options-from (entities conditional))))

(defmethod describe-entity ((action action))
  nil)

(defmethod collect-choices ((action action))
  (unless *self*
    (error "Action ~S is not inside an entity." (label action)))
  (list (option (label action)
		(action-invocation *self* action))))

(defmethod evaluate ((invocation action-invocation))
  (let ((*self* (action-owner invocation)))
    (let ((result (evaluate-effects (effects (invoked-action invocation)))))
      (or result (refresh)))))

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
	      (return-from evaluate result))))
	(format *output* "There is nothing here.~%"))
    (setf collected-options (collect-options-from (contents container)))
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

(defun split-reference-path (symbol)
  (let ((name (string-downcase (symbol-name symbol)))
	(start 0)
	(parts nil))
    (loop for dot = (position #\. name :start start)
	  do (push (subseq name start dot) parts)
	  while dot
	  do (setf start (1+ dot)))
    (nreverse parts)))

(defun state-path-symbol-p (thing)
  (and (symbolp thing)
       (find #\. (symbol-name thing))))

(defun resolve-state-path (path)
  (let ((parts (split-reference-path path)))
    (destructuring-bind (scope &rest rest) parts
      (cond
	((string= scope "self")
	 (unless *self*
	   (error "Cannot resolve ~S without a current entity." path))
	 (unless (= (length rest) 1)
	   (error "State path ~S must look like self.name." path))
	 (values (local-state *self*) (first rest)))
	((string= scope "global")
	 (unless *game*
	   (error "Cannot resolve ~S without a current game." path))
	 (unless (= (length rest) 1)
	   (error "State path ~S must look like global.name." path))
	 (values (game-global-state *game*) (first rest)))
	((string= scope "ref")
	 (unless *self*
	   (error "Cannot resolve ~S without a current entity." path))
	 (unless (= (length rest) 2)
	   (error "State path ~S must look like ref.name.state." path))
	 (let ((target (gethash (first rest) (resolved-refs *self*))))
	   (unless target
	     (error "Entity ~S has no declared ref named ~S."
		    (or (entity-id *self*) (name *self*))
		    (first rest)))
	   (values (local-state target) (second rest))))
	(t
	 (error "Unknown state path scope ~S in ~S." scope path))))))

(defun state-path-value (path)
  (multiple-value-bind (table key) (resolve-state-path path)
    (gethash key table)))

(defun set-state-path-value (path value)
  (multiple-value-bind (table key) (resolve-state-path path)
    (setf (gethash key table) value)))

(defun toggled-value (value)
  (cond
    ((eq value :on) :off)
    ((eq value :off) :on)
    ((eq value t) nil)
    ((null value) t)
    (t (error "Cannot toggle value ~S." value))))

(defun evaluate-expression (expression)
  (if (state-path-symbol-p expression)
      (state-path-value expression)
      expression))

(defun operator-name (operator)
  (unless (symbolp operator)
    (error "DSL operator must be a symbol, got ~S." operator))
  (string-downcase (symbol-name operator)))

(defun evaluate-condition (condition)
  (cond
    ((atom condition)
     (not (null (evaluate-expression condition))))
    (t
     (let ((operator (operator-name (first condition)))
	   (arguments (rest condition)))
       (cond
	 ((member operator '("=" "is" "eq") :test #'string=)
	  (destructuring-bind (left right) arguments
	    (equal (evaluate-expression left)
		   (evaluate-expression right))))
	 ((string= operator "not")
	  (destructuring-bind (argument) arguments
	    (not (evaluate-condition argument))))
	 ((string= operator "and")
	  (every #'evaluate-condition arguments))
	 ((string= operator "or")
	  (some #'evaluate-condition arguments))
	 (t
	  (error "Unknown condition operator ~S." (first condition))))))))

(defun effect-operator-p (thing)
  (and (symbolp thing)
       (member (operator-name thing)
	       '("say" "set" "toggle" "if" "goto" "gosub" "back" "quit")
	       :test #'string=)))

(defun normalize-effect-list (branch)
  (cond
    ((null branch) nil)
    ((and (consp branch)
	  (effect-operator-p (first branch)))
     (list branch))
    (t branch)))

(defun evaluate-effects (effects)
  (dolist (effect effects)
    (let ((result (evaluate-effect effect)))
      (when (control-result-p result)
	(return result)))))

(defun evaluate-effect (effect)
  (unless (consp effect)
    (error "Effect must be a list, got ~S." effect))
  (let ((operator (operator-name (first effect)))
	(arguments (rest effect)))
    (cond
      ((string= operator "say")
       (destructuring-bind (text) arguments
	 (format *output* "~A~%" (evaluate-expression text))))
      ((string= operator "set")
       (destructuring-bind (path value) arguments
	 (unless (state-path-symbol-p path)
	   (error "SET target must be a state path, got ~S." path))
	 (set-state-path-value path (evaluate-expression value))
	 nil))
      ((string= operator "toggle")
       (destructuring-bind (path) arguments
	 (unless (state-path-symbol-p path)
	   (error "TOGGLE target must be a state path, got ~S." path))
	 (set-state-path-value path
			       (toggled-value (state-path-value path)))))
      ((string= operator "if")
       (destructuring-bind (condition then-branch &optional else-branch) arguments
	 (evaluate-effects
	  (normalize-effect-list
	   (if (evaluate-condition condition)
	       then-branch
	       else-branch)))))
      ((string= operator "goto")
       (destructuring-bind (room-name) arguments
	 (goto (evaluate-expression room-name))))
      ((string= operator "gosub")
       (destructuring-bind (room-name) arguments
	 (gosub (evaluate-expression room-name))))
      ((string= operator "back")
       (back))
      ((string= operator "quit")
       :quit)
      (t
       (error "Unknown effect operator ~S." (first effect))))))

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

(defmethod evaluate ((refresh refresh))
  refresh)
