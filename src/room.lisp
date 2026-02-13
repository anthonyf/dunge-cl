(uiop:define-package #:dunge/room
  (:use #:cl)
  (:shadow #:room)
  (:mix #:dunge/engine
	#:dunge/utils
	#:dunge/data-store
	#:dunge/text-layout)
  (:export #:room
	   #:room-id
	   #:make-room
	   #:exit
	   #:gate
	   #:p
	   #:prompt
	   #:room-local
	   #:local-ref))

(in-package #:dunge/room)

(defclass exit ()
  ((description :initarg :description
		:accessor exit-description)
   (choice-text :initarg :choice-text
		:accessor exit-choice-text)
   (room-id :initarg :room-id
	    :accessor exit-room-id)))

(defun exit (choice-text room-id &key description)
  (make-instance 'exit
		 :description description
		 :choice-text choice-text
		 :room-id room-id))

(defmethod perform (ctx (exit exit))
  (when (exit-description exit)
    (out ctx
	 (format nil "~a~%" (exit-description exit))))
  (let ((id (exit-room-id exit)))
    (list (make-instance 'choice
			 :label (exit-choice-text exit)
			 :action (lambda ()
				   (set-vignette (room id)))))))

(defclass p ()
  ((content :initarg :content :accessor p-content)))

(defun p (&rest content)
  (make-instance 'p :content content))

(defun resolve (item)
  (if (functionp item)
      (funcall item)
      item))

(defmethod perform (ctx (p p))
  (out ctx (format nil "~{~A~}~%" (mapcar #'resolve (p-content p))))
  nil)

(defclass room ()
  ((id :initarg :id
       :reader room-id)
   (title :initarg :title
	  :accessor room-title)
   (elements :initarg :elements
	     :accessor room-elements)
   (locals :accessor room-locals
	   :initform (make-hash-table :test 'equal))))

(defun room-local (key)
  (let ((room (current-vignette)))
    (when (typep room 'room)
      (gethash key (room-locals room)))))

(defun (setf room-local) (value key)
  (let ((room (current-vignette)))
    (when (typep room 'room)
      (if (null value)
	  (remhash key (room-locals room))
	  (setf (gethash key (room-locals room)) value))))
  value)

(defun local-ref (key)
  (lambda () (room-local key)))

(defmethod perform (ctx (room room))
  (out ctx
       (text (room-title room) (nl)))
  (loop for element in (room-elements room)
	for result = (perform ctx element)
	if (listp result) append result
	else return result))

(defclass gate ()
  ((condition :initarg :condition :accessor gate-condition)
   (then :initarg :then :accessor gate-then)
   (else :initarg :else :accessor gate-else :initform nil)))

(defun gate (condition &key then else)
  (make-instance 'gate
		 :condition condition
		 :then then
		 :else else))

(defmethod perform (ctx (gate gate))
  (let ((branch (if (funcall (gate-condition gate))
		    (gate-then gate)
		    (gate-else gate))))
    (loop for element in branch
	  for result = (perform ctx element)
	  if (listp result) append result
	  else return result)))

(defun resolve-validator (validator)
  (etypecase validator
    (keyword (ecase validator
	       (:non-empty-string #'validate-non-empty-string)))
    (function validator)))

(defun prompt (question &key validate store action goto)
  (let ((act action))
    (make-instance 'prompt
		   :question question
		   :validate-fn (resolve-validator validate)
		   :action (lambda (input)
			     (when store
			       (apply #'(setf lookup) input store))
			     (when act
			       (funcall act input))
			     (when goto
			       (set-vignette (room goto)))))))

(defun room (id)
  (lookup "rooms" id))

(defun (setf room) (room id)
  (setf (lookup "rooms" id) room))

(defun make-room (id title &rest elements)
  (setf (room id)
	(make-instance 'room
		       :id id
		       :title title
		       :elements elements)))
