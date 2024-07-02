(in-package :dunge)

(defvar *current-passage* nil)

(defvar *passages* (make-hash-table))


(defgeneric title (passage))
(defgeneric body (passage))
(defgeneric commands (passage))
(defgeneric do-command (command))
(defgeneric command-name (command))

;; (defmacro starting-passage (passage-name &rest args)
;;   `(set-passage ',passage-name ,@args))

;; (defmacro set-passage (passage-name &rest args)
;;   `(setf *current-passage* (funcall (gethash ',passage-name *passages*)
;; 				    ,@args)))

;;(defmacro title (str)
;;   `(setf *title* ,str))

;; (defmacro p (&rest args)
;;   `,@(loop for arg in args
;; 	   ))

;; (defmacro link)

;; (defmacro defpassage (name args &body body)
;;   `(setf (gethash ',name *passages*)
;; 	 (lambda (,@args)
;; 	   (let ((*title* "")
;; 		 (*body* ""))
;; 	     ,@body))))

(defclass basic-action ()
  ((func :reader func :initarg :func)
   (name :reader name :initarg :name)))

(defclass basic-passage ()
  ((title :reader title :initarg :title :initform nil)
   (body :reader body :initarg :body :initform nil)
   (commands :reader commands :initarg :commands :initform nil)))

(defun init-game ()
  (let ((welcome-passage (make-instance 'basic-passage
					:title "Welcome to Dunge!"
					:body "Dunge is an interactive dungeon crawler"
					:commands (make-instance 'basic-action
								 :name "Next passage"
								 :func (lambda ()
									 (setf *current-passage* next-passage))))))
    (setf *current-passage*
	  welcome-passage)))


(defun game-loop ()
  (format t "~a\n\n" (title *current-passage*))
  (format t "~a\n" (body *current-passage*))
  (let* ((command-map (loop for command in (commands *current-passage*)
			    for x from 1
			    do (format t "~d: ~a\n"
				       x
				       (command-name command))
			    collect (cons x command)))
	 (selected-command (cdr (assoc (read-line)
				       command-map :test #'equal))))
    (if selected-command
	(do-command selected-command)
	(format t "invalid command"))))
