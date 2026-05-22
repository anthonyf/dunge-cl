(in-package #:dunge-tests)

(def-suite :dunge-tests)
(in-suite :dunge-tests)

(defun build-state-fixture ()
  (let* ((door (entity "secret door"
                 :id "door"
                 :state ((:open nil))))
         (panel (entity "panel"
                  :id "panel"
                  :state ((:switch :off)
                          (:count 0))
                  :refs ((:door "door"))))
         (game (game (room "room" door panel))))
    (values game door panel)))

(defun test-context (game &key scene self)
  (make-runtime-context
   :game game
   :scene scene
   :self self))

(defun state-value (reference context)
  (dunge::state-reference-value reference context))

(defun contains-substring-p (needle haystack)
  (not (null (search needle haystack :test #'char=))))

(defun substring-count (needle haystack)
  (when (string= needle "")
    (error "Cannot count occurrences of an empty substring."))
  (loop with start = 0
        for position = (search needle haystack :start2 start :test #'char=)
        while position
        count 1
        do (setf start (+ position (length needle)))))

(defun run-game-with-input (game input)
  (with-output-to-string (output)
    (let ((*input* (make-string-input-stream input))
          (*output* output))
      (evaluate game))))

(defun run-example-with-input (function input)
  (with-output-to-string (output)
    (let ((*input* (make-string-input-stream input))
          (*output* output))
      (funcall function))))

(test substring-count-rejects-empty-needle
  (signals error
    (substring-count "" "anything")))

(test state-effects-update-global-self-and-refs
  (multiple-value-bind (game door panel) (build-state-fixture)
    (let ((context (test-context game :self panel)))
      (execute-effect (gain :recipe) context)
      (is (eq t (state-value (state-ref :global :recipe) context)))

      (execute-effect (lose :recipe) context)
      (is (not (state-value (state-ref :global :recipe) context)))

      (execute-effect (state-set :self :switch :on) context)
      (is (eq :on (state-value (state-ref :self :switch) context)))

      (execute-effect (toggle :self :switch) context)
      (is (eq :off (state-value (state-ref :self :switch) context)))

      (execute-effect (state-inc :self :count 3) context)
      (is (= 3 (state-value (state-ref :self :count) context)))

      (execute-effect (state-dec :self :count 1) context)
      (is (= 2 (state-value (state-ref :self :count) context)))

      (execute-effect (state-set :ref :door :open t) context)
      (let ((door-context (test-context game :self door)))
        (is (eq t (state-value (state-ref :self :open) door-context))))

      (execute-effect (state-clear :self :switch) context)
      (is (not (state-value (state-ref :self :switch) context))))))

(test condition-operators-read-state
  (multiple-value-bind (game door panel) (build-state-fixture)
    (declare (ignore door))
    (let ((context (test-context game :self panel)))
      (execute-effect (gain :recipe) context)
      (is (evaluate-condition (have? :recipe) context))
      (is (evaluate-condition (condition-eq (state-ref :self :switch) :off)
                              context))
      (is (not (evaluate-condition (condition-not (have? :recipe))
                                   context)))
      (is (evaluate-condition
           (condition-and (have? :recipe)
                          (condition-eq (state-ref :self :switch) :off))
           context))
      (is (evaluate-condition
           (condition-or (condition-eq (state-ref :self :switch) :on)
                         (condition-eq (state-ref :self :switch) :off))
           context)))))

(test branch-selects-active-children
  (let ((game (game (room "room")))
        (node (branch (have? :recipe)
                :then ((p "You know the recipe."))
                :else ((p "You are missing the recipe.")))))
    (let ((without-recipe
            (with-output-to-string (output)
              (let ((*output* output))
                (describe-entity node (test-context game))))))
      (is (contains-substring-p "missing the recipe" without-recipe)))
    (execute-effect (gain :recipe) (test-context game))
    (let ((with-recipe
            (with-output-to-string (output)
              (let ((*output* output))
                (describe-entity node (test-context game))))))
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
    (let ((context (test-context game)))
      (is (not (dunge::choice-visible-p take-recipe context)))
      (execute-effect (gain :recipe) context)
      (is (dunge::choice-visible-p take-recipe context))
      (dunge::mark-choice-taken take-recipe context)
      (is (not (dunge::choice-visible-p take-recipe context))))))

(test actions-store-and-use-entity-owners
  (let* ((panel (entity "panel"
                  :state ((:switch :off))
                  (action "Flip"
                    (state-set :self :switch :on))))
         (game (game (room "room" panel)))
         (action-node (first (entities panel)))
         (context (test-context game)))
    (is (eq panel (dunge::action-owner action-node)))
    (let ((choice (first (collect-choices action-node context))))
      (is (eq action-node (target choice)))
      (evaluate (target choice) context)
      (is (eq :on (state-value (state-ref :self :switch)
                               (test-context game :self panel)))))))

(test nested-actions-keep-containing-entity-owner
  (let* ((panel (entity "panel"
                  :state ((:switch :off))
                  (branch t
                    :then ((action "Flip"
                             (state-set :self :switch :on))))))
         (game (game (room "room" panel)))
         (choice (first (collect-choices panel (test-context game))))
         (action-node (target choice)))
    (is (eq panel (dunge::action-owner action-node)))
    (evaluate action-node (test-context game))
    (is (eq :on (state-value (state-ref :self :switch)
                             (test-context game :self panel))))))

(test action-validation-is-structural
  (let* ((panel (entity "panel"
                  (action "Flip"
                    (gain :x))))
         (unprepared-game (make-instance 'game
                                         :rooms (list (room "room" panel)))))
    (is (null (dunge::action-owner (first (entities panel)))))
    (is (eq unprepared-game (validate-game unprepared-game)))))

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
              :refs ((:door "missing-door"))))))
  (signals error
    (game (room "start"
            (entity "panel"
              (action "Bad list effect"
                (conditional-effect t
                                    (list (gain :x))))))))
  (signals error
    (game (room "start"
            (action "Loose action"
              (gain :x))))))

(test validator-catches-duplicate-ids-and-malformed-state-refs
  (signals error
    (game (room "start"
            (choice
              ("First" (quit)
               :id :same)
              ("Second" (quit)
               :id :same)))))
  (signals error
    (game (room "start"
            (entity "first"
              :id "same")
            (entity "second"
              :id "same"))))
  (signals error
    (game (room "start"
            (entity "panel"
              (action "Bad ref"
                (make-instance 'state-set
                               :target (make-instance 'state-ref
                                                      :scope :global
                                                      :key "recipe")
                               :value t)))))))

(test deprecated-key-shapes-are-rejected
  (signals error
    (game (room "room"
            (entity "panel"
              :state ((switch :off))))))
  (signals error
    (game (room "room"
            (entity "door"
              :id "door")
            (entity "panel"
              :refs ((door "door"))))))
  (signals error
    (game (room "room"
            (entity "door"
              :id :door))))
  (signals error
    (game (room "room"
            (entity "door"
              :id "door")
            (entity "panel"
              :refs ((:door :door))))))
  (signals error
    (game (room "room"
            (choice
              ("Take" (quit)
               :id "take"
               :once t)))))
  (signals error
    (state-ref :self "switch"))
  (signals error
    (state-ref 'self :switch)))

(test effect-lists-error-and-empty-else-branches-are-safe
  (signals error
    (execute-effect (list (gain :x))))
  (is (null (execute-effect
             (conditional-effect nil
                                 (gain :x)
                                 nil))))
  (is (null (execute-effect
             (make-instance 'conditional-effect
                            :condition nil
                            :then (gain :x)
                            :else nil)))))

(test sequence-stops-after-first-control-result
  (let* ((game (game (room "start")
                     (room "next")))
         (context (test-context game))
         (result (execute-effect
                  (sequence
                    (gain :before-control)
                    (goto "next")
                    (gain :after-control))
                  context)))
    (is (typep result 'goto))
    (is (equal "next" (room-name result)))
    (is (state-value (state-ref :global :before-control) context))
    (is (not (state-value (state-ref :global :after-control) context)))))

(test once-choice-disappears-in-scripted-game
  (let* ((game (game
                (room "room"
                  (choice
                    ("Take key" (sequence
                                  (gain :key)
                                  (dunge::refresh))
                     :id :take-key
                     :once t)
                    ("Leave" (quit))))))
         (output (run-game-with-input game (format nil "1~%1~%"))))
    (is (= 1 (substring-count "Take key" output)))
    (is (= 2 (substring-count "Leave" output)))))

(test gosub-and-back-return-to-calling-room
  (let* ((game
           (game
            (room "start"
              (p "The start chamber waits.")
              (choice
                ("Visit alcove" (gosub "alcove"))
                ("Leave" (quit))))
            (room "alcove"
              (p "The alcove hums.")
              (choice
                ("Back" (back))))))
         (output (run-game-with-input game (format nil "1~%1~%2~%"))))
    (is (= 2 (substring-count "The start chamber waits." output)))
    (is (= 1 (substring-count "The alcove hums." output)))))

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
