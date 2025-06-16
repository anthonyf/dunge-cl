(uiop:define-package #:dunge
  (:use #:cl)
  (:mix-reexport #:dunge/generics)
  (:local-nicknames (#:i #:dunge/capi/interface))
  (:export #:main))

(in-package #:dunge)

(defclass simple-command ()
  ((text :initarg :text
	 :accessor text)
   (execute-fn :initarg :execute-fn
	       :accessor execute-fn)))

(defmethod execute ((command simple-command))
  (with-accessors ((execute-fn execute-fn)) command
    (funcall execute-fn)))

(defclass game-state ()
  ((text :initform "This is the initial text"
	 :accessor text)))

(defmethod commands ((gs game-state))
  (list (make-instance 'simple-command :text "Do something" :execute-fn (lambda () (setf (text gs) "Did it")))))

(defun main ()
  (setf *game-state* (make-instance 'game-state))
  (i:run-capi-game))

