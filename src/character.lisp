(uiop:define-package #:dunge/character
  (:use #:cl)
  (:mix #:dunge/dice
	#:dunge/text-layout)
  (:export #:character
	   #:character-name
	   #:character-strength
	   #:character-intelligence
	   #:character-wisdom
	   #:character-dexterity
	   #:character-constitution
	   #:character-charisma
	   
	   #:roll-attributes
	   #:create-character
	   #:attribute-modifier)
  (:shadow #:character))


(in-package :dunge/character)

(defparameter *attribute-modifiers*
  '((3 . -3)
    (4 . -2)
    (5 . -2)
    (6 . -1)
    (7 . -1)
    (8 . -1)
    (9 . 0)
    (10 . 0)
    (11 . 0)
    (12 . 0)
    (13 . 1)
    (14 . 1)
    (15 . 1)
    (16 . 2)
    (17 . 2)
    (18 . 3)))

(defclass character ()
  ((name :initarg :name :accessor character-name)
   (race :initarg :race :accessor character-race)
   (class :initarg :class :accessor character-class)
   (level :initform 1 :accessor character-level)
   (strength :initarg :strength :accessor character-strength)
   (intelligence :initarg :intelligence :accessor character-intelligence)
   (wisdom :initarg :wisdom :accessor character-wisdom)
   (dexterity :initarg :dexterity :accessor character-dexterity)
   (constitution :initarg :constitution :accessor character-constitution)
   (charisma :initarg :charisma :accessor character-charisma)))

(defun attribute-modifier (character attribute)
  (let ((value (funcall (intern (format nil "CHARACTER-~a" attribute) :dunge/character) character)))
    (cdr (assoc value *attribute-modifiers*))))

(defun shuffle (seq)
  "Knuth shuffle the given sequence."
  (let ((n (length seq)))
    (dotimes (i n seq)
      (rotatef (elt seq i)
               (elt seq (+ i (random (- n i))))))))

#+nil
(let ((list (list 1 2 3 4 5 6)))
  (values list (shuffle! list)))

(defun roll-attribute ()
  "Roll 4d6, drop the lowest die, and return the sum of the remaining three."
  (let* ((rolls (roll-dice 6 6 6 6))
	 (sorted-rolls (sort rolls #'<))
	 (best-three (cdr sorted-rolls)))
    (values (reduce #'+ best-three)
	    best-three)))

#+nil
(roll-attribute)

(defun roll-attributes ()
  "For each of the six attributes, roll 4d6,
drop the lowest die, and add them together. You can swap these rolls
around to different attributes if you have a particular sort of hero in
mind. If no roll is 16 or better, pick an attribute and set it to 16. A
hero is always remarkably good at something."
  (let ((attributes (loop repeat 6
			  collect (roll-attribute))))
    (unless (some (lambda (attr)
		    (>= attr 16)) attributes)
      ;; set the lowest attribute to 16
      (let ((min-attr (apply #'min attributes)))
	(setf attributes (remove min-attr attributes :count 1))
	(push 16 attributes)))
    (setf attributes (sort attributes #'>))
    (values attributes
	    (reduce #'+ attributes))))
  
#+nil
(roll-attributes)

(defparameter *attribute-priority*
  '((fighter . ((strength constitution) (dexterity) (wisdom charisma intelligence)))
    (wizard . ((intelligence) (wisdom constitution dexterity strength charisma)))
    (thief . ((dexterity) (intelligence constitution wisdom strength charisma)))
    (cleric . ((wisdom) (constitution strength dexterity intelligence charisma)))))

(defun attributes-for-class (class attributes)
  (let ((priority (cdr (assoc class *attribute-priority*))))
    (loop for attrs in priority
	  append (loop for attr in (shuffle (copy-seq attrs))
		       collect (cons attr (pop attributes))))))

#+nil
(attributes-for-class 'fighter (roll-attributes))

(defparameter *initial-hit-points*
  '((fighter . 8)
    (wizard . 4)
    (thief . 4)
    (cleric . 6)))

(defparameter *hp-gained-per-level*
  '((fighter . 4)
    (wizard . 2)
    (thief . 2)
    (cleric . 3)))


(defun total-hit-points (character)
  (let ((constitution-mod (attribute-modifier character 'constitution))
	(initial-hp (cdr (assoc (character-class character)
				*initial-hit-points*)))
	(hp-gained-per-level (cdr (assoc (character-class character)
				       *hp-gained-per-level*))))
    (+ initial-hp
       (* (character-level character)
	  (+ hp-gained-per-level constitution-mod)))))

(defun create-character (name class)
  (let* ((attributes (roll-attributes))
	 (class-attrs (attributes-for-class class attributes)))
    (make-instance 'character
		   :name name
		   :class class
		   :strength (cdr (assoc 'strength class-attrs))
		   :intelligence (cdr (assoc 'intelligence class-attrs))
		   :wisdom (cdr (assoc 'wisdom class-attrs))
		   :dexterity (cdr (assoc 'dexterity class-attrs))
		   :constitution (cdr (assoc 'constitution class-attrs))
		   :charisma (cdr (assoc 'charisma class-attrs)))))

(defun print-character-sheet (character)
  (flet ((fmt-attr-mod (modifyer)
	   (cond 
	     ((> modifyer 0)
	      (format nil "(+~a)" modifyer))
	     ((< modifyer 0)
	      (format nil "(~a)" modifyer))
	     (t ""))))
    
    (columns
     (lines ("Name: ~a" (character-name character))
	    ("Class: ~a" (character-class character))
	    ("Level: ~a" (character-level character))
	    ("HP: ~a" (total-hit-points character)))
    
     (lines ("Str: ~a ~a" (character-strength character)
			    (fmt-attr-mod (attribute-modifier character 'strength)))
	    ("Int: ~a ~a" (character-intelligence character)
			    (fmt-attr-mod (attribute-modifier character 'intelligence)))
	    ("Wis: ~a ~a" (character-wisdom character)
			    (fmt-attr-mod (attribute-modifier character 'wisdom)))
	    ("Dex: ~a ~a" (character-dexterity character)
			    (fmt-attr-mod (attribute-modifier character 'dexterity)))
	    ("Con: ~a ~a" (character-constitution character)
			    (fmt-attr-mod (attribute-modifier character 'constitution)))
	    ("Cha: ~a ~a" (character-charisma character)
			    (fmt-attr-mod (attribute-modifier character 'charisma)))))
    ))
  

#+nil
(print-character-sheet (create-character "Aragorn" 'fighter))
