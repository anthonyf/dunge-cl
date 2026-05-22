(in-package #:dunge)

;;; Game model and DSL constructors

(defclass game ()
  ((rooms :reader game-rooms :initarg :rooms :initform nil)
   (global-state :reader game-global-state
		 :initform (make-hash-table :test 'eql))
   (taken-choices :reader game-taken-choices
		  :initform (make-hash-table :test 'eql))
   (player :accessor game-player :initarg :player :initform nil)
   (room-index :reader room-index :initform (make-hash-table :test 'equal))
   (start :accessor game-start :initarg :start :initform nil)))

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

(defclass room ()
  ((name :reader name :initarg :name :initform nil)
   (scene-index :reader scene-index
		:initform (make-hash-table :test 'equal))
   (entities :accessor entities :initform nil :initarg :entities)))

(defun room (name &rest entities)
  (make-instance 'room :name name :entities entities))

(defclass effect-node ()
  ())

(defclass control-node (effect-node)
  ())

(defclass fall-through (control-node)
  ())

(defun fall-through ()
  (make-instance 'fall-through))

(defclass goto (control-node)
  ((room-name :reader room-name :initarg :room-name :initform nil)))

(defun goto (room-name)
  (make-instance 'goto :room-name room-name))

(defclass gosub (control-node)
  ((room-name :reader room-name :initarg :room-name :initform nil)))

(defun gosub (room-name)
  (make-instance 'gosub :room-name room-name))

(defclass enter (control-node)
  ((target :reader enter-target :initarg :target :initform nil)))

(defun enter (target)
  (make-instance 'enter :target target))

(defclass back (control-node)
  ())

(defun back ()
  (make-instance 'back))

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

(defclass state-ref ()
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

(defclass condition-eq ()
  ((left :reader condition-left :initarg :left :initform nil)
   (right :reader condition-right :initarg :right :initform nil)))

(defun condition-eq (left right)
  (make-instance 'condition-eq :left left :right right))

(defclass condition-not ()
  ((condition :reader condition-child :initarg :condition :initform nil)))

(defun condition-not (condition)
  (make-instance 'condition-not :condition condition))

(defclass condition-and ()
  ((conditions :reader conditions :initarg :conditions :initform nil)))

(defun condition-and (&rest conditions)
  (make-instance 'condition-and :conditions conditions))

(defclass condition-or ()
  ((conditions :reader conditions :initarg :conditions :initform nil)))

(defun condition-or (&rest conditions)
  (make-instance 'condition-or :conditions conditions))

(defclass sequence (effect-node)
  ((effects :reader sequence-effects :initarg :effects :initform nil)))

(defun sequence (&rest effects)
  (make-instance 'sequence :effects effects))

(defclass state-effect (effect-node)
  ((target :reader effect-target :initarg :target :initform nil)))

(defclass state-set (state-effect)
  ((value :reader effect-value :initarg :value :initform nil)))

(defun state-set (target &rest arguments)
  (multiple-value-bind (reference rest) (state-reference-from-arguments target arguments)
    (destructuring-bind (value) rest
      (make-instance 'state-set :target reference :value value))))

(defclass state-clear (state-effect)
  ())

(defun state-clear (target &rest arguments)
  (multiple-value-bind (reference rest) (state-reference-from-arguments target arguments)
    (when rest
      (error "STATE-CLEAR does not take a value."))
    (make-instance 'state-clear :target reference)))

(defclass state-inc (state-effect)
  ((amount :reader effect-amount :initarg :amount :initform 1)))

(defun state-inc (target &rest arguments)
  (multiple-value-bind (reference rest) (state-reference-from-arguments target arguments)
    (destructuring-bind (&optional (amount 1)) rest
      (make-instance 'state-inc :target reference :amount amount))))

(defclass state-dec (state-effect)
  ((amount :reader effect-amount :initarg :amount :initform 1)))

(defun state-dec (target &rest arguments)
  (multiple-value-bind (reference rest) (state-reference-from-arguments target arguments)
    (destructuring-bind (&optional (amount 1)) rest
      (make-instance 'state-dec :target reference :amount amount))))

(defclass state-toggle (state-effect)
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

(defclass say (effect-node)
  ((text :reader say-text :initarg :text :initform nil)))

(defun say (text)
  (make-instance 'say :text text))

(defclass conditional-effect (effect-node)
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

(defclass choice ()
  ((label :accessor label :initarg :label :initform nil)
   (target :accessor target :initarg :target :initform nil)
   (id :reader choice-id :initarg :id :initform nil)
   (condition :reader choice-condition :initarg :condition :initform nil)
   (once :reader choice-once-p :initarg :once :initform nil)))

(defclass choices ()
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

(defclass entity ()
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
   (entities :accessor entities :initarg :entities :initform nil)))

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

(defclass branch ()
  ((condition :reader branch-condition :initarg :condition :initform nil)
   (then-entities :reader branch-then-entities :initarg :then :initform nil)
   (else-entities :reader branch-else-entities :initarg :else :initform nil)))

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

(defclass action ()
  ((label :accessor label :initarg :label :initform nil)
   (effects :reader effects :initarg :effects :initform nil)
   (owner :accessor action-owner :initarg :owner :initform nil)))

(defmacro action (label &body effects)
  `(make-instance 'action
		  :label ,label
		  :effects (sequence ,@effects)))

(defclass refresh (control-node)
  ())

(defun refresh ()
  (make-instance 'refresh))

(defclass placement ()
  ((thing :reader placed-thing :initarg :thing :initform nil)
   (description :reader placement-description :initarg :description :initform nil)
   (interaction-label :reader interaction-label
		      :initarg :interaction-label
		      :initform nil)
   (interaction-target :reader interaction-target
		       :initarg :interaction-target
		       :initform nil)))

(defun placed (thing &key description interaction-label interaction-target)
  (make-instance 'placement
		 :thing thing
		 :description description
		 :interaction-label interaction-label
		 :interaction-target interaction-target))

(defclass item ()
  ((name :reader name :initarg :name :initform nil)
   (description :reader description :initarg :description :initform nil)))

(defun item (name &key description)
  (make-instance 'item :name name :description description))

(defclass container ()
  ((name :reader name :initarg :name :initform nil)
   (description :reader description :initarg :description :initform nil)
   (open-choice :reader open-choice :initarg :open-choice :initform nil)
   (close-choice :reader close-choice :initarg :close-choice :initform nil)
   (contents :accessor contents :initarg :contents :initform nil)))

(defmacro container (name &key description open-choice contents close-choice)
  `(make-instance 'container
		  :name ,name
		  :description ,description
		  :open-choice ,open-choice
		  :contents (list ,@contents)
		  :close-choice ,close-choice))

(defclass container-view ()
  ((container :reader viewed-container :initarg :container :initform nil)))

(defun container-view (container)
  (make-instance 'container-view :container container))

(defclass p ()
  ((text :reader text :initarg :text :initform nil))
  (:documentation "A paragraph of descriptive text."))

(defun p (text)
  (make-instance 'p :text text))

(defclass quit (control-node)
  ())

(defun quit ()
  (make-instance 'quit))

(defgeneric node-id (thing)
  (:documentation "Return the scene-local id for THING, or NIL."))

(defgeneric node-children (thing)
  (:documentation "Return child AST nodes that participate in scene indexing."))

(defmethod node-id ((thing t))
  nil)

(defmethod node-id ((thing entity))
  (entity-id thing))

(defmethod node-children ((thing t))
  nil)

(defmethod node-children ((thing room))
  (entities thing))

(defmethod node-children ((thing entity))
  (entities thing))

(defmethod node-children ((thing branch))
  (append (branch-then-entities thing)
	  (branch-else-entities thing)))

(defmethod node-children ((thing container))
  (contents thing))

(defun reset-local-state (thing)
  (when (typep thing 'entity)
    (clrhash (local-state thing))
    (dolist (declaration (state-declarations thing))
      (destructuring-bind (name value) declaration
	(setf (gethash (state-key name) (local-state thing))
	      value))))
  (dolist (child (node-children thing))
    (reset-local-state child)))

(defun index-scene-node (scene thing)
  (let ((id (node-id thing)))
    (when id
      (let ((key (scene-id-key id)))
	(when (nth-value 1 (gethash key (scene-index scene)))
	  (error "Duplicate scene id ~S in room ~S." id (name scene)))
	(setf (gethash key (scene-index scene)) thing))))
  (dolist (child (node-children thing))
    (index-scene-node scene child)))

(defun resolve-node-refs (scene thing)
  (when (typep thing 'entity)
    (clrhash (resolved-refs thing))
    (dolist (ref (entity-refs thing))
      (destructuring-bind (role target-id) ref
	(let* ((role-key (ref-role-key role))
	       (target-key (scene-id-key target-id))
	       (target (gethash target-key (scene-index scene))))
	  (unless target
	    (error "Entity ~S in room ~S has ref ~S to missing id ~S."
		   (or (entity-id thing) (name thing))
		   (name scene)
		   role
		   target-id))
	  (setf (gethash role-key (resolved-refs thing)) target)))))
  (dolist (child (node-children thing))
    (resolve-node-refs scene child)))

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

(defmethod validate-node ((thing room) game context)
  (declare (ignore context))
  (dolist (child (entities thing))
    (validate-node child game thing)))

(defmethod validate-node ((thing entity) game context)
  (declare (ignore context))
  (dolist (child (entities thing))
    (validate-node child game thing)))

(defmethod validate-node ((thing branch) game context)
  (validate-node (branch-condition thing) game context)
  (dolist (child (branch-then-entities thing))
    (validate-node child game context))
  (dolist (child (branch-else-entities thing))
    (validate-node child game context)))

(defmethod validate-node ((thing choices) game context)
  (dolist (choice (options thing))
    (validate-node choice game context)))

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

(defmethod validate-node ((thing action) game context)
  (unless (typep context 'entity)
    (validation-error "Action ~S must be inside an entity." (label thing)))
  (validate-effect-tree (effects thing) game context))

(defmethod validate-node ((thing container) game context)
  (dolist (child (contents thing))
    (validate-node child game context)))

(defmethod validate-node ((thing placement) game context)
  (when (interaction-target thing)
    (validate-node (interaction-target thing) game context)))

(defmethod validate-node ((thing condition-eq) game context)
  (validate-node (condition-left thing) game context)
  (validate-node (condition-right thing) game context))

(defmethod validate-node ((thing condition-not) game context)
  (validate-node (condition-child thing) game context))

(defmethod validate-node ((thing condition-and) game context)
  (dolist (condition (conditions thing))
    (validate-node condition game context)))

(defmethod validate-node ((thing condition-or) game context)
  (dolist (condition (conditions thing))
    (validate-node condition game context)))

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
  (dolist (effect (sequence-effects thing))
    (validate-effect-tree effect game context)))

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
