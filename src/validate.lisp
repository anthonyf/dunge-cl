(in-package #:dunge)

;;; Validation
;;;
;;; A separate pass over a game's definition that reports authoring errors
;;; before play. It only reads the game.

(defvar *validation-errors* nil)
(defvar *validation-choice-ids* nil)
(defvar *validation-resolve-room-targets* nil)

(defvar *validate-room-targets* t
  "Whether VALIDATE-GAME checks that :GO and :GOSUB targets exist. A build
turns this off for the scratch game it rolls on, whose source can name rooms
the build has yet to plan.")

(defgeneric validate-node (thing game context)
  (:documentation "Validate a Dunge AST node in GAME and CONTEXT."))

(defun validation-error (format-control &rest format-arguments)
  (push (apply #'format nil format-control format-arguments)
        *validation-errors*))

(defun static-room-name-p (thing)
  (stringp thing))

(defun validate-room-target (node game room-name)
  (when (and *validation-resolve-room-targets*
             (static-room-name-p room-name))
    (unless (nth-value 1 (gethash room-name (room-index game)))
      (validation-error "~A targets missing room ~S."
                        (class-name (class-of node))
                        room-name))))

(defun validate-game-start (game)
  (let ((start (game-start game)))
    (cond
      ((null start)
       (validation-error "Game must declare or infer a start room."))
      ((not (static-room-name-p start))
       (validation-error "Game start room must be a string; got ~S." start))
      ((not (nth-value 1 (gethash start (room-index game))))
       (validation-error "Game start room ~S does not exist." start)))))

(defun validate-choice-id (choice)
  (let ((id (consumable-id choice)))
    (cond
      ((and (consumable-once-p choice)
            (null id))
       (validation-error "Once-only choice ~S must declare :ID."
                         (label choice)))
      ((and id (not (keywordp id)))
       (validation-error "Choice id must be a keyword; got ~S." id))
      (id
       (let ((key (choice-id-key id)))
         (multiple-value-bind (existing present-p) (gethash key *validation-choice-ids*)
           (if present-p
               (validation-error "Duplicate choice id ~S on choices ~S and ~S."
                                 id
                                 (label existing)
                                 (label choice))
               (setf (gethash key *validation-choice-ids*) choice))))))))

(defun validate-availability-node (thing game context)
  (let ((condition (availability-condition thing)))
    (when condition
      (validate-condition condition game context))))

(defun validate-consumable-node (thing)
  (let ((id (consumable-id thing)))
    (cond
      ((and (consumable-once-p thing)
            (null id))
       (validation-error "Once-only node ~S must declare :ID." thing))
      ((and id (not (keywordp id)))
       (validation-error "Consumable node id must be a keyword; got ~S."
                         id)))))

(defun validate-state-declaration-list (owner-label declarations)
  (let ((seen (make-hash-table :test 'eql)))
    (dolist (declaration declarations)
      (destructuring-bind (key value) declaration
        (let ((state-key (state-key key)))
          (when (and (integerp value) (not (safe-integer-p value)))
            (validation-error "~A state key ~S starts at ~D, outside the supported range of plus or minus ~D."
                              owner-label
                              state-key
                              value
                              +max-safe-integer+))
          (if (nth-value 1 (gethash state-key seen))
              (validation-error "~A declares state key ~S more than once."
                                owner-label
                                state-key)
              (setf (gethash state-key seen) t)))))))

(defun expression-literal-p (thing)
  (or (stringp thing)
      (keywordp thing)
      (integerp thing)
      (eq thing t)
      (null thing)))

(defun validate-expression (thing game context)
  (cond
    ((typep thing 'expression-node)
     (validate-node thing game context))
    ((and (integerp thing) (not (safe-integer-p thing)))
     (validation-error "Integer ~D is outside the supported range of plus or minus ~D."
                       thing
                       +max-safe-integer+))
    ((expression-literal-p thing)
     nil)
    (t
     (validation-error "Expressions must be a literal or an expression node; got ~S."
                       thing))))

(defun validate-integer-expression (thing game context)
  "Validate THING as an expression that must produce an integer."
  (if (or (typep thing 'concat)
          (and (expression-literal-p thing)
               (not (integerp thing))))
      (validation-error "Expected an integer expression; got ~S." thing)
      (validate-expression thing game context)))

(defvar *validating-condition* nil
  "True while validating a condition or paragraph text. Both may be evaluated
any number of times, such as on every render, so they must not roll dice.")

(defun validate-condition (condition game context)
  (if (typep condition 'condition-node)
      (let ((*validating-condition* t))
        (validate-node condition game context))
      (validation-error "Condition must be a condition node; got ~S."
                        condition)))

(defun validate-current-maximum-pairs (owner-label declarations)
  "Where DECLARATIONS declare both KEY and MAX-KEY, such as :HP and :MAX-HP,
require non-negative integers with KEY at most MAX-KEY."
  (dolist (declaration declarations)
    (destructuring-bind (key value) declaration
      (let* ((max-key (intern (format nil "MAX-~A" (symbol-name key)) :keyword))
             (max-declaration (assoc max-key declarations)))
        (when max-declaration
          (let ((maximum (second max-declaration)))
            (cond
              ((not (and (integerp value) (not (minusp value))
                         (integerp maximum) (not (minusp maximum))))
               (validation-error "~A ~S and ~S must be non-negative integers; got ~S and ~S."
                                 owner-label key max-key value maximum))
              ((> value maximum)
               (validation-error "~A ~S starts at ~D, above its maximum ~D."
                                 owner-label key value maximum)))))))))

(defun signal-validation-errors (label)
  (when *validation-errors*
    (error "~A validation failed:~%~{  - ~A~%~}"
           label
           (nreverse *validation-errors*))))

(defun validate-room (room)
  (let ((*validation-errors* nil)
        (*validation-choice-ids* (make-hash-table :test 'eql))
        (*validation-resolve-room-targets* nil))
    (validate-node room nil room)
    (signal-validation-errors "Room"))
  room)

(defun validate-game (game)
  (let ((*validation-errors* nil)
        (*validation-choice-ids* (make-hash-table :test 'eql))
        (*validation-resolve-room-targets* *validate-room-targets*))
    (validate-game-start game)
    (validate-state-declaration-list "Game"
                                     (game-global-state-declarations game))
    (validate-state-declaration-list "Player"
                                     (game-player-state-declarations game))
    (validate-current-maximum-pairs "Player"
                                    (game-player-state-declarations game))
    (dolist (table (game-tables game))
      (validate-node table game game))
    (dolist (room (game-rooms game))
      (validate-node room game room))
    (signal-validation-errors "Game"))
  game)

(defmethod validate-node ((thing t) game context)
  (declare (ignore thing game context))
  nil)

(defun validate-node-list (nodes game context)
  (dolist (node nodes)
    (validate-node node game context)))

(defmethod validate-node ((thing room) game context)
  (declare (ignore context))
  (validate-node-list (entities thing) game thing))

(defmethod validate-node ((thing entity) game context)
  (declare (ignore context))
  (when (and (state-declarations thing)
             (null (entity-id thing)))
    (validation-error
     "Entity ~S declares :STATE but has no :ID; stateful entities need an :ID so their state can be saved."
     (name thing)))
  (validate-state-declaration-list
   (format nil "Entity ~S" (or (entity-id thing) (name thing)))
   (state-declarations thing))
  (validate-node-list (entities thing) game thing))

(defmethod validate-node ((thing branch) game context)
  (validate-condition (branch-condition thing) game context)
  (validate-node-list (branch-then-entities thing) game context)
  (validate-node-list (branch-else-entities thing) game context))

(defmethod validate-node ((thing choices) game context)
  (validate-node-list (options thing) game context))

(defmethod validate-node ((thing choice) game context)
  (validate-availability-node thing game context)
  (validate-choice-id thing)
  (validate-node (target thing) game context))

(defun table-result-reference-id (result)
  (when (and (consp result)
             (eq (first result) :table)
             (consp (rest result))
             (null (cddr result)))
    (second result)))

(defun table-range-high (range)
  (cdr range))

(defun table-ranges-overlap-p (left right)
  (and (<= (car left) (cdr right))
       (<= (car right) (cdr left))))

(defun validate-table-entry-list (table)
  (when (null (table-entries table))
    (validation-error "Table ~S must contain at least one entry."
                      (table-id table)))
  (when (eq (table-mode table) :roll)
    (let ((seen-ranges nil))
      (dolist (entry (table-entries table))
        (let ((range (table-entry-range entry)))
          (unless range
            (validation-error "Roll table ~S entry ~S is missing :RANGE."
                              (table-id table)
                              (table-entry-result entry)))
          (when range
            (dolist (seen seen-ranges)
              (when (table-ranges-overlap-p range seen)
                (validation-error "Roll table ~S has overlapping ranges ~S and ~S."
                                  (table-id table)
                                  range
                                  seen)))
            (push range seen-ranges)))))))

(defmethod validate-node ((thing random-table) game context)
  (declare (ignore context))
  (validate-table-entry-list thing)
  (dolist (entry (table-entries thing))
    (validate-node entry game thing)))

(defmethod validate-node ((thing table-entry) game context)
  (declare (ignore context))
  (validate-availability-node thing game nil)
  (let ((table-id (table-result-reference-id (table-entry-result thing))))
    (when table-id
      (unless (keywordp table-id)
        (validation-error "Table reference result must use a keyword id; got ~S."
                          table-id))
      (when (and game
                 (keywordp table-id)
                 (not (nth-value 1 (gethash table-id (table-index game)))))
        (validation-error "Table entry references missing table ~S."
                          table-id)))))

(defun validate-effect-tree (effects game context)
  (cond
    ((null effects)
     nil)
    ((listp effects)
     (validation-error
      "Effect lists are not valid; wrap authored effects in (:sequence :effects ...)."))
    ((typep effects 'effect-node)
     (validate-node effects game context))
    (t
     (validation-error "Expected an effect node, got ~S." effects))))

(defun validate-effect-list (effects game context)
  (dolist (effect effects)
    (validate-effect-tree effect game context)))

(defmethod validate-node ((thing action) game context)
  (unless (typep context 'entity)
    (validation-error "Action ~S must be inside an entity." (label thing)))
  (validate-effect-tree (effects thing) game context))

(defmethod validate-node ((thing container) game context)
  (validate-node-list (contents thing) game context))

(defmethod validate-node ((thing placement) game context)
  (when (interaction-target thing)
    (validate-node (interaction-target thing) game context)))

(defmethod validate-node ((thing condition-eq) game context)
  (validate-expression (condition-left thing) game context)
  (validate-expression (condition-right thing) game context))

(defmethod validate-node ((thing condition-compare) game context)
  (validate-integer-expression (condition-left thing) game context)
  (validate-integer-expression (condition-right thing) game context))

(defmethod validate-node ((thing condition-not) game context)
  (validate-condition (condition-child thing) game context))

(defmethod validate-node ((thing condition-and) game context)
  (dolist (child (conditions thing))
    (validate-condition child game context)))

(defmethod validate-node ((thing condition-or) game context)
  (dolist (child (conditions thing))
    (validate-condition child game context)))

(defmethod validate-node ((thing arithmetic) game context)
  (let ((operands (arithmetic-operands thing)))
    (when (< (length operands)
             (if (eq (arithmetic-operator thing) :sub) 2 1))
      (validation-error "~S needs ~:[at least one operand~;at least two operands~]; got ~S."
                        (arithmetic-operator thing)
                        (eq (arithmetic-operator thing) :sub)
                        operands))
    (dolist (operand operands)
      (validate-integer-expression operand game context))))

(defmethod validate-node ((thing roll) game context)
  (declare (ignore game context))
  (let* ((spec (roll-spec thing))
         (dice (getf spec :expression)))
    (when *validating-condition*
      (validation-error "Dice roll ~S cannot appear in a condition or paragraph; ~
                         set state from the roll in an effect and use that ~
                         instead."
                        dice))
    (destructuring-bind (&key count sides modifier &allow-other-keys) spec
      (cond
        ((> sides +dunge-rng-modulus+)
         ;; Each die draws a generator state modulo its sides, and every state
         ;; is below 2^31, so larger faces could never come up.
         (validation-error "Dice roll ~S has more than ~D sides."
                           dice
                           +dunge-rng-modulus+))
        ;; With at least one die and a safe modifier, the smallest total,
        ;; COUNT + MODIFIER, is safe too; only the largest can overflow.
        ((notevery #'safe-integer-p
                   (list count modifier (+ (* count sides) modifier)))
         (validation-error "Dice roll ~S can produce a total outside the ~
                            supported integer range."
                           dice))))
    (when (and (roll-label thing)
               (not (keywordp (roll-label thing))))
      (validation-error "Dice roll label must be a keyword; got ~S."
                        (roll-label thing)))))

(defmethod validate-node ((thing concat) game context)
  (dolist (part (concat-parts thing))
    (validate-expression part game context)))

(defmethod validate-node ((thing state-ref) game context)
  (declare (ignore context))
  (case (state-ref-scope thing)
    (:ref
     (unless (state-ref-role thing)
       (validation-error "REF state reference with key ~S is missing a role."
                         (state-ref-key thing)))
     (when (and (state-ref-role thing)
                (not (keywordp (state-ref-role thing))))
       (validation-error "REF state reference role must be a keyword; got ~S."
                         (state-ref-role thing)))
     (unless (state-ref-key thing)
       (validation-error "REF state reference with role ~S is missing a key."
                         (state-ref-role thing))))
    ((:self :global)
     (unless (state-ref-key thing)
       (validation-error "~S state reference is missing a key."
                         (state-ref-scope thing)))
     (when (and (eq (state-ref-scope thing) :global)
                game
                (state-ref-key thing)
                (global-state-declared-p game)
                (not (member (state-key (state-ref-key thing))
                             (declared-global-state-keys game)
                             :test #'eql)))
       (validation-error "GLOBAL state reference uses undeclared key ~S. Declared keys: ~S."
                         (state-ref-key thing)
                         (declared-global-state-keys game))))
    (:player
     (unless (state-ref-key thing)
       (validation-error "PLAYER state reference is missing a key."))
     (when (and game
                (state-ref-key thing)
                (not (member (state-key (state-ref-key thing))
                             (declared-player-state-keys game)
                             :test #'eql)))
       (validation-error "PLAYER state reference uses undeclared key ~S. Declared keys: ~S."
                         (state-ref-key thing)
                         (declared-player-state-keys game))))
    (otherwise
     (validation-error "Unknown state scope ~S."
                       (state-ref-scope thing))))
  (when (and (state-ref-key thing)
             (not (keywordp (state-ref-key thing))))
    (validation-error "State reference key must be a keyword; got ~S."
                      (state-ref-key thing))))

(defmethod validate-node ((thing sequence) game context)
  (validate-effect-list (sequence-effects thing) game context))

(defmethod validate-node ((thing state-effect) game context)
  (validate-node (effect-target thing) game context))

(defmethod validate-node ((thing state-set) game context)
  (call-next-method)
  (validate-expression (effect-value thing) game context))

(defmethod validate-node ((thing state-inc) game context)
  (call-next-method)
  (validate-integer-expression (effect-amount thing) game context))

(defmethod validate-node ((thing state-dec) game context)
  (call-next-method)
  (validate-integer-expression (effect-amount thing) game context))

(defmethod validate-node ((thing say) game context)
  (validate-expression (say-text thing) game context))

(defmethod validate-node ((thing p) game context)
  ;; Paragraphs render on every visit, like conditions, so no dice.
  (let ((*validating-condition* t))
    (validate-expression (text thing) game context)))

(defmethod validate-node ((thing conditional-effect) game context)
  (validate-condition (conditional-effect-condition thing) game context)
  (validate-effect-tree (conditional-effect-then thing) game context)
  (validate-effect-tree (conditional-effect-else thing) game context))

(defmethod validate-node ((thing goto) game context)
  (declare (ignore context))
  (validate-room-target thing game (room-name thing)))

(defmethod validate-node ((thing gosub) game context)
  (declare (ignore context))
  (validate-room-target thing game (room-name thing)))
