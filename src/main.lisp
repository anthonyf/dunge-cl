(uiop:define-package #:dunge
  (:use #:cl)
  (:export ))

(in-package #:dunge)

;;; DSL
(defparameter *quit* nil)
(defparameter *place* nil "represents the current place the player is at")
(defparameter *actions* (make-hash-table :test #'equalp) "list of all actions available in the game")

(defclass place ()
  ())

(defclass action ()
  ((command :initarg :command :accessor action-command)
   (description :initarg :description :accessor description)
   (validation-fn :initarg :validation-fn :accessor validation-fn)
   (action-fn :initarg :action-fn :accessor action-fn)))

(defgeneric title (place)
  (:documentation "Return the title of the place."))

(defgeneric description (place)
  (:documentation "Return the description of the place."))

(defgeneric do-action (action)
  (:documentation "Perform the action."))

(defgeneric valid-action-p (action)
  (:documentation "Return true if the action is valid in the current context."))

(eval-when (:compile-toplevel :load-toplevel :execute)
  
  (defmacro define-action (command &key description when do)
    (a (command description when do)
      `(let ((action (make-instance 'action
				   :command ,command
				   :description ,description
				   :validation-fn (lambda () ,when)
				   :action-fn (lambda () ,do))))
	(setf (gethash ,command *actions*) action))))

  (defmacro place (name description)
    `(progn
	   (defclass ,name (place)
	 ())
	   (defmethod title ((p ,name))))))

;;; Game REPL

(defun valid-actions ()
  (remove-if-not
   (lambda (action)
     (valid-action-p action))
   *actions*))

(defun print-actions-menu (actions)
  (loop for action in actions
	for x from 1
	do (format t "~A: ~A~%" x (action-command action))
	finally (format t "Choose an action by number: ")))

(defun process-input (line)
  (let* ((input (parse-integer line :junk-allowed t))
	 (actions (valid-actions)))
	(if (and input
	     (>= input 1)
	     (<= input (length actions)))
	(let ((action (nth (1- input) actions)))
	  (do-action action))
	  (format t "Invalid input. Please try again.~%"))))

(defun game-repl ()
  (loop until *quit*
	do (progn
	     (format t "~A~%" (title *place*))
	     (format t "~A~%~%" (description *place*))
	     (print-actions-menu (valid-actions))
	     (let ((input (read-line)))
	       (process-input input)))))

;;; 

(define-action quit "Quit the game"
  :when t
  :do (setf *quit* t))



;;; game example

(place town-square
       "You are in the bustling town square. Merchants are selling their wares and townsfolk are going about their day.")

(place blacksmiths-shop
       "You are inside the blacksmith's shop. The sound of hammering metal fills the air.")

(path town-square west blacksmiths-shop)
