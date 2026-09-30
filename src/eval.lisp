(in-package #:dunge)

;;; Evaluation
;;;
;;; Describing and collecting content, reading and changing state, and
;;; evaluating expressions, conditions, and effects.

(defmethod describe-entity ((thing t) context)
  (declare (ignore context))
  nil)

(defmethod collect-choices ((thing t) context)
  (declare (ignore context))
  nil)

(defun collect-options-from (things context)
  (loop for thing in things
        append (collect-choices thing context)))

(defun choice-state-key (choice)
  (let ((id (consumable-id choice)))
    (unless id
      (error "Once-only choice ~S must declare :ID." (label choice)))
    (choice-id-key id)))

(defun choice-taken-p (choice context)
  (and (consumable-once-p choice)
       context
       (runtime-context-world context)
       (gethash (choice-state-key choice)
                (world-taken (runtime-context-world context)))))

(defun choice-visible-p (choice context)
  (available-p choice context))

(defun mark-choice-taken (choice context)
  (when (consumable-once-p choice)
    (unless (and context (runtime-context-world context))
      (error "Cannot mark once-only choice ~S without a world."
             (label choice)))
    (setf (gethash (choice-state-key choice)
                   (world-taken (runtime-context-world context)))
          t)))

(defmethod consumed-p ((choice choice) context)
  (choice-taken-p choice context))

(defmethod consume-node ((choice choice) context)
  (mark-choice-taken choice context))

(defmethod evaluate ((paragraph p) &optional context)
  (render-pending-choice-spacing)
  (format *output* "~A~%~%"
          (format-dunge-value (evaluate-expression (text paragraph) context))))

(defmethod describe-entity ((paragraph p) context)
  (evaluate paragraph context))

;;; Effects can be reached as a choice target through EVALUATE, or inside a
;;; sequence through EXECUTE-EFFECT directly. This bridge keeps both paths
;;; equivalent while preserving CLOS dispatch over choice target unions.
(defmethod evaluate ((effect effect-node) &optional context)
  (or (execute-effect effect context)
      (%make-refresh)))

(defmethod collect-choices ((choices choices) context)
  (loop for choice in (options choices)
        when (choice-visible-p choice context)
          collect choice))

(defmethod collect-choices ((choice choice) context)
  (when (choice-visible-p choice context)
    (list choice)))

(defmethod describe-entity ((entity entity) context)
  (describe-children (entities entity)
                     (runtime-context-for-self context entity)))

(defmethod collect-choices ((entity entity) context)
  (collect-options-from (entities entity)
                        (runtime-context-for-self context entity)))

(defun active-branch-entities (branch context)
  (if (evaluate-condition (branch-condition branch) context)
      (branch-then-entities branch)
      (branch-else-entities branch)))

(defmethod describe-entity ((branch branch) context)
  (describe-children (active-branch-entities branch context) context))

(defmethod collect-choices ((branch branch) context)
  (collect-options-from (active-branch-entities branch context) context))

(defmethod describe-entity ((action action) context)
  (declare (ignore context))
  nil)

(defmethod collect-choices ((action action) context)
  (declare (ignore context))
  (unless (action-owner action)
    (error "Action ~S is not inside an entity." (label action)))
  (list (%make-choice :label (label action)
                      :target action)))

(defmethod evaluate ((action action) &optional context)
  (unless (action-owner action)
    (error "Action ~S is not inside an entity." (label action)))
  (let* ((action-context (runtime-context-for-self context
                                                   (action-owner action)))
         (result (evaluate-effects (effects action) action-context)))
    (or result (%make-refresh))))

(defmethod describe-entity ((item item) context)
  (declare (ignore context))
  (format *output* "~A~%" (or (description item) (name item))))

(defmethod describe-entity ((container container) context)
  (declare (ignore context))
  (when (description container)
    (format *output* "~A~%" (description container))))

(defmethod collect-choices ((container container) context)
  (declare (ignore context))
  (when (open-choice container)
    (list (%make-choice :label (open-choice container)
                        :target (%make-enter
                                 :target (%make-container-view
                                          :container container))))))

(defmethod describe-entity ((placement placement) context)
  (declare (ignore context))
  (when (placement-description placement)
    (format *output* "~A~%" (placement-description placement))))

(defmethod collect-choices ((placement placement) context)
  (declare (ignore context))
  (if (and (interaction-label placement)
           (interaction-target placement))
      (list (%make-choice :label (interaction-label placement)
                          :target (interaction-target placement)))
      nil))

(defun entity-state-name (entity)
  (or (entity-id entity) (name entity)))

(defun declared-state-keys (entity)
  (loop for declaration in (state-declarations entity)
        collect (destructuring-bind (key value) declaration
                  (declare (ignore value))
                  (state-key key))))

(defun declared-state-initial-value (entity key)
  (dolist (declaration (state-declarations entity))
    (destructuring-bind (declared-key value) declaration
      (when (eql (state-key declared-key) key)
        (return value)))))

(defun ensure-declared-state-key (entity key)
  (let ((state-key (state-key key))
        (declared-keys (declared-state-keys entity)))
    (unless (member state-key declared-keys :test #'eql)
      (error "Entity ~S has no declared state key ~S. Declared keys: ~S."
             (entity-state-name entity)
             state-key
             declared-keys))
    state-key))

(defun context-world (context)
  (or (and context (runtime-context-world context))
      (error "Cannot read or change state without a world.")))

(defun resolve-state-reference (reference context)
  (ecase (state-ref-scope reference)
    (:self
     (unless (and context (runtime-context-self context))
       (error "Cannot resolve SELF state without a current entity."))
     (let* ((self (runtime-context-self context))
            (key (ensure-declared-state-key self (state-ref-key reference))))
       (values (entity-state (context-world context) self)
               key
               self)))
    (:global
     (let ((game (runtime-context-game context)))
       (values (world-globals (context-world context))
               (if game
                   (ensure-declared-global-state-key game (state-ref-key reference))
                   (state-key (state-ref-key reference))))))
    (:player
     (unless (and context (runtime-context-game context))
       (error "Cannot resolve PLAYER state without a current game."))
     (values (world-player (context-world context))
             (ensure-declared-player-state-key
              (runtime-context-game context)
              (state-ref-key reference))))
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
       (let ((key (ensure-declared-state-key target (state-ref-key reference))))
         (values (entity-state (context-world context) target)
                 key
                 target))))))

(defun state-reference-value (reference context)
  (multiple-value-bind (table key) (resolve-state-reference reference context)
    (gethash key table)))

(defun set-state-reference-value (reference value context)
  (multiple-value-bind (table key) (resolve-state-reference reference context)
    (setf (gethash key table) value)))

(defun clear-state-reference-value (reference context)
  (multiple-value-bind (table key) (resolve-state-reference reference context)
    (remhash key table)))

(defun toggled-value (value on-value off-value)
  (cond
    ((eql value on-value) off-value)
    ((eql value off-value) on-value)
    (t (error "Cannot toggle value ~S." value))))

(defun declared-toggle-pair (entity key)
  (let ((initial-value (declared-state-initial-value entity key)))
    (cond
      ((or (eq initial-value t)
           (null initial-value))
       (values t nil t))
      ((member initial-value '(:on :off) :test #'eq)
       (values :on :off t))
      (t
       (values nil nil nil)))))

(defun global-toggled-value (value)
  (cond
    ((eq value :on) :off)
    ((eq value :off) :on)
    ((eq value t) nil)
    ((null value) t)
    (t (error "Cannot toggle value ~S." value))))

(defun toggle-state-reference-value (reference context)
  (multiple-value-bind (table key entity) (resolve-state-reference reference context)
    (setf (gethash key table)
          (if entity
              (multiple-value-bind (on-value off-value toggle-pair-p)
                  (declared-toggle-pair entity key)
                (let ((current-value (gethash key table)))
                  (unless toggle-pair-p
                    (error "Cannot toggle value ~S." current-value))
                  (toggled-value current-value on-value off-value)))
              (global-toggled-value (gethash key table))))))

(defmethod evaluate-expression ((expression t) context)
  (declare (ignore context))
  expression)

(defmethod evaluate-expression ((reference state-ref) context)
  (state-reference-value reference context))

(defun format-dunge-value (value)
  "Render VALUE as text the way both runtimes do: strings as written,
integers in decimal, keywords as their lower-case name, T as \"true\", and
NIL (including cleared or unset state) as the empty string."
  (cond
    ((stringp value) value)
    ((integerp value) (format nil "~D" value))
    ((null value) "")
    ((eq value t) "true")
    ((keywordp value) (string-downcase (symbol-name value)))
    (t (error "Cannot display value ~S." value))))

(defun integer-operand (value)
  "Return VALUE as an arithmetic operand. NIL, as for unset state, counts as 0."
  (cond
    ((null value) 0)
    ((integerp value) value)
    (t (error "Arithmetic needs integer values; got \"~A\"."
              (format-dunge-value value)))))

(defun checked-integer (value)
  (unless (safe-integer-p value)
    (error "Arithmetic result is outside the supported integer range."))
  value)

(defun arithmetic-function (operator)
  (ecase operator
    (:add #'+)
    (:sub #'-)
    (:mul #'*)
    (:min #'min)
    (:max #'max)))

(defmethod evaluate-expression ((expression arithmetic) context)
  ;; Evaluate and combine operands left to right, checking each step, so the
  ;; first error is the same one the browser runtime reports.
  (let ((function (arithmetic-function (arithmetic-operator expression)))
        (result nil))
    (dolist (operand (arithmetic-operands expression) result)
      (let ((value (integer-operand (evaluate-expression operand context))))
        (setf result
              (checked-integer
               (if result
                   (funcall function result value)
                   value)))))))

(defmethod evaluate-expression ((expression roll) context)
  (values (roll-dice-spec (context-world context)
                          (roll-spec expression)
                          :label (roll-label expression))))

(defmethod evaluate-expression ((expression concat) context)
  (format nil "~{~A~}"
          (mapcar (lambda (part)
                    (format-dunge-value (evaluate-expression part context)))
                  (concat-parts expression))))

(defmethod evaluate-condition ((condition t) context)
  (not (null (evaluate-expression condition context))))

(defmethod evaluate-condition ((condition condition-eq) context)
  (equal (evaluate-expression (condition-left condition) context)
         (evaluate-expression (condition-right condition) context)))

(defmethod evaluate-condition ((condition condition-compare) context)
  (funcall (ecase (comparison-operator condition)
             (:lt #'<)
             (:lte #'<=)
             (:gt #'>)
             (:gte #'>=))
           (integer-operand (evaluate-expression (condition-left condition)
                                                 context))
           (integer-operand (evaluate-expression (condition-right condition)
                                                 context))))

(defmethod evaluate-condition ((condition condition-not) context)
  (not (evaluate-condition (condition-child condition) context)))

(defmethod evaluate-condition ((condition condition-and) context)
  (every (lambda (condition)
           (evaluate-condition condition context))
         (conditions condition)))

(defmethod evaluate-condition ((condition condition-or) context)
  (some (lambda (condition)
          (evaluate-condition condition context))
        (conditions condition)))

(defmethod execute-effect ((effect sequence) context)
  (dolist (child (sequence-effects effect))
    (let ((result (execute-effect child context)))
      (when (control-result-p result)
        (return result)))))

(defmethod execute-effect ((effect state-set) context)
  (set-state-reference-value (effect-target effect)
                             (evaluate-expression (effect-value effect) context)
                             context)
  nil)

(defmethod execute-effect ((effect state-clear) context)
  (clear-state-reference-value (effect-target effect) context)
  nil)

(defun numeric-state-value (reference context)
  (let ((value (or (state-reference-value reference context) 0)))
    (unless (integerp value)
      (error "Cannot increment or decrement non-numeric state value."))
    value))

(defun adjust-state-reference-value (effect function context)
  (set-state-reference-value
   (effect-target effect)
   (checked-integer
    (funcall function
             (numeric-state-value (effect-target effect) context)
             (integer-operand
              (evaluate-expression (effect-amount effect) context))))
   context))

(defmethod execute-effect ((effect state-inc) context)
  (adjust-state-reference-value effect #'+ context)
  nil)

(defmethod execute-effect ((effect state-dec) context)
  (adjust-state-reference-value effect #'- context)
  nil)

(defmethod execute-effect ((effect state-toggle) context)
  (toggle-state-reference-value (effect-target effect) context)
  nil)

(defmethod execute-effect ((effect say) context)
  (render-pending-choice-spacing)
  (format *output* "~A~%~%"
          (format-dunge-value (evaluate-expression (say-text effect) context)))
  (pause-after-say)
  nil)

(defmethod execute-effect ((effect conditional-effect) context)
  (execute-effect
   (or (if (evaluate-condition (conditional-effect-condition effect) context)
           (conditional-effect-then effect)
           (conditional-effect-else effect))
       (%make-sequence))
   context))

(defun evaluate-effects (effects context)
  (when effects
    (execute-effect effects context)))

(defmethod execute-effect ((effect goto) context)
  (%make-goto :room-name (evaluate-expression (room-name effect) context)))

(defmethod execute-effect ((effect gosub) context)
  (%make-gosub :room-name (evaluate-expression (room-name effect) context)))

(defmethod execute-effect ((effect enter) context)
  (declare (ignore context))
  effect)

(defmethod execute-effect ((effect back) context)
  (declare (ignore context))
  effect)

(defmethod execute-effect ((effect quit) context)
  (declare (ignore context))
  effect)

(defmethod execute-effect ((effect refresh) context)
  (declare (ignore context))
  effect)

(defmethod execute-effect ((effects cons) context)
  (declare (ignore effects context))
  (error "Effect lists are not executable; authored effects should use (:sequence :effects ...)."))

(defmethod execute-effect ((effect t) context)
  (declare (ignore context))
  (error "Cannot execute ~S as an effect." effect))

;;; Control nodes evaluate to the result object consumed by the game loop.
(defmethod evaluate ((node control-node) &optional context)
  (declare (ignore context))
  node)
