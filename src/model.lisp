(in-package #:dunge)

;;; Game model and DSL constructors

(defgeneric node-id (thing)
  (:documentation "Return the scene-local id for THING, or NIL."))

(defgeneric node-children (thing)
  (:documentation "Return child AST nodes that participate in scene indexing."))

(defmacro define-ast-node (name superclasses slots &body options)
  "Define an AST node class and its local constructor/traversal boilerplate."
  (labels ((method-option-form (option generic-function)
             (destructuring-bind (keyword lambda-list &body body) option
               (declare (ignore keyword))
               (unless (and (listp lambda-list)
                            (= 1 (length lambda-list))
                            (symbolp (first lambda-list)))
                 (error "DEFINE-AST-NODE method option for ~S must use a single-argument lambda list; got ~S."
                        name
                        lambda-list))
               `(defmethod ,generic-function ((,(first lambda-list) ,name))
                  ,@body))))
    (let (constructor id children class-options)
      (dolist (option options)
        (unless (consp option)
          (error "Malformed DEFINE-AST-NODE option ~S." option))
        (case (first option)
          (:constructor
           (when constructor
             (error "Duplicate DEFINE-AST-NODE :CONSTRUCTOR option for ~S." name))
           (setf constructor option))
          (:id
           (when id
             (error "Duplicate DEFINE-AST-NODE :ID option for ~S." name))
           (setf id option))
          (:children
           (when children
             (error "Duplicate DEFINE-AST-NODE :CHILDREN option for ~S." name))
           (setf children option))
          (:class-option
           (setf class-options (append class-options (rest option))))
          (otherwise
           (error "Unknown DEFINE-AST-NODE option ~S for ~S."
                  (first option)
                  name))))
      `(progn
         (defclass ,name ,superclasses
           ,slots
           ,@class-options)
         ,@(when constructor
             (destructuring-bind (keyword function lambda-list &rest initargs)
                 constructor
               (declare (ignore keyword))
               `((defun ,function ,lambda-list
                   (make-instance ',name ,@initargs)))))
         ,@(when id
             `(,(method-option-form id 'node-id)))
         ,@(when children
             `(,(method-option-form children 'node-children)))))))

(defmethod node-id ((thing t))
  nil)

(defmethod node-children ((thing t))
  nil)

(define-ast-node game ()
  ((rooms :reader game-rooms :initarg :rooms :initform nil)
   (global-state :reader game-global-state
                 :initform (make-hash-table :test 'eql))
   (taken-choices :reader game-taken-choices
                  :initform (make-hash-table :test 'eql))
   (player :accessor game-player :initarg :player :initform nil)
   (room-index :reader room-index :initform (make-hash-table :test 'equal))
   (start :accessor game-start :initarg :start :initform nil))
  (:children (thing) (game-rooms thing)))

(defmethod initialize-instance :after ((game game) &key)
  (clrhash (room-index game))
  (dolist (room (game-rooms game))
    (when (nth-value 1 (gethash (name room) (room-index game)))
      (error "Duplicate room named ~S." (name room)))
    (setf (gethash (name room) (room-index game)) room))
  (unless (game-start game)
    (setf (game-start game) (and (game-rooms game)
                                 (name (first (game-rooms game)))))))

(defun game (&rest rooms)
  (let ((game (make-instance 'game :rooms rooms)))
    (prepare-game game)
    (validate-game game)
    game))

(define-ast-node room ()
  ((name :reader name :initarg :name :initform nil)
   (scene-index :reader scene-index
                :initform (make-hash-table :test 'equal))
   (entities :accessor entities :initform nil :initarg :entities))
  (:constructor room (name &rest entities) :name name :entities entities)
  (:children (thing) (entities thing)))

(define-ast-node effect-node ()
  ())

(define-ast-node control-node (effect-node)
  ())

(define-ast-node fall-through (control-node)
  ()
  (:constructor fall-through ()))

(define-ast-node goto (control-node)
  ((room-name :reader room-name :initarg :room-name :initform nil))
  (:constructor goto (room-name) :room-name room-name))

(define-ast-node gosub (control-node)
  ((room-name :reader room-name :initarg :room-name :initform nil))
  (:constructor gosub (room-name) :room-name room-name))

(define-ast-node enter (control-node)
  ((target :reader enter-target :initarg :target :initform nil))
  (:constructor enter (target) :target target))

(define-ast-node back (control-node)
  ()
  (:constructor back ()))

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

(define-ast-node state-ref ()
  ((scope :reader state-ref-scope :initarg :scope :initform :global)
   (role :reader state-ref-role :initarg :role :initform nil)
   (key :reader state-ref-key :initarg :key :initform nil)))

(defun state-ref (scope key &optional (ref-state-key nil ref-state-key-p))
  (let ((scope-key (state-scope-key scope)))
    (cond
      ((eq scope-key :ref)
       (unless ref-state-key-p
         (error "REF state references must include a role and key."))
       (make-instance 'state-ref
                      :scope scope-key
                      :role (ref-role-key key)
                      :key (state-key ref-state-key)))
      (ref-state-key-p
       (error "~S state references take only one key." scope-key))
      (t
       (make-instance 'state-ref
                      :scope scope-key
                      :key (state-key key))))))

(defun state-reference-from-arguments (target arguments)
  "Parse state mutation constructor arguments.

TARGET may be an existing STATE-REF, or a scope designator followed by
positional arguments. Examples:

  (state-set (state-ref :self :switch) :on)
  (state-set :global :recipe t)
  (state-toggle :self :switch)
  (state-set :ref :door :open t)"
  (cond
    ((typep target 'state-ref)
     (values target arguments))
    (t
     (let ((scope (state-scope-key target)))
       (case scope
         (:ref
          (unless (>= (length arguments) 2)
            (error "REF state references need a role and key."))
          (values (state-ref :ref (first arguments) (second arguments))
                  (cddr arguments)))
         (otherwise
          (unless arguments
            (error "~S state references need a key." scope))
          (values (state-ref scope (first arguments))
                  (rest arguments))))))))

(define-ast-node condition-eq ()
  ((left :reader condition-left :initarg :left :initform nil)
   (right :reader condition-right :initarg :right :initform nil))
  (:constructor condition-eq (left right) :left left :right right))

(define-ast-node condition-not ()
  ((condition :reader condition-child :initarg :condition :initform nil))
  (:constructor condition-not (condition) :condition condition))

(define-ast-node condition-and ()
  ((conditions :reader conditions :initarg :conditions :initform nil))
  (:constructor condition-and (&rest conditions) :conditions conditions))

(define-ast-node condition-or ()
  ((conditions :reader conditions :initarg :conditions :initform nil))
  (:constructor condition-or (&rest conditions) :conditions conditions))

(define-ast-node sequence (effect-node)
  ((effects :reader sequence-effects :initarg :effects :initform nil))
  (:constructor sequence (&rest effects) :effects effects))

(define-ast-node state-effect (effect-node)
  ((target :reader effect-target :initarg :target :initform nil)))

(define-ast-node state-set (state-effect)
  ((value :reader effect-value :initarg :value :initform nil)))

(defun state-set (target &rest arguments)
  (multiple-value-bind (reference rest) (state-reference-from-arguments target arguments)
    (destructuring-bind (value) rest
      (make-instance 'state-set :target reference :value value))))

(define-ast-node state-clear (state-effect)
  ())

(defun state-clear (target &rest arguments)
  (multiple-value-bind (reference rest) (state-reference-from-arguments target arguments)
    (when rest
      (error "STATE-CLEAR does not take a value."))
    (make-instance 'state-clear :target reference)))

(define-ast-node state-inc (state-effect)
  ((amount :reader effect-amount :initarg :amount :initform 1)))

(defun state-inc (target &rest arguments)
  (multiple-value-bind (reference rest) (state-reference-from-arguments target arguments)
    (destructuring-bind (&optional (amount 1)) rest
      (make-instance 'state-inc :target reference :amount amount))))

(define-ast-node state-dec (state-effect)
  ((amount :reader effect-amount :initarg :amount :initform 1)))

(defun state-dec (target &rest arguments)
  (multiple-value-bind (reference rest) (state-reference-from-arguments target arguments)
    (destructuring-bind (&optional (amount 1)) rest
      (make-instance 'state-dec :target reference :amount amount))))

(define-ast-node state-toggle (state-effect)
  ())

(defun state-toggle (target &rest arguments)
  (multiple-value-bind (reference rest) (state-reference-from-arguments target arguments)
    (when rest
      (error "STATE-TOGGLE does not take a value."))
    (make-instance 'state-toggle :target reference)))

(defun have? (key)
  (state-ref :global key))

(defun gain (key)
  (state-set :global key t))

(defun lose (key)
  (state-clear :global key))

(defun toggle (target &rest arguments)
  (apply #'state-toggle target arguments))

(define-ast-node say (effect-node)
  ((text :reader say-text :initarg :text :initform nil))
  (:constructor say (text) :text text))

(define-ast-node conditional-effect (effect-node)
  ((condition :reader conditional-effect-condition
              :initarg :condition
              :initform nil)
   (then-effects :reader conditional-effect-then
                 :initarg :then
                 :initform (sequence))
   (else-effects :reader conditional-effect-else
                 :initarg :else
                 :initform (sequence))))

(defun conditional-effect (condition then-effects &optional (else-effects (sequence)))
  (make-instance 'conditional-effect
                 :condition condition
                 :then (or then-effects (sequence))
                 :else (or else-effects (sequence))))

(define-ast-node choice ()
  ((label :accessor label :initarg :label :initform nil)
   (target :accessor target :initarg :target :initform nil)
   (id :reader choice-id :initarg :id :initform nil)
   (condition :reader choice-condition :initarg :condition :initform nil)
   (once :reader choice-once-p :initarg :once :initform nil)))

(define-ast-node choices ()
  ((options :accessor options :initarg :options :initform nil)))

(defun make-option (label target &key id condition once)
  (make-instance 'choice
                 :label label
                 :target target
                 :id (and id (choice-id-key id))
                 :condition condition
                 :once once))

(defmacro option (label target &key id when once)
  `(make-option ,label
                ,target
                :id ,id
                :condition ,when
                :once ,once))

(defmacro choice (&body options)
  `(make-instance 'choices
                  :options (list
                            ,@(mapcar (lambda (option)
                                        (destructuring-bind (label target &rest args) option
                                          `(option ,label ,target ,@args)))
                                      options))))

(define-ast-node entity ()
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
  (:children (thing) (entities thing)))

(defmacro entity (name &body body)
  (let ((id nil)
        (state nil)
        (refs nil)
        (forms body))
    (loop while (and forms (keywordp (first forms)))
          for key = (pop forms)
          do (case key
               (:id (setf id (pop forms)))
               (:state (setf state (pop forms)))
               (:refs (setf refs (pop forms)))
               (otherwise
                (error "Unknown entity option ~S." key))))
    `(make-instance 'entity
                    :name ,name
                    :id ,id
                    :state ',state
                    :refs ',refs
                    :entities (list ,@forms))))

(define-ast-node branch ()
  ((condition :reader branch-condition :initarg :condition :initform nil)
   (then-entities :reader branch-then-entities :initarg :then :initform nil)
   (else-entities :reader branch-else-entities :initarg :else :initform nil))
  (:children (thing)
    (append (branch-then-entities thing)
            (branch-else-entities thing))))

(defmacro branch (condition &key then else)
  `(make-instance 'branch
                  :condition ,condition
                  :then (list ,@then)
                  :else (list ,@else)))

(defmacro shown-when (condition &body entities)
  `(branch ,condition
           :then ,entities))

(defmacro shown-unless (condition &body entities)
  `(branch (condition-not ,condition)
           :then ,entities))

(define-ast-node action ()
  ((label :accessor label :initarg :label :initform nil)
   (effects :reader effects :initarg :effects :initform nil)
   (owner :accessor action-owner :initarg :owner :initform nil)))

(defmacro action (label &body effects)
  `(make-instance 'action
                  :label ,label
                  :effects (sequence ,@effects)))

(define-ast-node refresh (control-node)
  ()
  (:constructor refresh ()))

(define-ast-node placement ()
  ((thing :reader placed-thing :initarg :thing :initform nil)
   (description :reader placement-description :initarg :description :initform nil)
   (interaction-label :reader interaction-label
                      :initarg :interaction-label
                      :initform nil)
   (interaction-target :reader interaction-target
                       :initarg :interaction-target
                       :initform nil))
  (:constructor placed (thing &key description interaction-label interaction-target)
   :thing thing
   :description description
   :interaction-label interaction-label
   :interaction-target interaction-target))

(define-ast-node item ()
  ((name :reader name :initarg :name :initform nil)
   (description :reader description :initarg :description :initform nil))
  (:constructor item (name &key description) :name name :description description))

(define-ast-node container ()
  ((name :reader name :initarg :name :initform nil)
   (description :reader description :initarg :description :initform nil)
   (open-choice :reader open-choice :initarg :open-choice :initform nil)
   (close-choice :reader close-choice :initarg :close-choice :initform nil)
   (contents :accessor contents :initarg :contents :initform nil))
  (:children (thing) (contents thing)))

(defmacro container (name &key description open-choice contents close-choice)
  `(make-instance 'container
                  :name ,name
                  :description ,description
                  :open-choice ,open-choice
                  :contents (list ,@contents)
                  :close-choice ,close-choice))

(define-ast-node container-view ()
  ((container :reader viewed-container :initarg :container :initform nil))
  (:constructor container-view (container) :container container))

(define-ast-node p ()
  ((text :reader text :initarg :text :initform nil))
  (:constructor p (text) :text text)
  (:class-option (:documentation "A paragraph of descriptive text.")))

(define-ast-node quit (control-node)
  ()
  (:constructor quit ()))

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
  (clrhash (game-global-state game))
  (clrhash (game-taken-choices game))
  (dolist (room (game-rooms game))
    (prepare-room-scene room))
  game)

(defvar *validation-errors* nil)
(defvar *validation-choice-ids* nil)

(defgeneric validate-node (thing game context)
  (:documentation "Validate a Dunge AST node in GAME and CONTEXT."))

(defun validation-error (format-control &rest format-arguments)
  (push (apply #'format nil format-control format-arguments)
        *validation-errors*))

(defun static-room-name-p (thing)
  (stringp thing))

(defun validate-room-target (node game room-name)
  (when (static-room-name-p room-name)
    (unless (nth-value 1 (gethash room-name (room-index game)))
      (validation-error "~A targets missing room ~S."
                        (class-name (class-of node))
                        room-name))))

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

(defun validate-game (game)
  (let ((*validation-errors* nil)
        (*validation-choice-ids* (make-hash-table :test 'eql)))
    (dolist (room (game-rooms game))
      (validate-node room game room))
    (when *validation-errors*
      (error "Game validation failed:~%~{  - ~A~%~}"
             (nreverse *validation-errors*))))
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
  (validate-node-list (entities thing) game thing))

(defmethod validate-node ((thing branch) game context)
  (validate-node (branch-condition thing) game context)
  (validate-node-list (branch-then-entities thing) game context)
  (validate-node-list (branch-else-entities thing) game context))

(defmethod validate-node ((thing choices) game context)
  (validate-node-list (options thing) game context))

(defmethod validate-node ((thing choice) game context)
  (validate-choice-id thing)
  (when (choice-condition thing)
    (validate-node (choice-condition thing) game context))
  (validate-node (target thing) game context))

(defun validate-effect-tree (effects game context)
  (cond
    ((null effects)
     nil)
    ((listp effects)
     (validation-error "Effect lists are not valid; wrap effects in (sequence ...)."))
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
  (validate-node (condition-left thing) game context)
  (validate-node (condition-right thing) game context))

(defmethod validate-node ((thing condition-not) game context)
  (validate-node (condition-child thing) game context))

(defmethod validate-node ((thing condition-and) game context)
  (validate-node-list (conditions thing) game context))

(defmethod validate-node ((thing condition-or) game context)
  (validate-node-list (conditions thing) game context))

(defmethod validate-node ((thing state-ref) game context)
  (declare (ignore game context))
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
                         (state-ref-scope thing))))
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
  (validate-node (conditional-effect-condition thing) game context)
  (validate-effect-tree (conditional-effect-then thing) game context)
  (validate-effect-tree (conditional-effect-else thing) game context))

(defmethod validate-node ((thing goto) game context)
  (declare (ignore context))
  (validate-room-target thing game (room-name thing)))

(defmethod validate-node ((thing gosub) game context)
  (declare (ignore context))
  (validate-room-target thing game (room-name thing)))
