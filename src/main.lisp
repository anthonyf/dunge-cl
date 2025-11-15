(uiop:define-package #:dunge
  (:use #:cl)
  (:shadow #:room)
  (:export #:main))

(in-package #:dunge)

(defgeneric description (thing))
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
	do (format t "~a~%" (description cmd))))

(defmethod read-command ((ui text-ui))
  (let ((input (read-line)))
    (find input (commands *state*) :key #'description :test #'string=)))


(defclass question ()
  ((description :accessor description :initarg :description)
   (choices :accessor choices :initarg :choices)))

(defmethod commands ((state question))
  (choices state))

(defclass choice ()
  ((description :accessor description :initarg :description)
   (action :accessor action :initarg :action)))

(defmethod execute ((command choice))
  (funcall (action command)))

(defun run-game (ui starting-state)
  (let ((*state* starting-state))
    (loop do (progn (print-text ui (description *state*))
		    (print-menu ui (commands *state*))
		    (execute (read-command ui)))
	  while *state*)))


(defclass room ()
  ((description :accessor description :initarg :description)))

(defclass pathway ()
  ((from :accessor from :initarg :from)
   (to :accessor to :initarg :to)
   (direction :accessor direction :initarg :direction)))

(defclass door (pathway)
  ((description :accessor description :initarg :description)
   (lockedp :accessor lockedp :initarg :lockedp :initform nil)
   (openp :accessor openp :initarg :openp :initform nil)))

(defvar *rooms* nil)



(defun main ()
  (run-game (make-instance 'text-ui)
	    (make-instance 'question
			   :description "You are in a dark room. There is a door to the north."
			   :choices (list (make-instance 'choice
							 :description "Go north"
							 :action (lambda ()
								   (setf *state*
									 (make-instance 'question
											:description "You are in a bright room. There is a door to the south."
											:choices (list (make-instance 'choice
														      :description "Go south"
														      :action (lambda ()
																(setf *state* nil))))))))
					  (make-instance 'choice
							 :description "Stay"
							 :action (lambda ()
								   (setf *state* nil)))))))
