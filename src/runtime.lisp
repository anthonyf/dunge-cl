(in-package #:dunge)

;;; Evaluator and console runtime
;;; Control protocol: control AST nodes evaluate to themselves and are
;;; propagated upward unchanged. Rooms with no choices return FALL-THROUGH
;;; instead of returning the room. The game loop consumes these objects and
;;; dispatches on their type.

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

;;; FALL-THROUGH is defined in this file and matched by TRIVIA below, so the
;;; class must exist while the EVALUATE method is compiled.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defclass fall-through ()
    ()))

(defun fall-through ()
  (make-instance 'fall-through))

(defun control-result-p (thing)
  (or (typep thing 'control-node)
      (typep thing 'fall-through)))

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
	       (match result
		 ((quit)
		  (return result))
		 ((refresh)
		  nil)
		 ((goto (room-name room-name))
		  (setf context (find-room game room-name)))
		 ((gosub (room-name room-name))
		  (push context return-stack)
		  (setf context (find-room game room-name)))
		 ((enter (target target))
		  (push context return-stack)
		  (setf context target))
		 ((back)
		  (if return-stack
		      (setf context (pop return-stack))
		      (return result)))
		 ((fall-through)
		  (if return-stack
		      (setf context (pop return-stack))
		      (return context)))
		 (_
		  (return result)))))))

(defmethod evaluate ((room room))
  (let ((*scene* room)
	(*self* nil))
    (format *output* "~&~A~%" (name room))
    (dolist (entity (entities room))
      (let ((result (if (control-result-p entity)
			entity
			(describe-entity entity))))
	(when (control-result-p result)
	  (return-from evaluate result))))
    (let ((collected-options (collect-options-from (entities room))))
      (if collected-options
	  (evaluate (make-instance 'choices :options collected-options))
	  (fall-through)))))

(defmethod describe-entity ((thing t))
  nil)

(defmethod collect-choices ((thing t))
  nil)

(defun collect-options-from (things)
  (loop for thing in things
	append (copy-list (collect-choices thing))))

(defun choice-state-key (choice)
  (let ((id (choice-id choice)))
    (unless id
      (error "Once-only choice ~S must declare :ID." (label choice)))
    (normalize-id-key id)))

(defun choice-taken-p (choice)
  (and (choice-once-p choice)
       *game*
       (gethash (choice-state-key choice) (game-taken-choices *game*))))

(defun choice-visible-p (choice)
  (and (not (choice-taken-p choice))
       (or (null (choice-condition choice))
	   (evaluate-condition (choice-condition choice)))))

(defun mark-choice-taken (choice)
  (when (choice-once-p choice)
    (unless *game*
      (error "Cannot mark once-only choice ~S without a current game."
	     (label choice)))
    (setf (gethash (choice-state-key choice) (game-taken-choices *game*)) t)))

(defmethod evaluate ((paragraph p))
  (format *output* "~A~%" (text paragraph)))

(defmethod describe-entity ((paragraph p))
  (evaluate paragraph))

(defmethod evaluate ((choices choices))
  (let ((options (remove-if-not #'choice-visible-p (options choices))))
    (loop for option in options
	  for index from 1
	  do (format *output* "~D. ~A~%" index (label option)))
    (let ((index (and options (read-choice-index (length options)))))
      (if index
	  (let ((option (elt options (1- index))))
	    (mark-choice-taken option)
	    (evaluate (target option)))
	  (quit)))))

(defmethod evaluate ((effect effect-node))
  (execute-effect effect))

(defmethod collect-choices ((choices choices))
  (remove-if-not #'choice-visible-p (options choices)))

(defmethod collect-choices ((choice choice))
  (when (choice-visible-p choice)
    (list choice)))

(defmethod describe-entity ((entity entity))
  (let ((*self* entity))
    (dolist (child (entities entity))
      (let ((result (if (control-result-p child)
			child
			(describe-entity child))))
	(when (control-result-p result)
	  (return-from describe-entity result)))))
  nil)

(defmethod collect-choices ((entity entity))
  (let ((*self* entity))
    (collect-options-from (entities entity))))

(defun active-branch-entities (branch)
  (if (evaluate-condition (branch-condition branch))
      (branch-then-entities branch)
      (branch-else-entities branch)))

(defmethod describe-entity ((branch branch))
  (dolist (child (active-branch-entities branch))
    (let ((result (if (control-result-p child)
		      child
		      (describe-entity child))))
      (when (control-result-p result)
	(return-from describe-entity result))))
  nil)

(defmethod collect-choices ((branch branch))
  (collect-options-from (active-branch-entities branch)))

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
	  (let ((result (if (control-result-p entity)
			    entity
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

(defun state-reference-value (reference)
  (multiple-value-bind (table key) (resolve-state-reference reference)
    (gethash key table)))

(defun set-state-reference-value (reference value)
  (multiple-value-bind (table key) (resolve-state-reference reference)
    (setf (gethash key table) value)))

(defun clear-state-reference-value (reference)
  (multiple-value-bind (table key) (resolve-state-reference reference)
    (remhash key table)))

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
   (or (if (evaluate-condition (conditional-effect-condition effect))
	   (conditional-effect-then effect)
	   (conditional-effect-else effect))
       (sequence))))

(defun evaluate-effects (effects)
  (cond
    ((null effects)
     nil)
    ((listp effects)
     (error "Effect lists are not executable; use (sequence ...) instead."))
    (t
     (execute-effect effects))))

(defmethod execute-effect ((effect goto))
  (goto (evaluate-expression (room-name effect))))

(defmethod execute-effect ((effect gosub))
  (gosub (evaluate-expression (room-name effect))))

(defmethod execute-effect ((effect enter))
  effect)

(defmethod execute-effect ((effect back))
  effect)

(defmethod execute-effect ((effect quit))
  effect)

(defmethod execute-effect ((effect refresh))
  effect)

(defmethod execute-effect ((effects cons))
  (declare (ignore effects))
  (error "Effect lists are not executable; use (sequence ...) instead."))

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
  quit)

(defmethod evaluate ((refresh refresh))
  refresh)
