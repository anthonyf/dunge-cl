(in-package #:dunge)

(defun roll-dice (&rest sides)
  "Roll dice with the given number of sides."
  (loop for sides in sides
	collect (1+ (random sides))))

(defun roll-d20 ()
  "Roll a single d20."
  (first (roll-dice 20)))

