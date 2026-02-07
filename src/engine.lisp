(uiop:define-package :dunge/engine
  (:use #:cl)
  (:export #:*current-scene*
	   #:choice-menu
	   #:prn
	   #:prnln))

(in-package :dunge/engine)

(defun prn (&rest strs)
  (format t "~{~A~}" strs))

(defun prnln (&rest strs)
  (format t "~{~A~}~%" strs))


(defun print-menu (choices)
  (loop for (choice-text . _) in choices
	for n from 1
	do (prnln n ". " choice-text))
  (prn "> "))


(defun choice-menu (choices)
  (tagbody
   :retry
     (print-menu choices)
     (let* ((input (read-line))
	    (choice (parse-integer input :junk-allowed t)))
       (if (and choice
		(<= 1 choice (length choices)))
	   (funcall (cdr (nth (1- choice) choices)))
	   (progn (prnln "Invalid choice: " input)
		  (go :retry))))))


