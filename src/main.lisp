(uiop:define-package #:dunge
  (:use #:cl)
  (:shadow #:room)
  (:export #:main))

(in-package #:dunge)

(defgeneric text (thing))
(defgeneric execute (command))
(defgeneric commands (state))

(defgeneric print-text (ui text))
(defgeneric print-menu (ui commands))
(defgeneric read-command (ui))

(defvar *state* nil)

(defclass text-ui ()
  ())

(defmethod print-text ((ui text-ui) text)
  (format t "~a~%" text))

(defmethod print-menu ((ui text-ui) commands)
  (loop for cmd in commands
	do (format t "~a~%" (text cmd))))

(defmethod read-command ((ui text-ui))
  (let ((input (read-line)))
    (find input (commands *state*) :key #'text :test #'string=)))


(defclass question ()
  ((text :accessor text :initarg :text)
   (choices :accessor choices :initarg :choices)))

(defmethod commands ((state question))
  (choices state))

(defclass choice ()
  ((text :accessor text :initarg :text)
   (action :accessor action :initarg :action)))

(defmethod execute ((command choice))
  (funcall (action command)))

(defun run-game (ui starting-state)
  (let ((*state* starting-state))
    (loop do (progn (print-text ui (text *state*))
		    (print-menu ui (commands *state*))
		    (execute (read-command ui)))
	  while *state*)))


(defun main ()
  (run-game (make-instance 'text-ui)
	    (make-instance 'question
			   :text "You are in a dark room. There is a door to the north."
			   :choices (list (make-instance 'choice
							 :text "Go north"
							 :action (lambda ()
								   (setf *state*
									 (make-instance 'question
											:text "You are in a bright room. There is a door to the south."
											:choices (list (make-instance 'choice
														      :text "Go south"
														      :action (lambda ()
																(setf *state* nil))))))))
					  (make-instance 'choice
							 :text "Stay"
							 :action (lambda ()
								   (setf *state* nil)))))))
