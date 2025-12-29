(uiop:define-package :dunge/dsl
  (:use #:cl)
  (:mix #:dunge/engine)
  (:export ))

(in-package :dunge/dsl)

(defclass scene ()
  ((name :initarg :name :accessor scene-name)
   (elements :initarg :elements :accessor scene-elements)))

(defgeneric render (element)
  (:documentation "Render a scene element."))

(defmethod render ((element string))
  (format t "~a~%" element))

(defmethod render ((element function))
  (funcall element))

(defparameter *choices* nil)

(defmethod perform ((scene scene))
  (let ((*choices* nil))
    (loop for element in (scene-elements scene)
	  do (render element))
    *choices*))

(defclass choice ()
  ((description :initarg :description :accessor choice-description)
   (action :initarg :action :accessor choice-action)))

(defmethod choice-text ((choice choice))
  (choice-description choice))

(defmethod render ((choice choice))
  (push choice *choices*))

(defmethod execute-choice ((choice choice))
  (funcall (choice-action choice)))

(defun test-game ()
  (let ((start-scene nil)
	(north-scene nil)
	(south-scene nil))
    (setf start-scene
	  (make-instance 'scene
			 :name 'start
			 :elements (list "You are in a dark room."
					 (make-instance 'choice
							:description "Go north."
							:action (lambda ()
								  (format t "You go north.~%")
								  (setf *current-scene* north-scene)))
					 (make-instance 'choice
							:description "Go south."
							:action (lambda ()
								  (format t "You go south.~%")
								  (setf *current-scene* south-scene))))))
    (setf north-scene
	  (make-instance 'scene :name 'north
				:elements (list "You are in a bright room."
						(make-instance 'choice
							       :description "Go back south."
							       :action (lambda ()
									 (format t "You go back south.~%")
									 (setf *current-scene* start-scene))))))
    (setf south-scene
	  (make-instance 'scene :name 'south
				:elements (list "You are in a gloomy cave."
						(make-instance 'choice
							       :description "Go back north."
							       :action (lambda ()
									 (format t "You go back north.~%")
									 (setf *current-scene* start-scene))))))
    (setf *current-scene* start-scene)
    (play-game start-scene)))


;; label (a label to goto or gosub)

;; scene (a block of text and choices)

;; var (declare a variable)

;; set (set a variable)

;; goto (jump to another scene)

;; gosub (jump to another scene and return)

;; title (title of the game)

;; https://sarabander.github.io/sicp/html/5_002e4.xhtml

;;; game objects
;; scene
;; text
;; choice


#+nil(defun counter-test ()
  (game
    (var count 0)
    (label start)
    (text "Count is now " count)
    (text "continue counting?")
    (choice ("yes"
	     (set count (+ count 1))
	     (goto start))
      ("no"
       (text "Final count is " count)))
    ))


(eval-when (:load-toplevel :compile-toplevel :execute)
  (defmacro game (&body body)
    `(make-instance 'scene
		    :name 'main
		    :elements (list ,@body)))
  
  (defmacro text (&rest args)
    `(lambda ()
       (format t ,(apply #'concatenate 'string (mapcar (lambda (x)
							 (if (stringp x)
							     x
							     "~a"))
						       args))
	       ,@(remove-if #'stringp args))))

  (defmacro choice (description &body body)
    `(progn
       (format t "~A~%" ,description)
       ,@(loop for item in body
	       collect  (let ((desc (car item))
			      (action-body (cdr item)))
			  `(make-instance 'choice
					  :description ,desc
					  :action (lambda ()
						    @,(loop for elem in action-body
							    collect `(render-element ,elem))))))))
  )


(defun run-game ()
  (game 
   (text "Your majesty, your people are starving in the streets, and threaten revolution.
Our enemies to the west are weak, but they threaten soon to invade.  What will you do?")

   (choice
     ("Make pre-emptive war on the western lands."
      (text "If you can seize their territory, your kingdom will flourish.  But your army's morale is low and the kingdom's armory is empty.  How will you win the war?")
      (choice
	("Drive the peasants like slaves"
	 ;; if we work hard enough, we'll win.
	 (text "Unfortunately, morale doesn't work like that.  Your army soon turns against you and the kingdom falls to the western barbarians.")
	 (finish))
	("Appoint charismatic knights and give them land, peasants, and resources."
	 (text "Your majesty's people are eminently resourceful.  Your knights win the day, but take care: they may soon demand a convention of parliament.")
	 (finish))
	("Steal food and weapons from the enemy in the dead of night."
	 (text "A cunning plan.  Soon your army is a match for the westerners; they choose not to invade for now, but how long can your majesty postpone the inevitable?")
	 (finish))))
     ("Beat swords to plowshares and trade food to the westerners for protection."
      (text "The westerners have you at the point of a sword.  They demand unfair terms from you.")
      (choice
	("Accept the terms for now."
	 (text "Eventually, the barbarian westerners conquer you anyway, destroying their bread basket, and the entire region starves.")
	 (finish))
	("Threaten to salt our fields if they don't offer better terms."
	 (text "They blink.  Your majesty gets a fair price for wheat.")
	 (finish))))
     ("Abdicate the throne. I have clearly mismanaged this kingdom!"
      (text "The kingdom descends into chaos, but you manage to escape with your own hide.  Perhaps in time you can return to restore order to this fair land.")
      (finish)))))
