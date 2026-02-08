(uiop:define-package #:dunge/room
  (:use #:cl)
  (:shadow #:room)
  (:mix #:dunge/engine
	#:dunge/data-store
	#:dunge/text-layout)
  (:export #:room
	   #:make-room
	   #:exit
	   #:gate))

(in-package #:dunge/room)

(defclass exit ()
  ((description :initarg :description
		:accessor exit-description)
   (choice-text :initarg :choice-text
		:accessor exit-choice-text)
   (target-vignette :initarg :target-vignette
		    :accessor exit-target-vignette)))

(defun exit (choice-text target &key description)
  (make-instance 'exit
		 :description description
		 :choice-text choice-text
		 :target-vignette target))

(defmethod perform (ctx (exit exit))
  (when (exit-description exit)
    (out ctx
	 (text (exit-description exit) (nl))))
  (list (goto-choice (exit-choice-text exit)
		     (exit-target-vignette exit))))

(defclass room ()
  ((title :initarg :title
	  :accessor room-title)
   (description :initarg :description
		:accessor room-description)
   (elements :initarg :elements
		  :accessor room-elements)))

(defmethod perform (ctx (room room))
  (out ctx
       (text (room-title room) (nl)
	     (room-description room) (nl)))
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

(defun room (id)
  (lookup "rooms" id))

(defun (setf room) (room id)
  (setf (lookup "rooms" id) room))

(defun make-room (id title description &key elements)
  (setf (room id)
	(make-instance 'room
		       :title title
		       :description description
		       :elements elements)))
