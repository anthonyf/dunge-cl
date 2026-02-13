(uiop:define-package #:dunge/engine
  (:use #:cl)
  (:mix #:dunge/utils)
  (:export #:*vignette-stack*
	   #:current-vignette
	   #:set-vignette

	   #:perform
	   #:menu
	   #:choice
	   #:choice-label
	   #:choice-action
	   #:execute-action
	   
	   #:goto-choice
	   #:gosub-choice
	   #:return-choice

	   #:print-context
	   #:out

	   #:prompt
	   #:prompt-question
	   #:prompt-validate-fn
	   #:prompt-action

	   #:game-repl))

(in-package #:dunge/engine)

(defparameter *vignette-stack* nil)
(defun current-vignette ()
  (car *vignette-stack*))
(defun set-vignette (vignette)
  (setf (car *vignette-stack*)
	vignette))
(defun push-vignette (vignette)
  (push vignette *vignette-stack*))
(defun pop-vignette ()
  (pop *vignette-stack*))

(defgeneric perform (ctx vignette))

(defgeneric menu (ctx choices))
(defgeneric choice-label (choice))
(defgeneric choice-action (choice))
(defgeneric execute-action (action &rest args))

(defgeneric out (ctx str))

;; implentations

(defclass print-context ()())

(defmethod perform (ctx (fun function))
  (funcall fun ctx))

(defmethod menu ((ctx print-context) (choices list))
  (tagbody
     (loop for choice in choices
	   for n from 1
	   do (format t "~a. ~a~%" n (choice-label choice)))
   prompt
     (format t "Enter choice: ")
     (let* ((line (read-line))
	    (n (parse-integer line :junk-allowed t)))
       (when (or (< n 1)(> n (length choices)))
	 (format t "Invalid input: ~a~%" line)
	 (go prompt))
       (execute-action (choice-action (nth (1- n) choices))))))


(defmethod execute-action ((fun function) &rest args)
  (apply fun args))

(defun game-repl (starting-vignette)
  (let ((ctx (make-instance 'print-context))
	(*vignette-stack* (list starting-vignette)))
    (loop while *vignette-stack*
	  for vignette = (current-vignette)
	  for choices = (perform ctx vignette)
	  do (menu ctx choices))))

(defmethod out ((ctx print-context) str)
  (princ str))

(defclass choice ()
  ((label :initarg :label :accessor choice-label)
   (action :initarg :action :accessor choice-action)))

(defun goto-choice (label vignette)
  (make-instance 'choice
		 :label label
		 :action (lambda ()
			   (set-vignette vignette))))

(defun gosub-choice (label vignette)
  (make-instance 'choice
		 :label label
		 :action (lambda ()
			   (push-vignette vignette))))

(defun return-choice (label)
  (make-instance 'choice
		 :label label
		 :action (lambda ()
			   (pop-vignette))))

(defclass prompt ()
  ((question :initarg :question :accessor prompt-question)
   (validate-fn :initarg :validate-fn :accessor prompt-validate-fn)
   (action :initarg :action :accessor prompt-action)))

(defmethod perform (ctx (prompt prompt))
  prompt)

(defmethod menu ((ctx print-context) (prompt prompt))
  (tagbody
   retry
     (format t "~a > " (prompt-question prompt))
     (let ((line (trim-whitespace (read-line))))
       (cond ((funcall (prompt-validate-fn prompt) line)
	      (funcall (prompt-action prompt) line))
	     (t
	      (format t "Invalid input: ~a~%" line)
	      (go retry))))))


