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

(defstruct (runtime-session
             (:constructor %make-runtime-session (game location return-stack)))
  game
  location
  return-stack)

(defgeneric evaluate (thing &optional context)
  (:documentation "Evaluate a Dunge CLOS AST node in CONTEXT.

When THING is a game, returns one of: a QUIT instance when the player chose to
quit or input closed; a BACK instance when the player backed past the top of the
return stack; or a ROOM or CONTAINER-VIEW instance when play fell through with no
choices and an empty return stack. Control node identity is preserved, so callers
can TYPEP the result against QUIT, BACK, and related classes."))

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

(defun make-runtime-session (game &key current-room return-stack)
  (let ((start-room (or current-room (game-start game))))
    (unless start-room
      (error "Cannot start a runtime session for a game with no rooms."))
    (%make-runtime-session
     game
     (find-room game start-room)
     (mapcar (lambda (room-name)
               (find-room game room-name))
             return-stack))))

(defun ensure-saveable-room-location (location purpose)
  (unless (typep location 'room)
    (error "Cannot save ~A while it is a transient ~A."
           purpose
           (class-name (class-of location))))
  location)

(defun runtime-session-current-room-name (session)
  (name (ensure-saveable-room-location
         (runtime-session-location session)
         "the current location")))

(defun runtime-session-return-stack-room-names (session)
  (mapcar (lambda (location)
            (name (ensure-saveable-room-location location "the return stack")))
          (runtime-session-return-stack session)))

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
  (check-type context runtime-context)
  (make-runtime-context
   :game (runtime-context-game context)
   :scene scene
   :self nil))

(defun runtime-context-for-self (context self)
  (check-type context runtime-context)
  (make-runtime-context
   :game (runtime-context-game context)
   :scene (runtime-context-scene context)
   :self self))

(defun runtime-context-for-location (context location)
  (if (typep location 'room)
      (runtime-context-for-scene context location)
      context))

(defun describe-children (children context)
  (dolist (child children)
    (let ((result (if (control-result-p child)
                      child
                      (describe-entity child context))))
      (when (control-result-p result)
        (return result)))))

(defun evaluate-session (session)
  (check-type session runtime-session)
  (let* ((game (runtime-session-game session))
         (game-context (make-runtime-context :game game)))
    (loop do (let* ((location (runtime-session-location session))
                    (location-context
                      (runtime-context-for-location game-context location))
                    (result (evaluate location location-context)))
               (match result
                 ((quit)
                  (return result))
                 ((refresh)
                  nil)
                 ((goto (room-name room-name))
                  (setf (runtime-session-location session)
                        (find-room game room-name)))
                 ((gosub (room-name room-name))
                  (push location (runtime-session-return-stack session))
                  (setf (runtime-session-location session)
                        (find-room game room-name)))
                 ((enter (target target))
                  (push location (runtime-session-return-stack session))
                  (setf (runtime-session-location session) target))
                 ((back)
                  (if (runtime-session-return-stack session)
                      (setf (runtime-session-location session)
                            (pop (runtime-session-return-stack session)))
                      (return result)))
                 ((fall-through)
                  (if (runtime-session-return-stack session)
                      (setf (runtime-session-location session)
                            (pop (runtime-session-return-stack session)))
                      (return location)))
                 (_
                  (return result)))))))

(defmethod evaluate ((game game) &optional context)
  (declare (ignore context))
  (evaluate-session (make-runtime-session game)))

(defmethod evaluate ((room room) &optional context)
  (let ((room-context (runtime-context-for-scene context room)))
    (format *output* "~&~A~%" (or (room-title room) (name room)))
    (let ((result (describe-children (entities room) room-context)))
      (when result
        (return-from evaluate result)))
    (let ((collected-options (collect-options-from (entities room) room-context)))
      (if collected-options
          (evaluate (%make-choices :options collected-options) room-context)
          (%make-fall-through)))))

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
          (%make-quit)))))

;;; Effects can be reached as a choice target through EVALUATE, or inside a
;;; sequence through EXECUTE-EFFECT directly. This bridge keeps both paths
;;; equivalent while preserving CLOS dispatch over choice target unions.
(defmethod evaluate ((effect effect-node) &optional context)
  (or (execute-effect effect context)
      (%make-refresh)))

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
  (list (%make-choice :label (label action)
                      :target action)))

(defmethod evaluate ((action action) &optional context)
  (unless (action-owner action)
    (error "Action ~S is not inside an entity." (label action)))
  (let* ((action-context (runtime-context-for-self context
                                                   (action-owner action)))
         (result (evaluate-effects (effects action) action-context)))
    (or result (%make-refresh))))

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
    (list (%make-choice :label (open-choice container)
                        :target (%make-enter
                                 :target (%make-container-view
                                          :container container))))))

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
                  (list (%make-choice :label (or (close-choice container) "Back")
                                      :target (%make-back)))))
    (evaluate (%make-choices :options collected-options) context)))

(defmethod describe-entity ((placement placement) &optional context)
  (declare (ignore context))
  (when (placement-description placement)
    (format *output* "~A~%" (placement-description placement))))

(defmethod collect-choices ((placement placement) &optional context)
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

(defun resolve-state-reference (reference context)
  (ecase (state-ref-scope reference)
    (:self
     (unless (and context (runtime-context-self context))
       (error "Cannot resolve SELF state without a current entity."))
     (let* ((self (runtime-context-self context))
            (key (ensure-declared-state-key self (state-ref-key reference))))
       (values (local-state self)
               key
               self)))
    (:global
     (unless (and context (runtime-context-game context))
       (error "Cannot resolve GLOBAL state without a current game."))
     (let ((game (runtime-context-game context)))
       (values (game-global-state game)
               (ensure-declared-global-state-key
                game
                (state-ref-key reference)))))
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
         (values (local-state target)
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

(defun sorted-state-alist (table)
  (sort (loop for key being the hash-keys of table
                using (hash-value value)
              collect (cons key value))
        #'string<
        :key (lambda (entry)
               (prin1-to-string (car entry)))))

(defun sorted-hash-keys (table)
  (sort (loop for key being the hash-keys of table
              collect key)
        #'string<
        :key #'prin1-to-string))

(defun collect-runtime-local-state (game)
  (let (entries)
    (dolist (room (game-rooms game))
      (walk-node-tree
       room
       (lambda (node)
         (when (and (typep node 'entity)
                    (entity-id node)
                    (state-declarations node))
           (push (list :room (name room)
                       :entity (entity-id node)
                       :state (sorted-state-alist (local-state node)))
                 entries)))))
    (nreverse entries)))

(defun capture-runtime-state (session)
  (let ((game (runtime-session-game session)))
    (list :current-room (runtime-session-current-room-name session)
          :return-stack (runtime-session-return-stack-room-names session)
          :globals (sorted-state-alist (game-global-state game))
          :locals (collect-runtime-local-state game)
          :taken-choices (sorted-hash-keys (game-taken-choices game)))))

(defun runtime-state-field (state field &optional default)
  (unless (and (listp state) (evenp (length state)))
    (error "Runtime state must be a property list; got ~S." state))
  (loop for (key value) on state by #'cddr
        when (eq key field)
          do (return value)
        finally (return default)))

(defun runtime-state-required-field (state field)
  (let ((missing '#:missing))
    (let ((value (runtime-state-field state field missing)))
      (when (eq value missing)
        (error "Runtime state is missing required field ~S." field))
      value)))

(defun runtime-state-pair-p (entry)
  (consp entry))

(defun restore-runtime-global-state (game globals)
  (unless (listp globals)
    (error "Runtime :GLOBALS must be an alist; got ~S." globals))
  (dolist (entry globals)
    (unless (runtime-state-pair-p entry)
      (error "Runtime global state entry must be (KEY . VALUE); got ~S."
             entry))
    (setf (gethash (ensure-declared-global-state-key game (car entry))
                   (game-global-state game))
          (cdr entry))))

(defun restore-runtime-taken-choices (game taken-choices)
  (unless (listp taken-choices)
    (error "Runtime :TAKEN-CHOICES must be a list; got ~S." taken-choices))
  (clrhash (game-taken-choices game))
  (dolist (choice-id taken-choices)
    (setf (gethash (choice-id-key choice-id)
                   (game-taken-choices game))
          t)))

(defun restore-runtime-local-state-entry (game entry)
  (unless (and (listp entry) (evenp (length entry)))
    (error "Runtime local state entry must be a property list; got ~S." entry))
  (let* ((room-name (runtime-state-required-field entry :room))
         (entity-id (runtime-state-required-field entry :entity))
         (state (runtime-state-field entry :state nil))
         (room (find-room game room-name))
         (entity (gethash (scene-id-key entity-id) (scene-index room))))
    (unless (typep entity 'entity)
      (error "No saveable entity ~S in room ~S." entity-id room-name))
    (unless (listp state)
      (error "Runtime local :STATE must be an alist; got ~S." state))
    (dolist (state-entry state)
      (unless (runtime-state-pair-p state-entry)
        (error "Runtime local state entry must be (KEY . VALUE); got ~S."
               state-entry))
      (setf (gethash (ensure-declared-state-key entity (car state-entry))
                     (local-state entity))
            (cdr state-entry)))))

(defun restore-runtime-local-state (game locals)
  (unless (listp locals)
    (error "Runtime :LOCALS must be a list; got ~S." locals))
  (dolist (entry locals)
    (restore-runtime-local-state-entry game entry)))

(defun restore-runtime-state (game state)
  (let ((current-room (runtime-state-required-field state :current-room))
        (return-stack (runtime-state-field state :return-stack nil))
        (globals (runtime-state-field state :globals nil))
        (locals (runtime-state-field state :locals nil))
        (taken-choices (runtime-state-field state :taken-choices nil)))
    (prepare-game game)
    (restore-runtime-global-state game globals)
    (restore-runtime-local-state game locals)
    (restore-runtime-taken-choices game taken-choices)
    (make-runtime-session game
                          :current-room current-room
                          :return-stack return-stack)))

(defun read-runtime-state-form (stream source-name)
  (let ((*read-eval* nil)
        (*readtable* (copy-readtable nil))
        (eof '#:eof))
    (let ((form (read stream nil eof)))
      (when (eq form eof)
        (error "~A is empty." source-name))
      (let ((extra (read stream nil eof)))
        (unless (eq extra eof)
          (error "~A must contain exactly one top-level form." source-name)))
      form)))

(defun read-runtime-state-file (path)
  (with-open-file (stream path :direction :input)
    (read-runtime-state-form stream (namestring (truename path)))))

(defun write-runtime-state-file (session path)
  (with-open-file (stream path
                          :direction :output
                          :if-exists :supersede
                          :if-does-not-exist :create)
    (let ((*print-readably* t)
          (*print-pretty* t))
      (prin1 (capture-runtime-state session) stream)
      (terpri stream)))
  path)

(defun load-runtime-state-file (game path)
  (restore-runtime-state game (read-runtime-state-file path)))

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
  (toggle-state-reference-value (effect-target effect) context)
  nil)

(defmethod execute-effect ((effect say) &optional context)
  (format *output* "~A~%" (evaluate-expression (say-text effect) context))
  nil)

(defmethod execute-effect ((effect conditional-effect) &optional context)
  (execute-effect
   (or (if (evaluate-condition (conditional-effect-condition effect) context)
           (conditional-effect-then effect)
           (conditional-effect-else effect))
       (%make-sequence))
   context))

(defun evaluate-effects (effects context)
  (when effects
    (execute-effect effects context)))

(defmethod execute-effect ((effect goto) &optional context)
  (%make-goto :room-name (evaluate-expression (room-name effect) context)))

(defmethod execute-effect ((effect gosub) &optional context)
  (%make-gosub :room-name (evaluate-expression (room-name effect) context)))

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
  (error "Effect lists are not executable; authored effects should use (:sequence :effects ...)."))

(defmethod execute-effect ((effect t) &optional context)
  (declare (ignore context))
  (error "Cannot execute ~S as an effect." effect))

;;; Control nodes evaluate to the result object consumed by the game loop.
(defmethod evaluate ((node control-node) &optional context)
  (declare (ignore context))
  node)
