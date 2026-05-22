(in-package #:dunge)

;;; Game model and DSL constructors

(defclass game ()
  ((rooms :reader game-rooms :initarg :rooms :initform nil)
   (global-state :reader game-global-state
		 :initform (make-hash-table :test 'equal))
   (player :accessor game-player :initarg :player :initform nil)
   (room-index :reader room-index :initform (make-hash-table :test 'equal))
   (start :accessor game-start :initarg :start :initform nil)))

(defmethod initialize-instance :after ((game game) &key)
  (clrhash (room-index game))
  (dolist (room (game-rooms game))
    (multiple-value-bind (existing-room present-p) (gethash (name room) (room-index game))
      (declare (ignore existing-room))
      (when present-p
	(error "Duplicate room named ~S." (name room))))
    (setf (gethash (name room) (room-index game)) room))
  (unless (game-start game)
    (setf (game-start game) (and (game-rooms game)
				 (name (first (game-rooms game)))))))

(defun game (&rest rooms)
  (let ((game (make-instance 'game :rooms rooms)))
    (prepare-game game)
    game))

(defclass room ()
  ((name :reader name :initarg :name :initform nil)
   (scene-index :reader scene-index
		:initform (make-hash-table :test 'equal))
   (entities :accessor entities :initform nil :initarg :entities)))

(defun room (name &rest entities)
  (make-instance 'room :name name :entities entities))

(defclass goto ()
  ((room-name :reader room-name :initarg :room-name :initform nil)))

(defun goto (room-name)
  (make-instance 'goto :room-name room-name))

(defclass gosub ()
  ((room-name :reader room-name :initarg :room-name :initform nil)))

(defun gosub (room-name)
  (make-instance 'gosub :room-name room-name))

(defclass enter ()
  ((target :reader enter-target :initarg :target :initform nil)))

(defun enter (target)
  (make-instance 'enter :target target))

(defclass back ()
  ())

(defun back ()
  (make-instance 'back))

(defun operator-name (operator)
  (unless (symbolp operator)
    (error "DSL operator must be a symbol, got ~S." operator))
  (string-downcase (symbol-name operator)))

(defun split-reference-path (symbol)
  (let ((name (string-downcase (symbol-name symbol)))
	(start 0)
	(parts nil))
    (loop for dot = (position #\. name :start start)
	  do (push (subseq name start dot) parts)
	  while dot
	  do (setf start (1+ dot)))
    (nreverse parts)))

(defun state-path-symbol-p (thing)
  (and (symbolp thing)
       (find #\. (symbol-name thing))))

(defun normalize-state-scope (scope)
  (let ((name (etypecase scope
		(symbol (string-downcase (symbol-name scope)))
		(string (string-downcase scope)))))
    (cond
      ((string= name "self") :self)
      ((string= name "global") :global)
      ((string= name "ref") :ref)
      (t (error "Unknown state scope ~S." scope)))))

(defclass state-ref ()
  ((scope :reader state-ref-scope :initarg :scope :initform :global)
   (role :reader state-ref-role :initarg :role :initform nil)
   (key :reader state-ref-key :initarg :key :initform nil)))

(defun state-ref (scope key &optional state-key)
  (let ((normalized-scope (normalize-state-scope scope)))
    (cond
      ((eq normalized-scope :ref)
       (unless state-key
	 (error "REF state references must include a role and key."))
       (make-instance 'state-ref
		      :scope normalized-scope
		      :role key
		      :key state-key))
      (state-key
       (error "~S state references take only one key." normalized-scope))
      (t
       (make-instance 'state-ref
		      :scope normalized-scope
		      :key key)))))

(defun state-ref-from-path (path)
  (let ((parts (split-reference-path path)))
    (destructuring-bind (scope &rest rest) parts
      (cond
	((string= scope "self")
	 (unless (= (length rest) 1)
	   (error "State path ~S must look like self.name." path))
	 (state-ref :self (first rest)))
	((string= scope "global")
	 (unless (= (length rest) 1)
	   (error "State path ~S must look like global.name." path))
	 (state-ref :global (first rest)))
	((string= scope "ref")
	 (unless (= (length rest) 2)
	   (error "State path ~S must look like ref.name.state." path))
	 (state-ref :ref (first rest) (second rest)))
	(t
	 (error "Unknown state path scope ~S in ~S." scope path))))))

(defun state-reference-from-arguments (target arguments)
  (cond
    ((typep target 'state-ref)
     (values target arguments))
    ((state-path-symbol-p target)
     (values (state-ref-from-path target) arguments))
    (t
     (let ((scope (normalize-state-scope target)))
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

(defclass effect-node ()
  ())

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
		 :initform nil)
   (else-effects :reader conditional-effect-else
		 :initarg :else
		 :initform nil)))

(defun conditional-effect (condition then-effects &optional else-effects)
  (make-instance 'conditional-effect
		 :condition condition
		 :then then-effects
		 :else else-effects))

(defclass choice ()
  ((label :accessor label :initarg :label :initform nil)
   (target :accessor target :initarg :target :initform nil)))

(defclass choices ()
  ((options :accessor options :initarg :options :initform nil)))

(defun option (label target)
  (make-instance 'choice :label label :target target))

(defmacro choice (&body options)
  `(make-instance 'choices
		  :options (list
			    ,@(mapcar (lambda (option)
					(destructuring-bind (label target) option
					  `(option ,label ,target)))
				      options))))

(defclass entity ()
  ((name :reader name :initarg :name :initform nil)
   (id :reader entity-id :initarg :id :initform nil)
   (state-declarations :reader state-declarations
		       :initarg :state
		       :initform nil)
   (local-state :reader local-state
		:initform (make-hash-table :test 'equal))
   (refs :reader entity-refs :initarg :refs :initform nil)
   (resolved-refs :reader resolved-refs
		  :initform (make-hash-table :test 'equal))
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

(defclass conditional ()
  ((condition :reader conditional-condition :initarg :condition :initform nil)
   (entities :accessor entities :initarg :entities :initform nil)))

(defmacro shown-when (condition &body entities)
  `(make-instance 'conditional
		  :condition (condition-form ',condition)
		  :entities (list ,@entities)))

(defclass action ()
  ((label :accessor label :initarg :label :initform nil)
   (effects :reader effects :initarg :effects :initform nil)))

(defmacro action (label &body effects)
  `(make-instance 'action
		  :label ,label
		  :effects (effect-sequence-from-forms ',effects)))

(defclass action-invocation ()
  ((owner :reader action-owner :initarg :owner :initform nil)
   (action :reader invoked-action :initarg :action :initform nil)))

(defun action-invocation (owner action)
  (make-instance 'action-invocation :owner owner :action action))

(defclass refresh ()
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

(defclass quit ()
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

(defmethod node-children ((thing conditional))
  (entities thing))

(defmethod node-children ((thing container))
  (contents thing))

(defun effect-operator-p (thing)
  (and (symbolp thing)
       (member (operator-name thing)
	       '("say" "set" "clear" "gain" "lose" "inc" "dec" "toggle"
		 "if" "goto" "gosub" "back" "quit" "refresh" "sequence")
	       :test #'string=)))

(defun expression-form (form)
  (cond
    ((typep form 'state-ref)
     form)
    ((state-path-symbol-p form)
     (state-ref-from-path form))
    ((and (consp form)
	  (string= (operator-name (first form)) "state-ref"))
     (apply #'state-ref (rest form)))
    (t form)))

(defun condition-form (form)
  (cond
    ((typep form 'state-ref)
     form)
    ((atom form)
     (expression-form form))
    (t
     (let ((operator (operator-name (first form)))
	   (arguments (rest form)))
       (cond
	 ((member operator '("=" "is" "eq") :test #'string=)
	  (destructuring-bind (left right) arguments
	    (condition-eq (expression-form left)
			  (expression-form right))))
	 ((string= operator "not")
	  (destructuring-bind (argument) arguments
	    (condition-not (condition-form argument))))
	 ((string= operator "and")
	  (apply #'condition-and (mapcar #'condition-form arguments)))
	 ((string= operator "or")
	  (apply #'condition-or (mapcar #'condition-form arguments)))
	 ((string= operator "have?")
	  (destructuring-bind (key) arguments
	    (have? key)))
	 ((string= operator "state-ref")
	  (apply #'state-ref arguments))
	 (t
	  (error "Unknown condition operator ~S." (first form))))))))

(defun effect-forms-from-branch (branch)
  (cond
    ((null branch)
     nil)
    ((and (consp branch)
	  (effect-operator-p (first branch)))
     (list (effect-form branch)))
    (t
     (mapcar #'effect-form branch))))

(defun effect-sequence-from-forms (forms)
  (apply #'sequence (mapcar #'effect-form forms)))

(defun effect-sequence-from-branch (branch)
  (apply #'sequence (effect-forms-from-branch branch)))

(defun effect-form (form)
  (cond
    ((or (typep form 'effect-node)
	 (typep form 'goto)
	 (typep form 'gosub)
	 (typep form 'enter)
	 (typep form 'back)
	 (typep form 'quit)
	 (typep form 'refresh))
     form)
    ((not (consp form))
     (error "Effect must be a list, got ~S." form))
    (t
     (let ((operator (operator-name (first form)))
	   (arguments (rest form)))
       (cond
	 ((string= operator "say")
	  (destructuring-bind (text) arguments
	    (say (expression-form text))))
	 ((string= operator "set")
	  (destructuring-bind (path value) arguments
	    (state-set (expression-form path)
		       (expression-form value))))
	 ((string= operator "clear")
	  (destructuring-bind (path) arguments
	    (state-clear (expression-form path))))
	 ((string= operator "gain")
	  (destructuring-bind (key) arguments
	    (gain key)))
	 ((string= operator "lose")
	  (destructuring-bind (key) arguments
	    (lose key)))
	 ((string= operator "inc")
	  (destructuring-bind (path &optional (amount 1)) arguments
	    (state-inc (expression-form path)
		       (expression-form amount))))
	 ((string= operator "dec")
	  (destructuring-bind (path &optional (amount 1)) arguments
	    (state-dec (expression-form path)
		       (expression-form amount))))
	 ((string= operator "toggle")
	  (destructuring-bind (path) arguments
	    (state-toggle (expression-form path))))
	 ((string= operator "if")
	  (destructuring-bind (condition then-branch &optional else-branch) arguments
	    (conditional-effect (condition-form condition)
				(effect-sequence-from-branch then-branch)
				(effect-sequence-from-branch else-branch))))
	 ((string= operator "goto")
	  (destructuring-bind (room-name) arguments
	    (goto (expression-form room-name))))
	 ((string= operator "gosub")
	  (destructuring-bind (room-name) arguments
	    (gosub (expression-form room-name))))
	 ((string= operator "back")
	  (back))
	 ((string= operator "quit")
	  (quit))
	 ((string= operator "refresh")
	  (refresh))
	 ((string= operator "sequence")
	  (effect-sequence-from-forms arguments))
	 (t
	  (error "Unknown effect operator ~S." (first form))))))))

(defun normalize-state-key (name)
  (etypecase name
    (symbol (string-downcase (symbol-name name)))
    (string (string-downcase name))))

(defun normalize-id-key (id)
  (etypecase id
    (symbol (string-downcase (symbol-name id)))
    (string (string-downcase id))))

(defun reset-local-state (thing)
  (when (typep thing 'entity)
    (clrhash (local-state thing))
    (dolist (declaration (state-declarations thing))
      (destructuring-bind (name value) declaration
	(setf (gethash (normalize-state-key name) (local-state thing))
	      value))))
  (dolist (child (node-children thing))
    (reset-local-state child)))

(defun index-scene-node (scene thing)
  (let ((id (node-id thing)))
    (when id
      (let ((key (normalize-id-key id)))
	(multiple-value-bind (existing present-p) (gethash key (scene-index scene))
	  (declare (ignore existing))
	  (when present-p
	    (error "Duplicate scene id ~S in room ~S." id (name scene))))
	(setf (gethash key (scene-index scene)) thing))))
  (dolist (child (node-children thing))
    (index-scene-node scene child)))

(defun resolve-node-refs (scene thing)
  (when (typep thing 'entity)
    (clrhash (resolved-refs thing))
    (dolist (ref (entity-refs thing))
      (destructuring-bind (role target-id) ref
	(let* ((role-key (normalize-state-key role))
	       (target-key (normalize-id-key target-id))
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

(defun prepare-room-scene (room)
  (clrhash (scene-index room))
  (reset-local-state room)
  (dolist (entity (entities room))
    (index-scene-node room entity))
  (dolist (entity (entities room))
    (resolve-node-refs room entity)))

(defun prepare-game (game)
  (clrhash (game-global-state game))
  (dolist (room (game-rooms game))
    (prepare-room-scene room))
  game)
