(uiop:define-package :dunge/dsl
  (:use #:cl)
  (:mix #:dunge/engine)
  (:export ))

(in-package :dunge/dsl)

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
    `(play-game (make-instance 'scene
			       :name 'main
			       :elements (list ,@body))))

  (defmacro )
  
  (defmacro text (&rest args)
    `(lambda ()
       (format t ,(apply #'concatenate 'string (mapcar (lambda (x)
							 (if (stringp x)
							     x
							     "~a"))
						       args))
	       ,@(remove-if #'stringp args))))

  (defmacro choice (&body body)
    `(progn
       ,@(loop for (desc . action-body) in body
	       collect (let ()
			 `(make-instance 'choice
					 :description ,desc
					 :action (lambda ()
						   ,@action-body
						   #+nil,@(loop for elem in action-body
							   collect `(render ,elem))))))))
  (defmacro finish ()
    `(throw 'finish-scene nil))
  )


