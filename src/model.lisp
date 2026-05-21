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
		  :condition ',condition
		  :entities (list ,@entities)))

(defclass action ()
  ((label :accessor label :initarg :label :initform nil)
   (effects :reader effects :initarg :effects :initform nil)))

(defmacro action (label &body effects)
  `(make-instance 'action
		  :label ,label
		  :effects ',effects))

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
