(uiop:define-package #:dunge/dice
  (:use #:cl)
  (:export #:roll-dice
	   #:roll-d20))

(in-package :dunge/dice)

(defun roll-dice (&rest sides)
  "Roll dice with the given number of sides."
  (loop for sides in sides
	collect (1+ (random sides))))

(defun roll-d20 ()
  "Roll a single d20."
  (first (roll-dice 20)))

