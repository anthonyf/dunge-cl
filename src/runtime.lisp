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

(defgeneric evaluate-expression (thing)
  (:documentation "Evaluate a Dunge expression AST node."))

(defgeneric evaluate-condition (thing)
  (:documentation "Evaluate a Dunge condition AST node."))

(defgeneric execute-effect (thing)
  (:documentation "Execute a Dunge effect/control AST node."))

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

(defmethod evaluate ((effect effect-node))
  (execute-effect effect))

(defmethod collect-choices ((choices choices))
  (options choices))

(defmethod collect-choices ((choice choice))
  (list choice))

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
    (let ((result (execute-effect (effects (invoked-action invocation)))))
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

(defun resolve-state-reference (reference)
  (ecase (state-ref-scope reference)
    (:self
     (unless *self*
       (error "Cannot resolve SELF state without a current entity."))
     (values (local-state *self*)
	     (normalize-state-key (state-ref-key reference))))
    (:global
     (unless *game*
       (error "Cannot resolve GLOBAL state without a current game."))
     (values (game-global-state *game*)
	     (normalize-state-key (state-ref-key reference))))
    (:ref
     (unless *self*
       (error "Cannot resolve REF state without a current entity."))
     (let* ((role-key (normalize-state-key (state-ref-role reference)))
	    (target (gethash role-key (resolved-refs *self*))))
       (unless target
	 (error "Entity ~S has no declared ref named ~S."
		(or (entity-id *self*) (name *self*))
		(state-ref-role reference)))
       (values (local-state target)
	       (normalize-state-key (state-ref-key reference)))))))

(defun resolve-state-path (path)
  (resolve-state-reference (state-ref-from-path path)))

(defun state-reference-value (reference)
  (multiple-value-bind (table key) (resolve-state-reference reference)
    (gethash key table)))

(defun set-state-reference-value (reference value)
  (multiple-value-bind (table key) (resolve-state-reference reference)
    (setf (gethash key table) value)))

(defun clear-state-reference-value (reference)
  (multiple-value-bind (table key) (resolve-state-reference reference)
    (remhash key table)))

(defun state-path-value (path)
  (state-reference-value (state-ref-from-path path)))

(defun set-state-path-value (path value)
  (set-state-reference-value (state-ref-from-path path) value))

(defun toggled-value (value)
  (cond
    ((eq value :on) :off)
    ((eq value :off) :on)
    ((eq value t) nil)
    ((null value) t)
    (t (error "Cannot toggle value ~S." value))))

(defmethod evaluate-expression ((expression t))
  expression)

(defmethod evaluate-expression ((reference state-ref))
  (state-reference-value reference))

(defmethod evaluate-condition ((condition t))
  (not (null (evaluate-expression condition))))

(defmethod evaluate-condition ((condition condition-eq))
  (equal (evaluate-expression (condition-left condition))
	 (evaluate-expression (condition-right condition))))

(defmethod evaluate-condition ((condition condition-not))
  (not (evaluate-condition (condition-child condition))))

(defmethod evaluate-condition ((condition condition-and))
  (every #'evaluate-condition (conditions condition)))

(defmethod evaluate-condition ((condition condition-or))
  (some #'evaluate-condition (conditions condition)))

(defmethod execute-effect ((effect sequence))
  (dolist (child (sequence-effects effect))
    (let ((result (execute-effect child)))
      (when (control-result-p result)
	(return result)))))

(defmethod execute-effect ((effect state-set))
  (set-state-reference-value (effect-target effect)
			     (evaluate-expression (effect-value effect)))
  nil)

(defmethod execute-effect ((effect state-clear))
  (clear-state-reference-value (effect-target effect))
  nil)

(defun numeric-state-value (reference)
  (let ((value (or (state-reference-value reference) 0)))
    (unless (numberp value)
      (error "Cannot increment non-numeric state value ~S." value))
    value))

(defmethod execute-effect ((effect state-inc))
  (set-state-reference-value
   (effect-target effect)
   (+ (numeric-state-value (effect-target effect))
      (evaluate-expression (effect-amount effect))))
  nil)

(defmethod execute-effect ((effect state-dec))
  (set-state-reference-value
   (effect-target effect)
   (- (numeric-state-value (effect-target effect))
      (evaluate-expression (effect-amount effect))))
  nil)

(defmethod execute-effect ((effect state-toggle))
  (set-state-reference-value
   (effect-target effect)
   (toggled-value (state-reference-value (effect-target effect))))
  nil)

(defmethod execute-effect ((effect say))
  (format *output* "~A~%" (evaluate-expression (say-text effect)))
  nil)

(defmethod execute-effect ((effect conditional-effect))
  (execute-effect
   (if (evaluate-condition (conditional-effect-condition effect))
       (conditional-effect-then effect)
       (conditional-effect-else effect))))

(defun evaluate-effects (effects)
  (execute-effect
   (if (typep effects 'sequence)
       effects
       (make-instance 'sequence :effects effects))))

(defmethod execute-effect ((effect goto))
  (goto (evaluate-expression (room-name effect))))

(defmethod execute-effect ((effect gosub))
  (gosub (evaluate-expression (room-name effect))))

(defmethod execute-effect ((effect enter))
  effect)

(defmethod execute-effect ((effect back))
  effect)

(defmethod execute-effect ((effect quit))
  :quit)

(defmethod execute-effect ((effect refresh))
  effect)

(defmethod execute-effect ((effect t))
  (error "Cannot execute ~S as an effect." effect))

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
