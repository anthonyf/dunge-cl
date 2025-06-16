(uiop:define-package #:dunge/capi/interface
  (:use #:cl)
  (:mix #:dunge/capi/wrapping-layout)
  (:mix-reexport #:dunge/generics)
  (:export #:capi-game
	   #:run-capi-game))

(in-package #:dunge/capi/interface)

(defun make-command-button (text callback)
  (make-instance 'capi:push-button :text text
				   :callback-type :item
				   :callback callback))

(defclass capi-game (capi:column-layout)
  ((text-pane :accessor capi-game-text-pane
	      :initform (make-instance 'capi:rich-text-pane))
   (button-row :accessor capi-game-button-row
	       :initform (make-instance 'wrapping-layout))))

(defmethod initialize-instance :after ((game capi-game) &key)
  (with-slots (text-pane button-row) game
    (setf (capi:layout-description game)
	  (list text-pane button-row))))

(defmethod (setf commands) (commands (game capi-game))
  (with-accessors ((button-row capi-game-button-row))
      game
    (setf (capi:layout-description button-row)
	  (loop for command in commands
		collect (make-command-button (text command)
					     (make-button-callback game command))))))

(defmethod (setf text) (text (game capi-game))
  (with-accessors ((text-pane capi-game-text-pane))
      game
    (setf (capi:rich-text-pane-text text-pane)
	  text)))

(defun make-button-callback (game command)
  (lambda (button)
    (declare (ignore button))
    (execute command)
    (setf (text game)
	  (text *game-state*))
    (setf (commands game)
	  (commands *game-state*))))

(defun run-capi-game ()
  (let ((game (make-instance 'capi-game)))
    (capi:contain game)
    (capi:apply-in-pane-process game (lambda ()
				       (setf (text game)
					     (text *game-state*))
				       (setf (commands game)
					     (commands *game-state*))))
    ))

