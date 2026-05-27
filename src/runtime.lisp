(in-package #:dunge)

;;; Evaluator and console runtime
;;; Control protocol: control AST nodes evaluate to themselves and are
;;; propagated upward unchanged. Rooms with no choices return FALL-THROUGH
;;; instead of returning the room. The game loop consumes these objects and
;;; dispatches on their type.

(defvar *input* *standard-input*)
(defvar *output* *standard-output*)
(defvar *pause-after-say* nil)
(defvar *debug* nil
  "When true, console play exposes debug controls such as Undo.")
(defvar *pending-choice-spacing* nil)

(defstruct runtime-context
  game
  scene
  self
  session)

(defstruct (runtime-session
             (:constructor %make-runtime-session (game location return-stack)))
  game
  location
  return-stack
  undo-stack)

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

(defun ensure-runtime-room-name (room-name label)
  (unless (stringp room-name)
    (error "Runtime ~A must be a room id string." label))
  room-name)

(defun runtime-proper-list-length (value label)
  (unless (listp value)
    (error "Runtime ~A must be a proper list." label))
  (let ((length (handler-case
                    (list-length value)
                  (type-error ()
                    nil))))
    (unless length
      (error "Runtime ~A must be a proper, non-circular list." label))
    length))

(defun ensure-runtime-list (value label)
  (runtime-proper-list-length value label)
  value)

(defun ensure-runtime-property-list (value label)
  (let ((length (runtime-proper-list-length value label)))
    (unless (evenp length)
      (error "Runtime ~A must contain an even number of property entries."
             label)))
  value)

(defun ensure-runtime-return-stack (return-stack)
  (ensure-runtime-list return-stack "return stack")
  (dolist (room-name return-stack)
    (ensure-runtime-room-name room-name "return stack entry"))
  return-stack)

(defun make-runtime-session (game &key current-room return-stack)
  (let ((start-room (or current-room (game-start game))))
    (unless start-room
      (error "Cannot start a runtime session for a game with no rooms."))
    (%make-runtime-session
     game
     (find-room game (ensure-runtime-room-name start-room "current room"))
     (mapcar (lambda (room-name)
               (find-room game room-name))
             (ensure-runtime-return-stack return-stack)))))

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
        (setf *pending-choice-spacing* t)
        (return index))
      (format *output* "Choose 1-~D.~%" count))))

(defun render-pending-choice-spacing ()
  (when *pending-choice-spacing*
    (terpri *output*)
    (setf *pending-choice-spacing* nil)))

(defun pause-after-say ()
  (when *pause-after-say*
    (format *output* "Press Enter to continue.")
    (finish-output *output*)
    (read-line *input* nil nil)
    (terpri *output*)))

(defun runtime-context-for-scene (context scene)
  (check-type context runtime-context)
  (make-runtime-context
   :game (runtime-context-game context)
   :scene scene
   :self nil
   :session (runtime-context-session context)))

(defun runtime-context-for-self (context self)
  (check-type context runtime-context)
  (make-runtime-context
   :game (runtime-context-game context)
   :scene (runtime-context-scene context)
   :self self
   :session (runtime-context-session context)))

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

(defun evaluate-session (session &key (debug *debug*))
  (check-type session runtime-session)
  (let ((*pending-choice-spacing* nil)
        (*debug* debug))
    (let* ((game (runtime-session-game session))
           (game-context (make-runtime-context :game game
                                               :session session)))
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
                    (return result))))))))

(defmethod evaluate ((game game) &optional context)
  (declare (ignore context))
  (terpri *output*)
  (evaluate-session (make-runtime-session game)))

(defun render-scene-title (title)
  (render-pending-choice-spacing)
  (format *output* "~&~A~%~A~%~%"
          title
          (make-string (length title) :initial-element #\=)))

(defmethod evaluate ((room room) &optional context)
  (let ((room-context (runtime-context-for-scene context room)))
    (render-scene-title (or (room-title room) (name room)))
    (let ((result (describe-children (entities room) room-context)))
      (when result
        (return-from evaluate result)))
    (let ((collected-options (collect-options-from (entities room) room-context)))
      (if (or collected-options
              (runtime-debug-undo-available-p room-context))
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
  (available-p choice context))

(defun mark-choice-taken (choice context)
  (when (choice-once-p choice)
    (unless (and context (runtime-context-game context))
      (error "Cannot mark once-only choice ~S without a current game."
             (label choice)))
    (setf (gethash (choice-state-key choice)
                   (game-taken-choices (runtime-context-game context)))
          t)))

(defmethod consumed-p ((choice choice) context)
  (choice-taken-p choice context))

(defmethod consume-node ((choice choice) context)
  (mark-choice-taken choice context))

(defconstant +dunge-rng-modulus+ 2147483648)
(defconstant +dunge-rng-multiplier+ 1103515245)
(defconstant +dunge-rng-increment+ 12345)

(defun find-table (game table-id)
  (multiple-value-bind (table present-p) (gethash (table-id-key table-id)
                                                  (table-index game))
    (if present-p
        table
        (error "No table named ~S." table-id))))

(defun runtime-context-for-table (game context)
  (or context
      (make-runtime-context :game game)))

(defun next-dunge-random-state (state)
  (mod (+ (* +dunge-rng-multiplier+ state)
          +dunge-rng-increment+)
       +dunge-rng-modulus+))

(defun game-random (game limit)
  (positive-integer-value limit "Random limit")
  (let ((next-state (next-dunge-random-state (game-random-state game))))
    (setf (game-random-state game) next-state)
    (mod next-state limit)))

(defun table-random (game limit random-state)
  (if random-state
      (random limit random-state)
      (game-random game limit)))

(defun record-table-roll (game entry)
  (push entry (game-roll-log-reversed game))
  entry)

(defun table-available-entries (table context)
  (let ((entries (remove-if-not (lambda (entry)
                                  (available-p entry context))
                                (table-entries table))))
    (unless entries
      (error "Table ~S has no available entries." (table-id table)))
    entries))

(defun choose-indexed-entry (entries index)
  (elt entries index))

(defun choose-random-entry (game entries random-state)
  (let ((index (table-random game (length entries) random-state)))
    (values (choose-indexed-entry entries index)
            (list :index index))))

(defun choose-weighted-entry (game entries random-state)
  (let ((total (reduce #'+ entries :key #'table-entry-weight)))
    (loop with roll = (table-random game total random-state)
          with remaining = roll
          for entry in entries
          for weight = (table-entry-weight entry)
          do (if (< remaining weight)
                 (return (values entry
                                 (list :roll roll
                                       :total total)))
                 (decf remaining weight)))))

(defun table-range-contains-p (range value)
  (and (<= (car range) value)
       (<= value (cdr range))))

(defun choose-roll-entry (game table entries random-state)
  (let* ((highest (reduce #'max entries
                          :key (lambda (entry)
                                 (table-range-high (table-entry-range entry)))))
         (roll (1+ (table-random game highest random-state))))
    (let ((entry (find-if (lambda (entry)
                            (table-range-contains-p (table-entry-range entry) roll))
                          entries)))
      (unless entry
        (error "Roll table ~S rolled ~D, but no entry covers that result."
               (table-id table)
               roll))
      (values entry
              (list :roll roll
                    :die highest)))))

(defun choose-sequence-entry (table entries)
  (let* ((last-index (1- (length entries)))
         (index (min (table-sequence-index table)
                     last-index))
         (entry (choose-indexed-entry entries index)))
    (setf (table-sequence-index table)
          (min (1+ index) last-index))
    (values entry
            (list :index index))))

(defun deck-entry-drawn-p (table entry)
  (gethash (table-entry-ordinal entry) (table-deck-drawn table)))

(defun choose-deck-entry (game table entries random-state)
  (let ((remaining (remove-if (lambda (entry)
                                (deck-entry-drawn-p table entry))
                              entries))
        (reshuffled nil))
    (unless remaining
      (clrhash (table-deck-drawn table))
      (setf remaining entries
            reshuffled t))
    (multiple-value-bind (entry details)
        (choose-random-entry game remaining random-state)
      (setf (gethash (table-entry-ordinal entry) (table-deck-drawn table))
            t)
      (values entry
              (append details
                      (list :remaining (length remaining)
                            :reshuffled reshuffled))))))

(defun choose-table-entry (game table context random-state)
  (let ((entries (table-available-entries table context)))
    (ecase (table-mode table)
      (:weighted
       (choose-weighted-entry game entries random-state))
      (:roll
       (choose-roll-entry game table entries random-state))
      (:deck
       (choose-deck-entry game table entries random-state))
      (:sequence
       (choose-sequence-entry table entries))
      (:first-match
       (values (first entries)
               (list :index 0))))))

(defun table-reference-result-id (result)
  (when (and (consp result)
             (eq (first result) :table)
             (consp (rest result))
             (null (cddr result)))
    (second result)))

(defun resolve-table-result (game result context random-state)
  (let ((nested-table-id (table-reference-result-id result)))
    (if nested-table-id
        (roll-table game nested-table-id
                    :context context
                    :random-state random-state)
        result)))

(defun table-roll-log-entry (table entry result details)
  (append (list :table (table-id table)
                :mode (table-mode table)
                :entry (and entry (table-entry-ordinal entry)))
          details
          (list :result result)))

(defun roll-table (game table-id &key context random-state)
  (let* ((table (find-table game table-id))
         (context (runtime-context-for-table game context)))
    (if (eq (table-mode table) :bundle)
        (let ((result (mapcar (lambda (entry)
                                (resolve-table-result game
                                                      (table-entry-result entry)
                                                      context
                                                      random-state))
                              (table-available-entries table context))))
          (record-table-roll
           game
           (table-roll-log-entry table nil result nil))
          (values result nil))
        (multiple-value-bind (entry details)
            (choose-table-entry game table context random-state)
          (let ((result (resolve-table-result game
                                              (table-entry-result entry)
                                              context
                                              random-state)))
            (record-table-roll
             game
             (table-roll-log-entry table entry result details))
            (values result entry))))))

(defun runtime-debug-undo-available-p (context)
  (and *debug*
       context
       (runtime-context-session context)
       (runtime-session-undo-stack (runtime-context-session context))))

(defun remember-runtime-undo-state (context)
  (when (and *debug*
             context
             (runtime-context-session context))
    (let ((session (runtime-context-session context)))
      (push (capture-runtime-undo-state session)
            (runtime-session-undo-stack session)))))

(defun undo-runtime-session (context)
  (let ((session (and context (runtime-context-session context))))
    (if (and session (runtime-session-undo-stack session))
        (progn
          (restore-runtime-undo-state
           session
           (pop (runtime-session-undo-stack session)))
          (%make-refresh))
        (progn
          (format *output* "Nothing to undo.~%")
          (%make-refresh)))))

(defmethod evaluate ((paragraph p) &optional context)
  (declare (ignore context))
  (render-pending-choice-spacing)
  (format *output* "~A~%~%" (text paragraph)))

(defmethod describe-entity ((paragraph p) &optional context)
  (evaluate paragraph context))

(defmethod evaluate ((choices choices) &optional context)
  (let ((options (remove-if-not (lambda (choice)
                                  (choice-visible-p choice context))
                                (options choices))))
    (loop for option in options
          for index from 1
          do (format *output* "~D. ~A~%" index (label option)))
    (let* ((story-option-count (length options))
           (undo-index (and (runtime-debug-undo-available-p context)
                            (1+ story-option-count)))
           (option-count (or undo-index story-option-count)))
      (when undo-index
        (format *output* "~D. Undo~%" undo-index))
      (let ((index (and (> option-count 0)
                        (read-choice-index option-count))))
        (cond
          ((null index)
           (%make-quit))
          ((and undo-index (= index undo-index))
           (undo-runtime-session context))
          (t
           (let ((option (elt options (1- index))))
             (remember-runtime-undo-state context)
             (consume-node option context)
             (evaluate (target option) context))))))))

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
    (render-scene-title (name container))
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

(defun collect-runtime-table-state (game)
  (mapcar (lambda (table)
            (list :table (table-id table)
                  :sequence-index (table-sequence-index table)
                  :deck-drawn (sorted-hash-keys (table-deck-drawn table))))
          (game-tables game)))

(defun collect-runtime-roll-log (game)
  (game-roll-log game))

(defun collect-runtime-player-state (game)
  (player-state-plist (game-player game)))

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
          :player (collect-runtime-player-state game)
          :rng-state (game-random-state game)
          :roll-log (collect-runtime-roll-log game)
          :globals (sorted-state-alist (game-global-state game))
          :locals (collect-runtime-local-state game)
          :tables (collect-runtime-table-state game)
          :taken-choices (sorted-hash-keys (game-taken-choices game)))))

(defun capture-runtime-undo-state (session)
  (let ((game (runtime-session-game session)))
    (list :location (runtime-session-location session)
          :return-stack (copy-list (runtime-session-return-stack session))
          :player (collect-runtime-player-state game)
          :rng-state (game-random-state game)
          :roll-log (collect-runtime-roll-log game)
          :globals (sorted-state-alist (game-global-state game))
          :locals (collect-runtime-local-state game)
          :tables (collect-runtime-table-state game)
          :taken-choices (sorted-hash-keys (game-taken-choices game)))))

(defun runtime-state-field (state field &optional default)
  (ensure-runtime-property-list state "state")
  (loop for (key value) on state by #'cddr
        when (eq key field)
          do (return value)
        finally (return default)))

(defun runtime-state-has-field-p (state field)
  (ensure-runtime-property-list state "state")
  (loop for tail on state by #'cddr
        for key = (car tail)
        when (eq key field)
          do (return t)
        finally (return nil)))

(defun runtime-state-required-field (state field)
  (let ((missing '#:missing))
    (let ((value (runtime-state-field state field missing)))
      (when (eq value missing)
        (error "Runtime state is missing required field ~S." field))
      value)))

(defun runtime-maybe-string-value (value label)
  (unless (or (null value) (stringp value))
    (error "Runtime ~A must be a string or NIL; got ~S." label value))
  value)

(defun runtime-maybe-keyword-value (value label)
  (unless (or (null value) (keywordp value))
    (error "Runtime ~A must be a keyword or NIL; got ~S." label value))
  value)

(defun runtime-keyword-list-value (value label)
  (ensure-runtime-list value label)
  (mapcar (lambda (entry)
            (unless (keywordp entry)
              (error "Runtime ~A entries must be keywords; got ~S."
                     label
                     entry))
            entry)
          value))

(defun runtime-player-number-field (state field label)
  (non-negative-integer-value
   (runtime-state-required-field state field)
   label))

(defun validate-runtime-player-current-maximum (current maximum label)
  (when (> current maximum)
    (error "Runtime player ~A current value ~D exceeds maximum ~D."
           label
           current
           maximum)))

(defun runtime-player-state-plist (state)
  (ensure-runtime-property-list state ":PLAYER")
  (let ((name (runtime-maybe-string-value
               (runtime-state-field state :name nil)
               "player name"))
        (background (runtime-maybe-keyword-value
                     (runtime-state-field state :background nil)
                     "player background"))
        (str (runtime-player-number-field state :str "Player STR"))
        (max-str (runtime-player-number-field state :max-str "Player max STR"))
        (dex (runtime-player-number-field state :dex "Player DEX"))
        (max-dex (runtime-player-number-field state :max-dex "Player max DEX"))
        (wil (runtime-player-number-field state :wil "Player WIL"))
        (max-wil (runtime-player-number-field state :max-wil "Player max WIL"))
        (hp (runtime-player-number-field state :hp "Player HP"))
        (max-hp (runtime-player-number-field state :max-hp "Player max HP"))
        (armor (runtime-player-number-field state :armor "Player armor"))
        (gold (runtime-player-number-field state :gold "Player gold"))
        (fate (runtime-player-number-field state :fate "Player fate"))
        (inventory (runtime-state-field state :inventory nil))
        (fatigue (runtime-player-number-field state :fatigue "Player fatigue"))
        (conditions (runtime-keyword-list-value
                     (runtime-state-field state :conditions nil)
                     "player conditions")))
    (ensure-runtime-list inventory "player inventory")
    (validate-runtime-player-current-maximum str max-str "STR")
    (validate-runtime-player-current-maximum dex max-dex "DEX")
    (validate-runtime-player-current-maximum wil max-wil "WIL")
    (validate-runtime-player-current-maximum hp max-hp "HP")
    (list :name name
          :background background
          :str str
          :max-str max-str
          :dex dex
          :max-dex max-dex
          :wil wil
          :max-wil max-wil
          :hp hp
          :max-hp max-hp
          :armor armor
          :gold gold
          :fate fate
          :inventory (copy-tree inventory)
          :fatigue fatigue
          :conditions conditions)))

(defun runtime-state-pair-p (entry)
  (consp entry))

(defun restore-runtime-global-state (game globals)
  (ensure-runtime-list globals ":GLOBALS")
  (dolist (entry globals)
    (unless (runtime-state-pair-p entry)
      (error "Runtime global state entry must be (KEY . VALUE)."))
    (setf (gethash (ensure-declared-global-state-key game (car entry))
                   (game-global-state game))
          (cdr entry))))

(defun restore-runtime-taken-choices (game taken-choices)
  (ensure-runtime-list taken-choices ":TAKEN-CHOICES")
  (clrhash (game-taken-choices game))
  (dolist (choice-id taken-choices)
    (setf (gethash (choice-id-key choice-id)
                   (game-taken-choices game))
          t)))

(defun restore-runtime-local-state-entry (game entry)
  (ensure-runtime-property-list entry "local state entry")
  (let* ((room-name (runtime-state-required-field entry :room))
         (entity-id (runtime-state-required-field entry :entity))
         (state (runtime-state-field entry :state nil))
         (room (find-room game room-name))
         (entity (gethash (scene-id-key entity-id) (scene-index room))))
    (unless (typep entity 'entity)
      (error "No saveable entity ~S in room ~S." entity-id room-name))
    (ensure-runtime-list state "local :STATE")
    (dolist (state-entry state)
      (unless (runtime-state-pair-p state-entry)
        (error "Runtime local state entry must be (KEY . VALUE)."))
      (setf (gethash (ensure-declared-state-key entity (car state-entry))
                     (local-state entity))
            (cdr state-entry)))))

(defun restore-runtime-local-state (game locals)
  (ensure-runtime-list locals ":LOCALS")
  (dolist (entry locals)
    (restore-runtime-local-state-entry game entry)))

(defun restore-runtime-table-state-entry (game entry)
  (ensure-runtime-property-list entry "table state entry")
  (let* ((table-id (runtime-state-required-field entry :table))
         (sequence-index (runtime-state-field entry :sequence-index 0))
         (deck-drawn (runtime-state-field entry :deck-drawn nil))
         (table (find-table game table-id)))
    (setf (table-sequence-index table)
          (non-negative-integer-value sequence-index "Table sequence index"))
    (ensure-runtime-list deck-drawn "table :DECK-DRAWN")
    (clrhash (table-deck-drawn table))
    (dolist (ordinal deck-drawn)
      (setf (gethash (non-negative-integer-value ordinal "Deck drawn ordinal")
                     (table-deck-drawn table))
            t))))

(defun restore-runtime-table-state (game tables)
  (ensure-runtime-list tables ":TABLES")
  (dolist (entry tables)
    (restore-runtime-table-state-entry game entry)))

(defun restore-runtime-random-state (game rng-state)
  (setf (game-random-state game)
        (non-negative-integer-value rng-state "Runtime RNG state")))

(defun restore-runtime-roll-log (game roll-log)
  (ensure-runtime-list roll-log ":ROLL-LOG")
  (setf (game-roll-log game) (copy-list roll-log)))

(defun restore-runtime-player-state (game player-state)
  (cond
    ((null player-state)
     (setf (game-player game) nil))
    (t
     (let ((player (or (game-player game)
                       (setf (game-player game)
                             (make-instance 'player)))))
       (apply-player-state player
                           (runtime-player-state-plist player-state))))))

(defun restore-runtime-state (game state)
  (let* ((missing '#:missing)
         (current-room (runtime-state-required-field state :current-room))
         (return-stack (runtime-state-field state :return-stack nil))
         (player-state (runtime-state-field state :player missing))
         (rng-state (runtime-state-field state :rng-state (game-random-seed game)))
         (roll-log (runtime-state-field state :roll-log nil))
         (globals (runtime-state-field state :globals nil))
         (locals (runtime-state-field state :locals nil))
         (tables (runtime-state-field state :tables nil))
         (taken-choices (runtime-state-field state :taken-choices nil)))
    (prepare-game game)
    (unless (eq player-state missing)
      (restore-runtime-player-state game player-state))
    (restore-runtime-random-state game rng-state)
    (restore-runtime-roll-log game roll-log)
    (restore-runtime-global-state game globals)
    (restore-runtime-local-state game locals)
    (restore-runtime-table-state game tables)
    (restore-runtime-taken-choices game taken-choices)
    (make-runtime-session game
                          :current-room current-room
                          :return-stack return-stack)))

(defun restore-runtime-undo-state (session state)
  (let ((game (runtime-session-game session)))
    (prepare-game game)
    (when (runtime-state-has-field-p state :player)
      (restore-runtime-player-state game (getf state :player nil)))
    (restore-runtime-random-state game
                                  (getf state :rng-state
                                        (game-random-seed game)))
    (restore-runtime-roll-log game (getf state :roll-log nil))
    (restore-runtime-global-state game (getf state :globals))
    (restore-runtime-local-state game (getf state :locals))
    (restore-runtime-table-state game (getf state :tables))
    (restore-runtime-taken-choices game (getf state :taken-choices))
    (setf (runtime-session-location session) (getf state :location))
    (setf (runtime-session-return-stack session)
          (copy-list (getf state :return-stack)))
    session))

(defun read-runtime-state-form (stream source-name)
  (let ((*read-eval* nil)
        (*readtable* (runtime-state-readtable))
        (eof '#:eof))
    (let ((form (read stream nil eof)))
      (when (eq form eof)
        (error "~A is empty." source-name))
      (let ((extra (read stream nil eof)))
        (unless (eq extra eof)
          (error "~A must contain exactly one top-level form." source-name)))
      form)))

(defun runtime-state-readtable ()
  (let ((readtable (copy-readtable nil)))
    (set-macro-character
     #\#
     (lambda (stream char)
       (declare (ignore stream char))
       (error "Runtime state reader does not allow # reader syntax."))
     nil
     readtable)
    readtable))

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
  (render-pending-choice-spacing)
  (format *output* "~A~%~%" (evaluate-expression (say-text effect) context))
  (pause-after-say)
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
