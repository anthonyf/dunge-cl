(in-package #:dunge)

;;; Internal CLOS AST model

(defgeneric node-id (thing)
  (:documentation "Return the scene-local id for THING, or NIL."))

(defgeneric node-children (thing)
  (:documentation "Return child AST nodes that participate in scene indexing."))

(defmethod node-id ((thing t))
  nil)

(defmethod node-children ((thing t))
  nil)

(define-dunge-node game ()
  ((rooms :reader game-rooms :initarg :rooms :initform nil)
   (global-state :reader game-global-state
                 :initform (make-hash-table :test 'eql))
   (global-state-declarations :reader game-global-state-declarations
                              :initarg :state
                              :initform nil)
   (taken-choices :reader game-taken-choices
                  :initform (make-hash-table :test 'eql))
   (player :accessor game-player :initarg :player :initform nil)
   (room-index :reader room-index :initform (make-hash-table :test 'equal))
   (start :accessor game-start :initarg :start :initform nil))
  (:children (thing) (game-rooms thing))
  (:source :game
   (:fields
    (:start :scene-id)
    (:state :state-declarations :default nil)
    (:rooms :room-list :required t))))

(define-dunge-node room ()
  ((name :reader name :initarg :name :initform nil)
   (title :reader room-title :initarg :title :initform nil)
   (scene-index :reader scene-index
                :initform (make-hash-table :test 'equal))
   (entities :accessor entities :initform nil :initarg :entities))
  (:children (thing) (entities thing))
  (:source :room
   (:fields
    (:id :scene-id :required t :to :name)
    (:title :string)
    (:body :node-list :default nil :to :entities))))

(define-dunge-node effect-node ()
  ())

(define-dunge-node control-node (effect-node)
  ())

(define-dunge-node fall-through (control-node)
  ())

(define-dunge-node goto (control-node)
  ((room-name :reader room-name :initarg :room-name :initform nil))
  (:source :goto
   (:fields
    (:room :scene-id :required t :to :room-name))))

(define-dunge-node gosub (control-node)
  ((room-name :reader room-name :initarg :room-name :initform nil))
  (:source :gosub
   (:fields
    (:room :scene-id :required t :to :room-name))))

(define-dunge-node enter (control-node)
  ((target :reader enter-target :initarg :target :initform nil)))

(define-dunge-node back (control-node)
  ()
  (:source :back
   (:fields)))

(defun state-scope-key (scope)
  (case scope
    ((:self :global :ref) scope)
    (otherwise
     (error "State scope must be one of :SELF, :GLOBAL, or :REF; got ~S."
            scope))))

(defun state-key (key)
  (unless (keywordp key)
    (error "State keys must be keywords; got ~S." key))
  key)

(defun ref-role-key (role)
  (unless (keywordp role)
    (error "Reference roles must be keywords; got ~S." role))
  role)

(defun scene-id-key (id)
  (unless (stringp id)
    (error "Scene ids must be strings; got ~S." id))
  id)

(defun choice-id-key (id)
  (unless (keywordp id)
    (error "Choice ids must be keywords; got ~S." id))
  id)

(define-dunge-field-type :scene-id (value context)
  (declare (ignore context))
  (scene-id-key value))

(define-dunge-field-type :choice-id (value context)
  (declare (ignore context))
  (choice-id-key value))

(define-dunge-field-type :state-key (value context)
  (declare (ignore context))
  (state-key value))

(define-dunge-field-type :state-scope (value context)
  (declare (ignore context))
  (state-scope-key value))

(defun source-pair-p (value)
  (and (consp value)
       (consp (cdr value))
       (null (cddr value))))

(define-dunge-field-type :state-declarations (value context)
  (declare (ignore context))
  (unless (listp value)
    (source-error "State declarations must be a list; got ~S." value))
  (mapcar (lambda (declaration)
            (unless (source-pair-p declaration)
              (source-error "State declaration must be (KEY INITIAL-VALUE); got ~S."
                            declaration))
            (list (state-key (first declaration))
                  (second declaration)))
          value))

(defun state-declaration-key-list (declarations)
  (mapcar (lambda (declaration)
            (state-key (first declaration)))
          declarations))

(defun declared-global-state-keys (game)
  (state-declaration-key-list (game-global-state-declarations game)))

(defun global-state-declared-p (game)
  (not (null (game-global-state-declarations game))))

(defun ensure-declared-global-state-key (game key)
  (let ((state-key (state-key key)))
    (when (global-state-declared-p game)
      (unless (member state-key (declared-global-state-keys game) :test #'eql)
        (error "Game has no declared global state key ~S. Declared keys: ~S."
               state-key
               (declared-global-state-keys game))))
    state-key))

(define-dunge-field-type :refs (value context)
  (declare (ignore context))
  (unless (listp value)
    (source-error "Entity refs must be a list; got ~S." value))
  (mapcar (lambda (ref)
            (unless (source-pair-p ref)
              (source-error "Entity ref must be (ROLE TARGET-ID); got ~S."
                            ref))
            (list (ref-role-key (first ref))
                  (scene-id-key (second ref))))
          value))

(define-dunge-node state-ref ()
  ((scope :reader state-ref-scope :initarg :scope :initform :global)
   (role :reader state-ref-role :initarg :role :initform nil)
   (key :reader state-ref-key :initarg :key :initform nil))
  (:source :state
   (:fields
    (:scope :state-scope :required t)
    (:role :keyword)
    (:key :state-key :required t))))

(define-dunge-node condition-eq ()
  ((left :reader condition-left :initarg :left :initform nil)
   (right :reader condition-right :initarg :right :initform nil))
  (:source :eq
   (:fields
    (:left :expression :required t)
    (:right :expression :required t))))

(define-dunge-node condition-not ()
  ((condition :reader condition-child :initarg :condition :initform nil))
  (:source :not
   (:fields
    (:condition :condition :required t))))

(define-dunge-node condition-and ()
  ((conditions :reader conditions :initarg :conditions :initform nil))
  (:source :and
   (:fields
    (:conditions :condition-list :required t))))

(define-dunge-node condition-or ()
  ((conditions :reader conditions :initarg :conditions :initform nil))
  (:source :or
   (:fields
    (:conditions :condition-list :required t))))

(define-dunge-node sequence (effect-node)
  ((effects :reader sequence-effects :initarg :effects :initform nil))
  (:source :sequence
   (:fields
    (:effects :effect-list :default nil))))

(define-dunge-node state-effect (effect-node)
  ((target :reader effect-target :initarg :target :initform nil)))

(define-dunge-node state-set (state-effect)
  ((value :reader effect-value :initarg :value :initform nil))
  (:source :set
   (:fields
    (:target :state-reference :required t)
    (:value :expression :required t))))

(define-dunge-node state-clear (state-effect)
  ()
  (:source :clear
   (:fields
    (:target :state-reference :required t))))

(define-dunge-node state-inc (state-effect)
  ((amount :reader effect-amount :initarg :amount :initform 1))
  (:source :inc
   (:fields
    (:target :state-reference :required t)
    (:amount :expression :default 1))))

(define-dunge-node state-dec (state-effect)
  ((amount :reader effect-amount :initarg :amount :initform 1))
  (:source :dec
   (:fields
    (:target :state-reference :required t)
    (:amount :expression :default 1))))

(define-dunge-node state-toggle (state-effect)
  ()
  (:source :toggle
   (:fields
    (:target :state-reference :required t))))

(define-dunge-node say (effect-node)
  ((text :reader say-text :initarg :text :initform nil))
  (:source :say
   (:fields
    (:text :expression :required t))))

(define-dunge-node conditional-effect (effect-node)
  ((condition :reader conditional-effect-condition
              :initarg :condition
              :initform nil)
   (then-effects :reader conditional-effect-then
                 :initarg :then
                 :initform nil)
   (else-effects :reader conditional-effect-else
                 :initarg :else
                 :initform nil))
  (:source :if
   (:fields
    (:when :condition :required t :to :condition)
    (:then :effect-block :default nil)
    (:else :effect-block :default nil))))

(define-dunge-node choice ()
  ((label :accessor label :initarg :label :initform nil)
   (target :accessor target :initarg :target :initform nil)
   (id :reader choice-id :initarg :id :initform nil)
   (condition :reader choice-condition :initarg :condition :initform nil)
   (once :reader choice-once-p :initarg :once :initform nil))
  (:source :option
   (:fields
    (:label :string :required t)
    (:do :effect :required t :to :target)
    (:id :choice-id)
    (:when :condition :to :condition)
    (:once :boolean))))

(define-dunge-node choices ()
  ((options :accessor options :initarg :options :initform nil))
  (:source :choice
   (:fields
    (:options :choice-list :required t))))

(define-dunge-node entity ()
  ((name :reader name :initarg :name :initform nil)
   (id :reader entity-id :initarg :id :initform nil)
   (state-declarations :reader state-declarations
                       :initarg :state
                       :initform nil)
   (local-state :reader local-state
                :initform (make-hash-table :test 'eql))
   (refs :reader entity-refs :initarg :refs :initform nil)
   (resolved-refs :reader resolved-refs
                  :initform (make-hash-table :test 'eql))
   (entities :accessor entities :initarg :entities :initform nil))
  (:id (thing) (entity-id thing))
  (:children (thing) (entities thing))
  (:source :entity
   (:fields
    (:name :string :required t)
    (:id :scene-id)
    (:state :state-declarations :default nil)
    (:refs :refs :default nil)
    (:body :node-list :default nil :to :entities))))

(define-dunge-node branch ()
  ((condition :reader branch-condition :initarg :condition :initform nil)
   (then-entities :reader branch-then-entities :initarg :then :initform nil)
   (else-entities :reader branch-else-entities :initarg :else :initform nil))
  (:children (thing)
    (append (branch-then-entities thing)
            (branch-else-entities thing)))
  (:source :branch
   (:fields
    (:when :condition :required t :to :condition)
    (:then :node-list :default nil)
    (:else :node-list :default nil))))

(define-dunge-node action ()
  ((label :accessor label :initarg :label :initform nil)
   (effects :reader effects :initarg :effects :initform nil)
   (owner :accessor action-owner :initarg :owner :initform nil))
  (:source :action
   (:fields
    (:label :string :required t)
    (:do :effect-block :default nil :to :effects))))

(define-dunge-node refresh (control-node)
  ())

(define-dunge-node placement ()
  ((thing :reader placed-thing :initarg :thing :initform nil)
   (description :reader placement-description :initarg :description :initform nil)
   (interaction-label :reader interaction-label
                      :initarg :interaction-label
                      :initform nil)
   (interaction-target :reader interaction-target
                       :initarg :interaction-target
                       :initform nil))
  (:source :placed
   (:fields
    (:thing :node :required t)
    (:description :string)
    (:label :string :to :interaction-label)
    (:do :effect :to :interaction-target))))

(define-dunge-node item ()
  ((name :reader name :initarg :name :initform nil)
   (description :reader description :initarg :description :initform nil))
  (:source :item
   (:fields
    (:name :string :required t)
    (:description :string))))

(define-dunge-node container ()
  ((name :reader name :initarg :name :initform nil)
   (description :reader description :initarg :description :initform nil)
   (open-choice :reader open-choice :initarg :open-choice :initform nil)
   (close-choice :reader close-choice :initarg :close-choice :initform nil)
   (contents :accessor contents :initarg :contents :initform nil))
  (:children (thing) (contents thing))
  (:source :container
   (:fields
    (:name :string :required t)
    (:description :string)
    (:open :string :to :open-choice)
    (:close :string :to :close-choice)
    (:contents :node-list :default nil))))

(define-dunge-node container-view ()
  ((container :reader viewed-container :initarg :container :initform nil)))

(define-dunge-node p ()
  ((text :reader text :initarg :text :initform nil))
  (:source :p
   (:fields
    (:text :string :required t))))

(define-dunge-node quit (control-node)
  ()
  (:source :quit
   (:fields)))

(defmethod initialize-instance :after ((game game) &key)
  (clrhash (room-index game))
  (dolist (room (game-rooms game))
    (when (nth-value 1 (gethash (name room) (room-index game)))
      (error "Duplicate room named ~S." (name room)))
    (setf (gethash (name room) (room-index game)) room))
  (unless (game-start game)
    (setf (game-start game) (and (game-rooms game)
                                 (name (first (game-rooms game)))))))

(defun walk-node-tree (thing function)
  (funcall function thing)
  (dolist (child (node-children thing))
    (walk-node-tree child function)))

(defun reset-local-state (thing)
  (walk-node-tree
   thing
   (lambda (node)
     (when (typep node 'entity)
       (clrhash (local-state node))
       (dolist (declaration (state-declarations node))
         (destructuring-bind (name value) declaration
           (setf (gethash (state-key name) (local-state node))
                 value)))))))

(defun reset-global-state (game)
  (clrhash (game-global-state game))
  (dolist (declaration (game-global-state-declarations game))
    (destructuring-bind (name value) declaration
      (setf (gethash (state-key name) (game-global-state game))
            value))))

(defun index-scene-node (scene thing)
  (walk-node-tree
   thing
   (lambda (node)
     (let ((id (node-id node)))
       (when id
         (let ((key (scene-id-key id)))
           (when (nth-value 1 (gethash key (scene-index scene)))
             (error "Duplicate scene id ~S in room ~S." id (name scene)))
           (setf (gethash key (scene-index scene)) node)))))))

(defun resolve-node-refs (scene thing)
  (walk-node-tree
   thing
   (lambda (node)
     (when (typep node 'entity)
       (clrhash (resolved-refs node))
       (dolist (ref (entity-refs node))
         (destructuring-bind (role target-id) ref
           (let* ((role-key (ref-role-key role))
                  (target-key (scene-id-key target-id))
                  (target (gethash target-key (scene-index scene))))
             (unless target
               (error "Entity ~S in room ~S has ref ~S to missing id ~S."
                      (or (entity-id node) (name node))
                      (name scene)
                      role
                      target-id))
             (setf (gethash role-key (resolved-refs node)) target))))))))

(defun assign-action-owners (thing owner)
  (cond
    ((typep thing 'entity)
     (dolist (child (entities thing))
       (assign-action-owners child thing)))
    ((typep thing 'action)
     (setf (action-owner thing) owner))
    (t
     (dolist (child (node-children thing))
       (assign-action-owners child owner)))))

(defun prepare-room-scene (room)
  (clrhash (scene-index room))
  (reset-local-state room)
  (dolist (entity (entities room))
    (index-scene-node room entity))
  (dolist (entity (entities room))
    (resolve-node-refs room entity))
  (dolist (entity (entities room))
    (assign-action-owners entity nil)))

(defun prepare-game (game)
  (reset-global-state game)
  (clrhash (game-taken-choices game))
  (dolist (room (game-rooms game))
    (prepare-room-scene room))
  game)

(defvar *validation-errors* nil)
(defvar *validation-choice-ids* nil)
(defvar *validation-resolve-room-targets* nil)

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
  (let ((id (choice-id choice)))
    (cond
      ((and (choice-once-p choice)
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

(defun validate-state-declaration-list (owner-label declarations)
  (let ((seen (make-hash-table :test 'eql)))
    (dolist (declaration declarations)
      (destructuring-bind (key value) declaration
        (declare (ignore value))
        (let ((state-key (state-key key)))
          (if (nth-value 1 (gethash state-key seen))
              (validation-error "~A declares state key ~S more than once."
                                owner-label
                                state-key)
              (setf (gethash state-key seen) t)))))))

(defun condition-literal-p (thing)
  (or (stringp thing)
      (keywordp thing)
      (numberp thing)
      (eq thing t)
      (null thing)))

(defun validate-condition-operand (thing game context)
  (cond
    ((typep thing 'state-ref)
     (validate-node thing game context))
    ((condition-literal-p thing)
     nil)
    (t
     (validation-error "Condition operands must be a state-ref or literal; got ~S."
                       thing))))

(defun validate-condition (condition game context)
  (cond
    ((typep condition 'condition-eq)
     (validate-condition-operand (condition-left condition) game context)
     (validate-condition-operand (condition-right condition) game context))
    ((typep condition 'condition-not)
     (validate-condition (condition-child condition) game context))
    ((typep condition 'condition-and)
     (dolist (child (conditions condition))
       (validate-condition child game context)))
    ((typep condition 'condition-or)
     (dolist (child (conditions condition))
       (validate-condition child game context)))
    ((typep condition 'state-ref)
     (validate-node condition game context))
    (t
     (validation-error "Condition must be a condition-* or state-ref node; got ~S."
                       condition))))

(defun signal-validation-errors (label)
  (when *validation-errors*
    (error "~A validation failed:~%~{  - ~A~%~}"
           label
           (nreverse *validation-errors*))))

(defun validate-room (room)
  (prepare-room-scene room)
  (let ((*validation-errors* nil)
        (*validation-choice-ids* (make-hash-table :test 'eql))
        (*validation-resolve-room-targets* nil))
    (validate-node room nil room)
    (signal-validation-errors "Room"))
  room)

(defun validate-game (game)
  (prepare-game game)
  (let ((*validation-errors* nil)
        (*validation-choice-ids* (make-hash-table :test 'eql))
        (*validation-resolve-room-targets* t))
    (validate-game-start game)
    (validate-state-declaration-list "Game"
                                     (game-global-state-declarations game))
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
  (validate-choice-id thing)
  (when (choice-condition thing)
    (validate-condition (choice-condition thing) game context))
  (validate-node (target thing) game context))

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
  (validate-condition thing game context))

(defmethod validate-node ((thing condition-not) game context)
  (validate-condition thing game context))

(defmethod validate-node ((thing condition-and) game context)
  (validate-condition thing game context))

(defmethod validate-node ((thing condition-or) game context)
  (validate-condition thing game context))

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
  (validate-node (effect-value thing) game context))

(defmethod validate-node ((thing state-inc) game context)
  (call-next-method)
  (validate-node (effect-amount thing) game context))

(defmethod validate-node ((thing state-dec) game context)
  (call-next-method)
  (validate-node (effect-amount thing) game context))

(defmethod validate-node ((thing say) game context)
  (validate-node (say-text thing) game context))

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
