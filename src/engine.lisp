(uiop:define-package :dunge/engine
  (:use #:cl)
  (:export #:*current-scene*
	   #:perform
	   #:execute-choice
	   #:choice-text
	   #:play-game
	   #:prn
	   #:prnln))

(in-package :dunge/engine)

(defparameter *current-scene* nil)

(defun prn (&rest strs)
  (format t "~{~A~}" strs))

(defun prnln (&rest strs)
  (format t "~{~A~}~%" strs))

(defgeneric perform (scene)
  (:documentation "Perform the given scene. Renders the scene's text and returns a list of available choices."))

(defgeneric execute-choice (choice)
  (:documentation "Execute the given choice, which may change the current scene or game state."))

(defgeneric choice-text (choice)
  (:documentation "Return the text description of the given choice."))

(defun print-menu (choices)
  (loop for choice in choices
	for n from 1
	do (prnln n ". " (choice-text choice)))
  (prn "Choose an option: "))


(defun run-scene (scene)
  (catch :finish-scene
    (let ((choices (perform scene)))
      (tagbody
       :retry
	 (print-menu choices)
	 (let* ((input (read-line))
		(choice (parse-integer input :junk-allowed t)))
	   (if (and choice
		    (<= 1 choice (length choices)))
	       (execute-choice (nth (1- choice) choices))
	       (progn (prnln "Invalid choice: " input)
		      (go :retry))))))))

(defun play-game (start-scene)
  (loop with *current-scene* = start-scene
	while *current-scene*
	do (run-scene *current-scene*)))

