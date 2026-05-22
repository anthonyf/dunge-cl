(in-package #:dunge-tests)

(def-suite :dunge-tests)
(in-suite :dunge-tests)

(defun build-state-fixture ()
  (let* ((door (entity "secret door"
		 :id "door"
		 :state ((open nil))))
	 (panel (entity "panel"
		  :id "panel"
		  :state ((switch :off)
			  (count 0))
		  :refs ((door "door"))))
	 (game (game (room "room" door panel))))
    (values game door panel)))

(defun state-value (reference)
  (dunge::state-reference-value reference))

(defun contains-substring-p (needle haystack)
  (not (null (search needle haystack :test #'char=))))

(defun run-example-with-input (function input)
  (with-output-to-string (output)
    (let ((*input* (make-string-input-stream input))
	  (*output* output))
      (funcall function))))

(test state-effects-update-global-self-and-refs
  (multiple-value-bind (game door panel) (build-state-fixture)
    (let ((dunge::*game* game)
	  (dunge::*self* panel))
      (execute-effect (gain :recipe))
      (is (eq t (state-value (state-ref :global :recipe))))

      (execute-effect (lose :recipe))
      (is (not (state-value (state-ref :global :recipe))))

      (execute-effect (state-set :self :switch :on))
      (is (eq :on (state-value (state-ref :self :switch))))

      (execute-effect (toggle :self :switch))
      (is (eq :off (state-value (state-ref :self :switch))))

      (execute-effect (state-inc :self :count 3))
      (is (= 3 (state-value (state-ref :self :count))))

      (execute-effect (state-dec :self :count 1))
      (is (= 2 (state-value (state-ref :self :count))))

      (execute-effect (state-set :ref :door :open t))
      (let ((dunge::*self* door))
	(is (eq t (state-value (state-ref :self :open)))))

      (execute-effect (state-clear :self :switch))
      (is (not (state-value (state-ref :self :switch)))))))

(test condition-operators-read-state
  (multiple-value-bind (game door panel) (build-state-fixture)
    (declare (ignore door))
    (let ((dunge::*game* game)
	  (dunge::*self* panel))
      (execute-effect (gain :recipe))
      (is (evaluate-condition (have? :recipe)))
      (is (evaluate-condition (condition-eq (state-ref :self :switch) :off)))
      (is (not (evaluate-condition (condition-not (have? :recipe)))))
      (is (evaluate-condition
	   (condition-and (have? :recipe)
			  (condition-eq (state-ref :self :switch) :off))))
      (is (evaluate-condition
	   (condition-or (condition-eq (state-ref :self :switch) :on)
			 (condition-eq (state-ref :self :switch) :off)))))))

(test branch-selects-active-children
  (let ((game (game (room "room")))
	(node (branch (have? :recipe)
		:then ((p "You know the recipe."))
		:else ((p "You are missing the recipe.")))))
    (let ((without-recipe
	    (with-output-to-string (output)
	      (let ((dunge::*game* game)
		    (*output* output))
		(describe-entity node)))))
      (is (contains-substring-p "missing the recipe" without-recipe)))
    (let ((dunge::*game* game))
      (execute-effect (gain :recipe)))
    (let ((with-recipe
	    (with-output-to-string (output)
	      (let ((dunge::*game* game)
		    (*output* output))
		(describe-entity node)))))
      (is (contains-substring-p "know the recipe" with-recipe)))))

(test once-and-conditional-choices
  (let* ((game (game
		(room "room"
		  (choice
		    ("Take the recipe" (quit)
		     :id :take-recipe
		     :once t
		     :when (have? :recipe))))))
	 (choice-node (first (entities (first (game-rooms game)))))
	 (take-recipe (first (options choice-node))))
    (let ((dunge::*game* game))
      (is (not (dunge::choice-visible-p take-recipe)))
      (execute-effect (gain :recipe))
      (is (dunge::choice-visible-p take-recipe))
      (dunge::mark-choice-taken take-recipe)
      (is (not (dunge::choice-visible-p take-recipe))))))

(test validator-catches-authoring-errors
  (signals error
    (game (room "start"
	    (choice
	      ("Missing room" (goto "missing"))))))
  (signals error
    (game (room "start"
	    (choice
	      ("Once without id" (quit)
	       :once t)))))
  (signals error
    (game (room "start")
	  (room "start")))
  (signals error
    (game (room "start"
	    (entity "panel"
	      :refs ((door "missing-door")))))))

(test basic-example-scripted-transcript
  (let ((output (run-example-with-input #'dunge-examples:basic-example
					(format nil "2~%"))))
    (is (contains-substring-p "You stand at the entrance" output))
    (is (contains-substring-p "Leave" output))))

(test control-panel-scripted-transcript
  (let ((output (run-example-with-input #'dunge-examples:control-panel-example
					(format nil "1~%2~%1~%2~%"))))
    (is (contains-substring-p "You flip the switch." output))
    (is (contains-substring-p "Something heavy slides open nearby." output))
    (is (contains-substring-p "hidden room" output))))
