(uiop:define-package #:dunge/dice
  (:use #:cl)
  (:export #:roll-dice
   ))

(in-package :dunge/dice)

(defun roll-dice (&rest sides)
  "Roll dice with the given number of sides."
  (loop for sides in sides
	collect (1+ (random sides))))
