(uiop:define-package #:dunge/generics
  (:use #:cl)
  (:export #:commands
	   #:text
	   #:execute

	   #:*game-state*))

(in-package #:dunge/generics)

(defparameter *game-state* nil)

(defgeneric commands (state))
(defgeneric text (thing))
(defgeneric execute (command))
