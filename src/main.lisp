(in-package :dunge)

(defparameter *passages* (make-hash-table :test 'equal))
(defparameter *data* (make-hash-table))
(defparameter *commands* (make-hash-table :test 'equal))
(defparameter *quit-p* nil)

(eval-when (:compile-toplevel :load-toplevel)
  (defmacro do (&body body)
    `(progn ,@body))

  (defmacro defpassage (passage-name &body body)
    `(setf (gethash ,passage-name ,*passages*)
	   #'(lambda () ,@body)))

  (defmacro set (var-name value)
    `(setf (gethash ',var-name ,*data*) ,value))
  
  )

(defun p (&rest args)
  (loop :for arg :in args
	:do (princ arg)
	:finally (terpri)))


(defun link (passage &optional link-text)
  (let ((text (or link-text passage)))
   (p text)
   (setf (gethash text *commands*) passage)))

(defun quit (message)
  (p message)
  (setf *quit-p* t))



(defun dunge-compile-ps-file (&key input output)
  (let ((outpath (or output (uiop:make-pathname* :defaults input :type "html"))))
    (uiop:with-enough-pathname (enough-outpath :pathname outpath)
      (with-open-file (ps:*parenscript-stream* enough-outpath :direction :output :if-exists :supersede)
	(ps:ps-compile-file input)))))

(defun main ()
  
  )
