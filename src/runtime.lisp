(in-package #:dunge)

;;; Runtime protocol
;;; Control protocol: control AST nodes evaluate to themselves and are
;;; propagated upward unchanged. A room with no choices offers a Continue
;;; choice back to its caller when the return stack is not empty, and
;;; otherwise returns FALL-THROUGH, which ends play. The game loop consumes
;;; these objects and dispatches on their type.

(defvar *input* *standard-input*)
(defvar *output* *standard-output*)
(defvar *pause-after-say* nil)
(defvar *debug* nil
  "When true, console play exposes debug controls such as Undo.")
(defvar *pending-choice-spacing* nil)

(defstruct runtime-context
  game
  world
  scene
  self
  session)

(defstruct (runtime-session
             (:constructor %make-runtime-session (game world)))
  game
  world
  undo-stack)

(defun runtime-session-location (session)
  (world-location (runtime-session-world session)))

(defun (setf runtime-session-location) (location session)
  (setf (world-location (runtime-session-world session)) location))

(defun runtime-session-return-stack (session)
  (world-return-stack (runtime-session-world session)))

(defun (setf runtime-session-return-stack) (return-stack session)
  (setf (world-return-stack (runtime-session-world session)) return-stack))

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
    (cond
      (present-p room)
      (t
       (error "No room named ~S." room-name)))))

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

(defun runtime-context-for-scene (context scene)
  (check-type context runtime-context)
  (make-runtime-context
   :game (runtime-context-game context)
   :world (runtime-context-world context)
   :scene scene
   :self nil
   :session (runtime-context-session context)))

(defun runtime-context-for-self (context self)
  (check-type context runtime-context)
  (make-runtime-context
   :game (runtime-context-game context)
   :world (runtime-context-world context)
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
