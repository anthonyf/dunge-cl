
(in-package #:dunge)

;;; generics

(defgeneric evaluate (ctx thing))

(defvar *rooms* (make-hash-table :test 'equal))

(defclass room ()
  ((name :reader name :initarg :name :initform nil))
   (entities :accessor entities :initform nil :initarg :entities))

(defmethod initialize-instance :after ((room room) &key)
  (setf (gethash (name room) *rooms*) room))

(defclass choice ()
  ((label :accessor label :initarg :label :initform nil)
   (target :accessor target :initarg :target :initform nil)))

(defclass choices ()
  ((options :accessor options :initarg :options :initform nil)))


(defun evaluate (thing)
  )

