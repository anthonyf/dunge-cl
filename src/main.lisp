(uiop:define-package #:dunge
  (:use #:cl)
  (:shadow #:return #:eval)
  (:export ))

(in-package #:dunge)


;; label (a label to goto or gosub)

;; scene (a block of text and choices)

;; var (declare a variable)

;; set (set a variable)

;; goto (jump to another scene)

;; gosub (jump to another scene and return)

;; title (title of the game)

;; https://sarabander.github.io/sicp/html/5_002e4.xhtml

(defun env-lookup (env var)
  (cond
    ((null env)
     (error "Unbound variable: ~A" var))
    ((eq var (caar env))
     (cdar env))
    (t
     (env-lookup (cdr env) var))))

(defun self-evaluating-p (expr)
  (or (numberp expr)
      (stringp expr)))

(defun variable-p (expr)
  (symbolp expr))

(defun assignment-p (expr)
  (and (listp expr)
       (eq (car expr) 'set)))

#+nil
(env-lookup '((x . 10) (y . 20)) 'x) ;; => 10

;; implement an explicit control evaluator
(defun evaluate (expr global-env)
  (let ((expr expr)
	(conts nil)
	(env global-env)
	(val nil) ;; result value
	)
    (push :ev-dispatch conts)
    (loop while conts
	  for cont = (pop conts)
	  do (case cont
	       (:ev-dispatch (cond
			       ((self-evaluating-p expr)
				(push :ev-self-eval conts)
				))
	       
			       )
	       (:ev-self-eval
		;; (assign val (reg exp))
		;; (goto (reg continue))
		(setf val expr)
		)))
    val))

(evaluate 4 nil)


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
    ))1


#+nil(defun run-game ()
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
