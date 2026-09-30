(in-package #:dunge)

;;; Internal CLOS AST model
;;;
;;; The node classes and their source schema. A game built from them is an
;;; immutable definition; play state lives in a WORLD (see world.lisp).

(defgeneric node-id (thing)
  (:documentation "Return the scene-local id for THING, or NIL."))

(defgeneric node-children (thing)
  (:documentation "Return child AST nodes that participate in scene indexing."))

(defmethod node-id ((thing t))
  nil)

(defmethod node-children ((thing t))
  nil)

(defconstant +dunge-rng-modulus+ 2147483648
  "The game generator's modulus, 2^31. Every generator state is below it.")
(defconstant +dunge-rng-multiplier+ 1103515245)
(defconstant +dunge-rng-increment+ 12345)

(defconstant +max-safe-integer+ (1- (expt 2 53))
  "The largest integer both runtimes represent exactly. Arithmetic results
beyond plus or minus this value are errors.")

(defun safe-integer-p (value)
  (and (integerp value)
       (<= (- +max-safe-integer+) value +max-safe-integer+)))

(define-dunge-node game ()
  ((rooms :reader game-rooms :initarg :rooms :initform nil)
   (tables :reader game-tables :initarg :tables :initform nil)
   (random-seed :reader game-random-seed :initarg :seed :initform 1)
   (global-state-declarations :reader game-global-state-declarations
                              :initarg :state
                              :initform nil)
   (flag-state-declarations :reader game-flag-state-declarations
                            :initarg :flags
                            :initform nil)
   (marked-state-declarations :reader game-marked-state-declarations
                              :initarg :marked
                              :initform nil)
   (player-state-declarations :reader game-player-state-declarations
                              :initarg :player
                              :initform nil)
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
    (:seed :non-negative-integer :default 1)
    (:player :state-declarations :default nil)
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
  (:source :go
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
    ((:self :global :player :ref) scope)
    (otherwise
     (error "State scope must be one of :SELF, :GLOBAL, :PLAYER, or :REF; got ~S."
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

;;; Expressions and conditions
;;;
;;; An expression is a literal (string, integer, keyword, T or NIL) or an
;;; EXPRESSION-NODE. A condition is a CONDITION-NODE. A state reference is
;;; both: as a condition it tests its value for truth.

(defclass expression-node () ())

(defclass condition-node () ())

(define-dunge-field-type :expression-list (value context)
  (mapcar (lambda (form)
            (compile-dunge-expression form context))
          (ensure-source-list :expression-list value)))

(define-dunge-node state-ref (expression-node condition-node)
  ((scope :reader state-ref-scope :initarg :scope :initform :global)
   (role :reader state-ref-role :initarg :role :initform nil)
   (key :reader state-ref-key :initarg :key :initform nil))
  (:source :state
   (:fields
    (:scope :state-scope :required t)
    (:role :keyword)
    (:key :state-key :required t))))

(define-dunge-node arithmetic (expression-node)
  ((operator :reader arithmetic-operator :initarg :operator :initform nil)
   (operands :reader arithmetic-operands :initarg :operands :initform nil)))

(define-dunge-field-type :dice (value context)
  (declare (ignore context))
  (parse-dice-expression value))

(define-dunge-node roll (expression-node)
  ((spec :reader roll-spec :initarg :spec :initform nil)
   (label :reader roll-label :initarg :label :initform nil))
  (:source :roll
   (:fields
    (:dice :dice :required t :to :spec)
    (:label :keyword))))

(define-dunge-node concat (expression-node)
  ((parts :reader concat-parts :initarg :parts :initform nil))
  (:source :concat
   (:fields
    (:parts :expression-list :required t))))

(defclass binary-condition (condition-node)
  ((left :reader condition-left :initarg :left :initform nil)
   (right :reader condition-right :initarg :right :initform nil)))

(define-dunge-node condition-eq (binary-condition)
  ()
  (:source :eq
   (:fields
    (:left :expression :required t)
    (:right :expression :required t))))

(define-dunge-node condition-compare (binary-condition)
  ((operator :reader comparison-operator :initarg :operator :initform nil)))

(defparameter *arithmetic-operators* '(:add :sub :mul :min :max))
(defparameter *comparison-operators* '(:lt :lte :gt :gte))

(dolist (operator *arithmetic-operators*)
  (let ((operator operator))
    (register-dunge-source-form
     operator
     (lambda (&rest initargs)
       (apply #'%make-arithmetic :operator operator initargs))
     '((:operands :expression-list :required t)))))

(dolist (operator *comparison-operators*)
  (let ((operator operator))
    (register-dunge-source-form
     operator
     (lambda (&rest initargs)
       (apply #'%make-condition-compare :operator operator initargs))
     '((:left :expression :required t)
       (:right :expression :required t)))))

(define-dunge-node condition-not (condition-node)
  ((condition :reader condition-child :initarg :condition :initform nil))
  (:source :not
   (:fields
    (:condition :condition :required t))))

(define-dunge-node condition-and (condition-node)
  ((conditions :reader conditions :initarg :conditions :initform nil))
  (:source :and
   (:fields
    (:conditions :condition-list :required t))))

(define-dunge-node condition-or (condition-node)
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
  (:source :choice
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

(defun proper-list-length-value (value label)
  (unless (listp value)
    (error "~A must be a proper list; got ~S." label value))
  (let ((length (handler-case
                    (list-length value)
                  (type-error ()
                    nil))))
    (unless length
      (error "~A must be a proper, non-circular list." label))
    length))

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

(define-dunge-field-type :literal-list (value context)
  (declare (ignore context))
  (ensure-source-list :literal-list value))

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
   (entries :reader table-entries :initarg :entries :initform nil))
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
   (scene :accessor entity-scene :initform nil)
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
    (:text :expression :required t))))

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

(defun declared-player-state-keys (game)
  (state-declaration-key-list (game-player-state-declarations game)))

(defun ensure-declared-player-state-key (game key)
  (let ((state-key (state-key key)))
    (unless (member state-key (declared-player-state-keys game) :test #'eql)
      (error "Game has no declared player state key ~S. Declared keys: ~S."
             state-key
             (declared-player-state-keys game)))
    state-key))

(defun index-scene-node (scene thing)
  (walk-node-tree
   thing
   (lambda (node)
     (when (typep node 'entity)
       (setf (entity-scene node) scene))
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

(defun link-room-scene (room)
  "Index ROOM's scene ids, resolve its entities' refs, and give each action
its owner. Linking only reads the room's definition, so it is idempotent."
  (clrhash (scene-index room))
  (dolist (entity (entities room))
    (index-scene-node room entity))
  (dolist (entity (entities room))
    (resolve-node-refs room entity))
  (dolist (entity (entities room))
    (assign-action-owners entity nil)))

(defmethod initialize-instance :after ((room room) &key)
  (link-room-scene room))
