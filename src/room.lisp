(uiop:define-package #:dunge/room
  (:use #:cl)
  (:shadow #:room)
  (:mix #:dunge/engine
	#:dunge/data-store
	#:dunge/text-layout)
  (:export #:room
	   #:make-room
	   #:exit))

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
   (interactibles :initarg :interactibles
		  :accessor room-interactibles)))

(defmethod perform (ctx (room room))
  (out ctx
       (text (room-title room) (nl)
	     (room-description room) (nl)))
  (loop for interactible in (room-interactibles room)
	append (perform ctx interactible)))

(defun room (id)
  (lookup "rooms" id))

(defun (setf room) (room id)
  (setf (lookup "rooms" id) room))

(defun make-room (id title description &key interactibles)
  (setf (room id)
	(make-instance 'room
		       :title title
		       :description description
		       :interactibles interactibles)))
