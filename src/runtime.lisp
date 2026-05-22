(in-package #:dunge)

;;; Evaluator and console runtime
;;; Control protocol: control AST nodes evaluate to themselves and are
;;; propagated upward unchanged. Rooms with no choices return FALL-THROUGH
;;; instead of returning the room. The game loop consumes these objects and
;;; dispatches on their type.

(defvar *input* *standard-input*)
(defvar *output* *standard-output*)

(defstruct runtime-context
  game
  scene
  self)

(defgeneric evaluate (thing &optional context)
  (:documentation "Evaluate a Dunge CLOS AST node in CONTEXT."))

(defgeneric describe-entity (thing &optional context)
  (:documentation "Describe an AST node as part of a room in CONTEXT."))

(defgeneric collect-choices (thing &optional context)
  (:documentation "Collect a fresh list of choice objects contributed by an AST node in CONTEXT."))

(defgeneric evaluate-expression (thing &optional context)
  (:documentation "Evaluate a Dunge expression AST node in CONTEXT."))

(defgeneric evaluate-condition (thing &optional context)
  (:documentation "Evaluate a Dunge condition AST node in CONTEXT."))

(defgeneric execute-effect (thing &optional context)
  (:documentation "Execute a Dunge effect/control AST node in CONTEXT."))

(defun control-result-p (thing)
  (typep thing 'control-node))

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

(defun runtime-context-for-scene (context scene)
  (make-runtime-context
   :game (and context (runtime-context-game context))
   :scene scene
   :self nil))

(defun runtime-context-for-self (context self)
  (make-runtime-context
   :game (and context (runtime-context-game context))
   :scene (and context (runtime-context-scene context))
   :self self))

(defun describe-children (children context)
  (dolist (child children)
    (let ((result (if (control-result-p child)
                      child
                      (describe-entity child context))))
      (when (control-result-p result)
        (return result)))))

(defmethod evaluate ((game game) &optional context)
  (declare (ignore context))
  (unless (game-start game)
    (error "Cannot evaluate a game with no rooms."))
  (let ((game-context (make-runtime-context :game game)))
    (loop with location = (find-room game (game-start game))
          with return-stack = nil
          do (let* ((location-context
                      (if (typep location 'room)
                          (runtime-context-for-scene game-context location)
                          game-context))
                    (result (evaluate location location-context)))
               (match result
                 ((quit)
                  (return result))
                 ((refresh)
                  nil)
                 ((goto (room-name room-name))
                  (setf location (find-room game room-name)))
                 ((gosub (room-name room-name))
                  (push location return-stack)
                  (setf location (find-room game room-name)))
                 ((enter (target target))
                  (push location return-stack)
                  (setf location target))
                 ((back)
                  (if return-stack
                      (setf location (pop return-stack))
                      (return result)))
                 ((fall-through)
                  (if return-stack
                      (setf location (pop return-stack))
                      (return location)))
                 (_
                  (return result)))))))

(defmethod evaluate ((room room) &optional context)
  (let ((room-context (runtime-context-for-scene context room)))
    (format *output* "~&~A~%" (name room))
    (let ((result (describe-children (entities room) room-context)))
      (when result
        (return-from evaluate result)))
    (let ((collected-options (collect-options-from (entities room) room-context)))
      (if collected-options
          (evaluate (make-instance 'choices :options collected-options) room-context)
          (fall-through)))))

(defmethod describe-entity ((thing t) &optional context)
  (declare (ignore context))
  nil)

(defmethod collect-choices ((thing t) &optional context)
  (declare (ignore context))
  nil)

(defun collect-options-from (things context)
  (loop for thing in things
        append (collect-choices thing context)))

(defun choice-state-key (choice)
  (let ((id (choice-id choice)))
    (unless id
      (error "Once-only choice ~S must declare :ID." (label choice)))
    (choice-id-key id)))

(defun choice-taken-p (choice context)
  (and (choice-once-p choice)
       context
       (runtime-context-game context)
       (gethash (choice-state-key choice)
                (game-taken-choices (runtime-context-game context)))))

(defun choice-visible-p (choice context)
  (and (not (choice-taken-p choice context))
       (or (null (choice-condition choice))
           (evaluate-condition (choice-condition choice) context))))

(defun mark-choice-taken (choice context)
  (when (choice-once-p choice)
    (unless (and context (runtime-context-game context))
      (error "Cannot mark once-only choice ~S without a current game."
             (label choice)))
    (setf (gethash (choice-state-key choice)
                   (game-taken-choices (runtime-context-game context)))
          t)))

(defmethod evaluate ((paragraph p) &optional context)
  (declare (ignore context))
  (format *output* "~A~%" (text paragraph)))

(defmethod describe-entity ((paragraph p) &optional context)
  (evaluate paragraph context))

(defmethod evaluate ((choices choices) &optional context)
  (let ((options (remove-if-not (lambda (choice)
                                  (choice-visible-p choice context))
                                (options choices))))
    (loop for option in options
          for index from 1
          do (format *output* "~D. ~A~%" index (label option)))
    (let ((index (and options (read-choice-index (length options)))))
      (if index
          (let ((option (elt options (1- index))))
            (mark-choice-taken option context)
            (evaluate (target option) context))
          (quit)))))

(defmethod evaluate ((effect effect-node) &optional context)
  (execute-effect effect context))

(defmethod collect-choices ((choices choices) &optional context)
  (loop for choice in (options choices)
        when (choice-visible-p choice context)
          collect choice))

(defmethod collect-choices ((choice choice) &optional context)
  (when (choice-visible-p choice context)
    (list choice)))

(defmethod describe-entity ((entity entity) &optional context)
  (describe-children (entities entity)
                     (runtime-context-for-self context entity)))

(defmethod collect-choices ((entity entity) &optional context)
  (collect-options-from (entities entity)
                        (runtime-context-for-self context entity)))

(defun active-branch-entities (branch context)
  (if (evaluate-condition (branch-condition branch) context)
      (branch-then-entities branch)
      (branch-else-entities branch)))

(defmethod describe-entity ((branch branch) &optional context)
  (describe-children (active-branch-entities branch context) context))

(defmethod collect-choices ((branch branch) &optional context)
  (collect-options-from (active-branch-entities branch context) context))

(defmethod describe-entity ((action action) &optional context)
  (declare (ignore context))
  nil)

(defmethod collect-choices ((action action) &optional context)
  (declare (ignore context))
  (unless (action-owner action)
    (error "Action ~S is not inside an entity." (label action)))
  (list (option (label action)
                action)))

(defmethod evaluate ((action action) &optional context)
  (unless (action-owner action)
    (error "Action ~S is not inside an entity." (label action)))
  (let* ((action-context (runtime-context-for-self context
                                                   (action-owner action)))
         (result (evaluate-effects (effects action) action-context)))
    (or result (refresh))))

(defmethod describe-entity ((item item) &optional context)
  (declare (ignore context))
  (format *output* "~A~%" (or (description item) (name item))))

(defmethod describe-entity ((container container) &optional context)
  (declare (ignore context))
  (when (description container)
    (format *output* "~A~%" (description container))))

(defmethod collect-choices ((container container) &optional context)
  (declare (ignore context))
  (when (open-choice container)
    (list (option (open-choice container)
                  (enter (container-view container))))))

(defmethod evaluate ((view container-view) &optional context)
  (let* ((container (viewed-container view))
         (collected-options nil))
    (format *output* "~&~A~%" (name container))
    (if (contents container)
        (let ((result (describe-children (contents container) context)))
          (when result
            (return-from evaluate result)))
        (format *output* "There is nothing here.~%"))
    (setf collected-options (collect-options-from (contents container) context))
    (setf collected-options
          (append collected-options
                  (list (option (or (close-choice container) "Back")
                                (back)))))
    (evaluate (make-instance 'choices :options collected-options) context)))

(defmethod describe-entity ((placement placement) &optional context)
  (declare (ignore context))
  (when (placement-description placement)
    (format *output* "~A~%" (placement-description placement))))

(defmethod collect-choices ((placement placement) &optional context)
  (declare (ignore context))
  (if (and (interaction-label placement)
           (interaction-target placement))
      (list (option (interaction-label placement)
                    (interaction-target placement)))
      nil))

(defun resolve-state-reference (reference context)
  (ecase (state-ref-scope reference)
    (:self
     (unless (and context (runtime-context-self context))
       (error "Cannot resolve SELF state without a current entity."))
     (values (local-state (runtime-context-self context))
             (state-key (state-ref-key reference))))
    (:global
     (unless (and context (runtime-context-game context))
       (error "Cannot resolve GLOBAL state without a current game."))
     (values (game-global-state (runtime-context-game context))
             (state-key (state-ref-key reference))))
    (:ref
     (unless (and context (runtime-context-self context))
       (error "Cannot resolve REF state without a current entity."))
     (let* ((role-key (ref-role-key (state-ref-role reference)))
            (self (runtime-context-self context))
            (target (gethash role-key (resolved-refs self))))
       (unless target
         (error "Entity ~S has no declared ref named ~S."
                (or (entity-id self) (name self))
                (state-ref-role reference)))
       (values (local-state target)
               (state-key (state-ref-key reference)))))))

(defun state-reference-value (reference context)
  (multiple-value-bind (table key) (resolve-state-reference reference context)
    (gethash key table)))

(defun set-state-reference-value (reference value context)
  (multiple-value-bind (table key) (resolve-state-reference reference context)
    (setf (gethash key table) value)))

(defun clear-state-reference-value (reference context)
  (multiple-value-bind (table key) (resolve-state-reference reference context)
    (remhash key table)))

(defun toggled-value (value)
  (cond
    ((eq value :on) :off)
    ((eq value :off) :on)
    ((eq value t) nil)
    ((null value) t)
    (t (error "Cannot toggle value ~S." value))))

(defmethod evaluate-expression ((expression t) &optional context)
  (declare (ignore context))
  expression)

(defmethod evaluate-expression ((reference state-ref) &optional context)
  (state-reference-value reference context))

(defmethod evaluate-condition ((condition t) &optional context)
  (not (null (evaluate-expression condition context))))

(defmethod evaluate-condition ((condition condition-eq) &optional context)
  (equal (evaluate-expression (condition-left condition) context)
         (evaluate-expression (condition-right condition) context)))

(defmethod evaluate-condition ((condition condition-not) &optional context)
  (not (evaluate-condition (condition-child condition) context)))

(defmethod evaluate-condition ((condition condition-and) &optional context)
  (every (lambda (condition)
           (evaluate-condition condition context))
         (conditions condition)))

(defmethod evaluate-condition ((condition condition-or) &optional context)
  (some (lambda (condition)
          (evaluate-condition condition context))
        (conditions condition)))

(defmethod execute-effect ((effect sequence) &optional context)
  (dolist (child (sequence-effects effect))
    (let ((result (execute-effect child context)))
      (when (control-result-p result)
        (return result)))))

(defmethod execute-effect ((effect state-set) &optional context)
  (set-state-reference-value (effect-target effect)
                             (evaluate-expression (effect-value effect) context)
                             context)
  nil)

(defmethod execute-effect ((effect state-clear) &optional context)
  (clear-state-reference-value (effect-target effect) context)
  nil)

(defun numeric-state-value (reference context)
  (let ((value (or (state-reference-value reference context) 0)))
    (unless (numberp value)
      (error "Cannot increment non-numeric state value ~S." value))
    value))

(defmethod execute-effect ((effect state-inc) &optional context)
  (set-state-reference-value
   (effect-target effect)
   (+ (numeric-state-value (effect-target effect) context)
      (evaluate-expression (effect-amount effect) context))
   context)
  nil)

(defmethod execute-effect ((effect state-dec) &optional context)
  (set-state-reference-value
   (effect-target effect)
   (- (numeric-state-value (effect-target effect) context)
      (evaluate-expression (effect-amount effect) context))
   context)
  nil)

(defmethod execute-effect ((effect state-toggle) &optional context)
  (set-state-reference-value
   (effect-target effect)
   (toggled-value (state-reference-value (effect-target effect) context))
   context)
  nil)

(defmethod execute-effect ((effect say) &optional context)
  (format *output* "~A~%" (evaluate-expression (say-text effect) context))
  nil)

(defmethod execute-effect ((effect conditional-effect) &optional context)
  (execute-effect
   (or (if (evaluate-condition (conditional-effect-condition effect) context)
           (conditional-effect-then effect)
           (conditional-effect-else effect))
       (sequence))
   context))

(defun evaluate-effects (effects context)
  (cond
    ((null effects)
     nil)
    ((listp effects)
     (error "Effect lists are not executable; use (sequence ...) instead."))
    (t
     (execute-effect effects context))))

(defmethod execute-effect ((effect goto) &optional context)
  (goto (evaluate-expression (room-name effect) context)))

(defmethod execute-effect ((effect gosub) &optional context)
  (gosub (evaluate-expression (room-name effect) context)))

(defmethod execute-effect ((effect enter) &optional context)
  (declare (ignore context))
  effect)

(defmethod execute-effect ((effect back) &optional context)
  (declare (ignore context))
  effect)

(defmethod execute-effect ((effect quit) &optional context)
  (declare (ignore context))
  effect)

(defmethod execute-effect ((effect refresh) &optional context)
  (declare (ignore context))
  effect)

(defmethod execute-effect ((effects cons) &optional context)
  (declare (ignore effects context))
  (error "Effect lists are not executable; use (sequence ...) instead."))

(defmethod execute-effect ((effect t) &optional context)
  (declare (ignore context))
  (error "Cannot execute ~S as an effect." effect))

;;; Control nodes evaluate to the result object consumed by the game loop.
(defmethod evaluate ((goto goto) &optional context)
  (declare (ignore context))
  goto)

(defmethod evaluate ((gosub gosub) &optional context)
  (declare (ignore context))
  gosub)

(defmethod evaluate ((enter enter) &optional context)
  (declare (ignore context))
  enter)

(defmethod evaluate ((back back) &optional context)
  (declare (ignore context))
  back)

(defmethod evaluate ((quit quit) &optional context)
  (declare (ignore context))
  quit)

(defmethod evaluate ((refresh refresh) &optional context)
  (declare (ignore context))
  refresh)
