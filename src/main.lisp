(uiop:define-package #:dunge
  (:use #:cl)
  (:shadow #:return #:eval)
  (:export ))

(in-package #:dunge)

(defparameter *scenes* (make-hash-table :test 'equal))

(eval-when (:compile-toplevel :load-toplevel :execute)

  (defmacro game (&body body)
    (macrolet ((scene (name &body body)
		   (macrolet ((finish ()
				`(go finish-scene)))
		     `(setf (gethash ,name *scenes*)
			    (lambda ()
			      (tagbody
				 ,@body
			       finish-scene
				 )))))
	       #+nil(finish (&body body)
		      `(progn))
	       (text (str)
		 `(format t "~A~%~%" ,str))
	       (choice (&body choices)
		 `(tagbody 
		     ,@(loop
			 for i from 1
			 for (choice-text . nil) in choices
			 collect `(format t "~A. ~A~%" ,i ,choice-text))
		   prompt
		     (format t "Enter choice: ")
		     (let* ((line (read-line))
			    (n (parse-integer line :junk-allowed t)))
		       (terpri)
		       (case n
			 ,@(loop for i from 1
				 for (nil . body) in choices
				 collect `(,i ,@body))
			 (t (format t "Invalid choice: ~A~%~%" n)
			  (go prompt))))))))
    `(let ((scene-name (catch 'goto-scene
			 ,@body
			 nil)))
       (when scene-name
	 (funcall (gethash scene-name *scenes*)))))

  )
  

  ;; scene (a block of text and choices)

  ;; var (declare a variable)

  ;; set (set a variable)

  ;; goto (jump to another scene)

  ;; gosub (jump to another scene and return)
  
  ;; title (title of the game)

  ;; comment (does not execute, just for documentation purposes)

  ;; page-break (press a button to continue)
  

;;; game objects
;; scene
;; text
;; choice


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
