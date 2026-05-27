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
   (tables :reader game-tables :initarg :tables :initform nil)
   (global-state :reader game-global-state
                 :initform (make-hash-table :test 'eql))
   (global-state-declarations :reader game-global-state-declarations
                              :initarg :state
                              :initform nil)
   (flag-state-declarations :reader game-flag-state-declarations
                            :initarg :flags
                            :initform nil)
   (marked-state-declarations :reader game-marked-state-declarations
                              :initarg :marked
                              :initform nil)
   (taken-choices :reader game-taken-choices
                  :initform (make-hash-table :test 'eql))
   (player :accessor game-player :initarg :player :initform nil)
   (room-index :reader room-index :initform (make-hash-table :test 'equal))
   (table-index :reader table-index :initform (make-hash-table :test 'eql))
   (start :accessor game-start :initarg :start :initform nil))
  (:children (thing) (append (game-rooms thing)
                             (game-tables thing)))
  (:source :game
   (:fields
    (:start :scene-id)
    (:state :state-declarations :default nil)
    (:flags :state-key-list :default nil)
    (:marked :state-key-list :default nil)
    (:tables :table-list :default nil)
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
  (:source :%goto
   (:fields
    (:room :scene-id :required t :to :room-name))))

(define-dunge-node gosub (control-node)
  ((room-name :reader room-name :initarg :room-name :initform nil))
  (:source :%gosub
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

(define-dunge-field-type :state-key-list (value context)
  (declare (ignore context))
  (unless (listp value)
    (source-error "State key lists must be lists; got ~S." value))
  (mapcar #'state-key value))

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

(defgeneric availability-condition (thing))
(defgeneric available-p (thing context))
(defgeneric consumed-p (thing context))
(defgeneric consume-node (thing context))
(defgeneric consumable-id (thing))
(defgeneric consumable-once-p (thing))
(defgeneric node-tags (thing))
(defgeneric node-priority (thing))

(defclass availability-mixin ()
  ((condition :reader availability-condition
              :initarg :condition
              :initform nil)))

(defclass consumable-mixin ()
  ((id :reader consumable-id :initarg :id :initform nil)
   (once :reader consumable-once-p :initarg :once :initform nil)))

(defclass tagged-mixin ()
  ((tags :reader node-tags :initarg :tags :initform nil)))

(defclass prioritized-mixin ()
  ((priority :reader node-priority :initarg :priority :initform 0)))

(defmethod availability-condition ((thing t))
  nil)

(defmethod consumed-p ((thing t) context)
  (declare (ignore thing context))
  nil)

(defmethod consume-node ((thing t) context)
  (declare (ignore thing context))
  nil)

(defmethod consumable-id ((thing t))
  nil)

(defmethod consumable-once-p ((thing t))
  nil)

(defmethod node-tags ((thing t))
  (declare (ignore thing))
  nil)

(defmethod node-priority ((thing t))
  (declare (ignore thing))
  0)

(defmethod available-p ((thing t) context)
  (not (consumed-p thing context)))

(defmethod available-p ((thing availability-mixin) context)
  (and (call-next-method)
       (or (null (availability-condition thing))
           (evaluate-condition (availability-condition thing) context))))

(defgeneric choice-condition (choice))
(defgeneric choice-id (choice))
(defgeneric choice-once-p (choice))

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

(define-dunge-node choice (availability-mixin consumable-mixin)
  ((label :accessor label :initarg :label :initform nil)
   (target :accessor target :initarg :target :initform nil))
  (:source :%choice
   (:fields
    (:label :string :required t)
    (:do :effect-or-block :required t :to :target)
    (:id :choice-id)
    (:when :condition :to :condition)
    (:once :boolean))))

(defmethod choice-condition ((choice choice))
  (availability-condition choice))

(defmethod choice-id ((choice choice))
  (consumable-id choice))

(defmethod choice-once-p ((choice choice))
  (consumable-once-p choice))

(define-dunge-node choices ()
  ((options :accessor options :initarg :options :initform nil)))

(defun table-id-key (id)
  (unless (keywordp id)
    (error "Table ids must be keywords; got ~S." id))
  id)

(defun table-mode-key (mode)
  (unless (member mode '(:weighted :roll :deck :sequence :first-match :bundle)
                  :test #'eq)
    (error "Table mode must be one of :WEIGHTED, :ROLL, :DECK, :SEQUENCE, :FIRST-MATCH, or :BUNDLE; got ~S."
           mode))
  mode)

(defun positive-integer-value (value label)
  (unless (and (integerp value) (plusp value))
    (error "~A must be a positive integer; got ~S." label value))
  value)

(defun non-negative-integer-value (value label)
  (unless (and (integerp value) (not (minusp value)))
    (error "~A must be a non-negative integer; got ~S." label value))
  value)

(defun tag-list-value (value)
  (unless (listp value)
    (source-error "Tag lists must be lists; got ~S." value))
  (mapcar (lambda (tag)
            (unless (keywordp tag)
              (source-error "Tags must be keywords; got ~S." tag))
            tag)
          value))

(define-dunge-field-type :table-id (value context)
  (declare (ignore context))
  (table-id-key value))

(define-dunge-field-type :table-mode (value context)
  (declare (ignore context))
  (table-mode-key value))

(define-dunge-field-type :positive-integer (value context)
  (declare (ignore context))
  (positive-integer-value value "Value"))

(define-dunge-field-type :non-negative-integer (value context)
  (declare (ignore context))
  (non-negative-integer-value value "Value"))

(define-dunge-field-type :tag-list (value context)
  (declare (ignore context))
  (tag-list-value value))

(defun table-range-value (value)
  (cond
    ((integerp value)
     (let ((point (positive-integer-value value "Table range")))
       (cons point point)))
    ((and (source-pair-p value)
          (integerp (first value))
          (integerp (second value)))
     (let ((low (positive-integer-value (first value) "Table range low"))
           (high (positive-integer-value (second value) "Table range high")))
       (when (> low high)
         (source-error "Table range low ~D is greater than high ~D."
                       low
                       high))
       (cons low high)))
    (t
     (source-error "Table ranges must be an integer or (LOW HIGH); got ~S."
                   value))))

(define-dunge-field-type :table-range (value context)
  (declare (ignore context))
  (table-range-value value))

(define-dunge-node table-entry (availability-mixin tagged-mixin)
  ((id :reader table-entry-id :initarg :id :initform nil)
   (weight :reader table-entry-weight :initarg :weight :initform 1)
   (range :reader table-entry-range :initarg :range :initform nil)
   (result :reader table-entry-result :initarg :result :initform nil)
   (ordinal :accessor table-entry-ordinal :initform nil))
  (:source :table-entry
   (:fields
    (:id :state-key)
    (:weight :positive-integer :default 1)
    (:range :table-range)
    (:when :condition :to :condition)
    (:tags :tag-list :default nil)
    (:result :literal :required t))))

(define-dunge-node random-table ()
  ((id :reader table-id :initarg :id :initform nil)
   (mode :reader table-mode :initarg :mode :initform :weighted)
   (entries :reader table-entries :initarg :entries :initform nil)
   (sequence-index :accessor table-sequence-index :initform 0)
   (deck-drawn :reader table-deck-drawn
               :initform (make-hash-table :test 'eql)))
  (:children (thing) (table-entries thing))
  (:source :table
   (:fields
    (:id :table-id :required t)
    (:mode :table-mode :default :weighted)
    (:entries :table-entry-list :required t))))

(defmethod initialize-instance :after ((table random-table) &key)
  (loop for entry in (table-entries table)
        for ordinal from 0
        do (setf (table-entry-ordinal entry) ordinal)))

(defun reset-table-state (table)
  (setf (table-sequence-index table) 0)
  (clrhash (table-deck-drawn table))
  table)

(define-dunge-field-type :table-entry-list (value context)
  (mapcar (lambda (form)
            (let ((node (compile-dunge-source-form form context)))
              (unless (typep node 'table-entry)
                (source-error "Expected a table entry source form, got ~S."
                              form))
              node))
          (ensure-source-list :table-entry-list value)))

(define-dunge-field-type :table-list (value context)
  (mapcar (lambda (form)
            (let ((node (compile-dunge-source-form form context)))
              (unless (typep node 'random-table)
                (source-error "Expected a table source form, got ~S."
                              form))
              node))
          (ensure-source-list :table-list value)))

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
  (setf (slot-value game 'global-state-declarations)
        (append (game-global-state-declarations game)
                (mapcar (lambda (key)
                          (list key nil))
                        (game-flag-state-declarations game))
                (mapcar (lambda (key)
                          (list key t))
                        (game-marked-state-declarations game))))
  (clrhash (room-index game))
  (dolist (room (game-rooms game))
    (when (nth-value 1 (gethash (name room) (room-index game)))
      (error "Duplicate room named ~S." (name room)))
    (setf (gethash (name room) (room-index game)) room))
  (clrhash (table-index game))
  (dolist (table (game-tables game))
    (when (nth-value 1 (gethash (table-id table) (table-index game)))
      (error "Duplicate table id ~S." (table-id table)))
    (setf (gethash (table-id table) (table-index game)) table))
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
  (dolist (table (game-tables game))
    (reset-table-state table))
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
  (validate-consumable-node thing)
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
