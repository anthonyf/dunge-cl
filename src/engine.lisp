(uiop:define-package #:dunge/engine
  (:use #:cl)
  (:export #:*vignette-stack*
	   #:current-vignette
	   #:set-vignette
	   #:push-vignette
	   #:pop-vignette

	   #:perform
	   #:menu
	   #:choice
	   #:choice-label
	   #:choice-action
	   #:execute-action
	   #:goto-choice

	   #:print-context
	   #:out

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
(defgeneric execute-action (action))

(defgeneric out (ctx str))

;; implentations

(defclass print-context ()())

(defmethod perform ((ctx print-context)(fun function))
  (funcall fun ctx))

(defmethod perform ((ctx print-context)(fun symbol))
  (funcall (symbol-function fun) ctx))

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


(defmethod execute-action ((sym symbol))
  (funcall (symbol-function sym)))

(defmethod execute-action ((fun function))
  (funcall fun))

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
