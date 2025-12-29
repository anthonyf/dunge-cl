(uiop:define-package :dunge/engine
  (:use #:cl)
  (:export #:*current-scene*
	   #:perform
	   #:execute-choice
	   #:choice-text
	   #:play-game))

(in-package :dunge/engine)

(defparameter *current-scene* nil)

(defgeneric perform (scene)
  (:documentation "Perform the given scene. Renders the scene's text and returns a list of available choices."))

(defgeneric execute-choice (choice)
  (:documentation "Execute the given choice, which may change the current scene or game state."))

(defgeneric choice-text (choice)
  (:documentation "Return the text description of the given choice."))

(defun play-game (start-scene)
  (loop with *current-scene* = start-scene
	while *current-scene*
	do (let ((choices (perform *current-scene*)))
	     (loop for choice in choices
		   for n from 1
		   do (format t "~a. ~a~%" n (choice-text choice)))
	     (format t "Choose an option: ")
	     (let* ((input (read-line))
		    (choice (parse-integer input :junk-allowed t)))
	       (when (and choice
			  (<= 1 choice (length choices)))
		 (execute-choice (nth (1- choice) choices)))))))

