(in-package #:dunge-tests)

(def-suite :dunge-tests)
(in-suite :dunge-tests)

(dunge::define-dunge-node sample-ast-node ()
  ((id :reader sample-ast-node-id :initarg :id :initform nil)
   (children :reader sample-ast-node-children :initarg :children :initform nil))
  (:id (thing) (sample-ast-node-id thing))
  (:children (thing) (sample-ast-node-children thing))
  (:source :sample
   (:fields
    (:id :string :required t)
    (:children :node-list :default nil))))

(defun source-node (form)
  (compile-dunge-source form))

(defun source-state (scope key &key role)
  (source-node
   (append (list :state :scope scope)
           (when role
             (list :role role))
           (list :key key))))

(defun source-game-with-body (&rest body)
  (source-node
   `(:game
     :start "room"
     :rooms
     ((:room :id "room" :body ,body)))))

(defun build-state-fixture ()
  (let* ((game
           (source-game-with-body
            '(:entity
              :name "secret door"
              :id "door"
              :state ((:open nil)))
            '(:entity
              :name "panel"
              :id "panel"
              :state ((:switch :off)
                      (:count 0))
              :refs ((:door "door")))))
         (room (first (game-rooms game)))
         (door (first (entities room)))
         (panel (second (entities room))))
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

(defun run-session-script (session input)
  (let (result)
    (values
     (with-output-to-string (output)
       (let ((*input* (make-string-input-stream input))
             (*output* output))
         (setf result (evaluate-session session))))
     result)))

(defun run-example-with-input (function input)
  (with-output-to-string (output)
    (let ((*input* (make-string-input-stream input))
          (*output* output))
      (funcall function))))

(defun error-message-from (thunk)
  (handler-case
      (progn
        (funcall thunk)
        nil)
    (error (condition)
      (princ-to-string condition))))

(defun write-test-file (path contents)
  (ensure-directories-exist path)
  (with-open-file (stream path
                          :direction :output
                          :if-exists :supersede
                          :if-does-not-exist :create)
    (write-string contents stream)))

(test substring-count-rejects-empty-needle
  (signals error
    (substring-count "" "anything")))

(test define-dunge-node-registers-source-schema-and-traversal
  (let* ((root (source-node
                '(:sample
                  :id "root"
                  :children
                  ((:sample :id "leaf")))))
         (leaf (first (node-children root)))
         (visited nil))
    (is (typep root 'sample-ast-node))
    (is (equal "root" (sample-ast-node-id root)))
    (is (equal "root" (node-id root)))
    (is (equal "leaf" (node-id leaf)))
    (walk-node-tree
     root
     (lambda (node)
       (push (node-id node) visited)))
    (is (equal '("root" "leaf") (nreverse visited)))))

(test define-dunge-node-rejects-unknown-options
  (signals error
    (macroexpand-1
     '(dunge::define-dunge-node invalid-sample-ast-node ()
       ()
       (:unknown-option t)))))

(test source-schema-rejects-malformed-input
  (signals error
    (source-node '(:missing :x t)))
  (signals error
    (source-node '(:p :text "ok" :extra t)))
  (signals error
    (source-node '(:p)))
  (signals error
    (source-node '(:p :text "one" :text "two")))
  (signals error
    (source-node '(:p :text 42)))
  (signals error
    (load-dunge-string "#.(error \"read eval leaked\")"))
  (is (contains-substring-p
       "Room entries must be room source forms or string file paths"
       (error-message-from
        (lambda ()
          (load-dunge-string
           "(:game :start \"start\" :rooms (#P\"rooms/start.dunge\"))")))))
  (let ((*readtable* (copy-readtable nil)))
    (set-macro-character
     #\(
     (lambda (stream char)
       (declare (ignore stream char))
       (error "custom readtable leaked")))
    (is (typep (load-dunge-string "(:p :text \"ok\")") 'p))))

(test source-diagnostics-include-form-and-field-context
  (let ((message
          (error-message-from
           (lambda ()
             (load-dunge-string
              "(:game :start \"start\" :rooms ((:room :id \"start\" :body ((:p :text 42)))))"
              :source-name "diagnostics.dunge")))))
    (is (contains-substring-p "Dunge source error in diagnostics.dunge"
                              message))
    (is (contains-substring-p
         "while compiling :GAME -> field :ROOMS -> :ROOM -> field :BODY -> :P -> field :TEXT"
         message))
    (is (contains-substring-p "Expected a string, got 42" message))))

(test source-diagnostics-include-referenced-room-file
  (let* ((root (merge-pathnames
                (format nil "dunge-source-diagnostics-test-~A/" (gensym))
                (uiop:temporary-directory)))
         (manifest (merge-pathnames "game.dunge" root))
         (start-room (merge-pathnames "rooms/start.dunge" root)))
    (unwind-protect
         (progn
           (write-test-file
            start-room
            "(:room :id \"start\" :body ((:choice :options ((:option :do (:quit))))))")
           (write-test-file
            manifest
            "(:game :start \"start\" :rooms (\"rooms/start.dunge\"))")
           (let ((message (error-message-from
                           (lambda ()
                             (load-dunge-file manifest)))))
             (is (contains-substring-p
                  (format nil "Dunge source error in ~A"
                          (namestring (truename start-room)))
                  message))
             (is (contains-substring-p
                  "while compiling :ROOM -> field :BODY -> :CHOICE -> field :OPTIONS -> :OPTION -> field :LABEL"
                  message))
             (is (contains-substring-p ":OPTION requires field :LABEL"
                                       message))
             (is (contains-substring-p
                  (format nil "included from ~A"
                          (namestring (truename manifest)))
                  message))
             (is (contains-substring-p
                  "while compiling :GAME -> field :ROOMS"
                  message))))
      (when (probe-file root)
        (uiop:delete-directory-tree root :validate t)))))

(test game-manifest-loads-relative-room-files
  (let* ((root (merge-pathnames
                (format nil "dunge-manifest-test-~A/" (gensym))
                (uiop:temporary-directory)))
         (manifest (merge-pathnames "game.dunge" root))
         (start-room (merge-pathnames "rooms/start.dunge" root))
         (end-room (merge-pathnames "rooms/end.dunge" root)))
    (unwind-protect
         (progn
           (write-test-file
            start-room
            "(:room :id \"start\" :title \"Start\" :body ((:p :text \"Start.\")))")
           (write-test-file
            end-room
            "(:room :id \"end\" :title \"End\" :body ((:p :text \"End.\")))")
           (write-test-file
            manifest
            "(:game :start \"start\" :rooms (\"rooms/start.dunge\" \"rooms/end.dunge\"))")
           (let ((game (load-dunge-file manifest)))
             (is (equal "start" (game-start game)))
             (is (equal '("start" "end")
                        (mapcar #'name (game-rooms game))))))
      (when (probe-file root)
        (uiop:delete-directory-tree root :validate t)))))

(test game-manifest-string-loads-relative-room-files
  (let* ((root (merge-pathnames
                (format nil "dunge-string-manifest-test-~A/" (gensym))
                (uiop:temporary-directory)))
         (start-room (merge-pathnames "rooms/start.dunge" root))
         (end-room (merge-pathnames "rooms/end.dunge" root)))
    (unwind-protect
         (progn
           (write-test-file
            start-room
            "(:room :id \"start\" :title \"Start\" :body ((:p :text \"Start.\")))")
           (write-test-file
            end-room
            "(:room :id \"end\" :title \"End\" :body ((:p :text \"End.\")))")
           (let ((game (load-dunge-string
                        "(:game :start \"start\" :rooms (\"rooms/start.dunge\" \"rooms/end.dunge\"))"
                        :source-name "game.dunge"
                        :base-directory root)))
             (is (equal "start" (game-start game)))
             (is (equal '("start" "end")
                        (mapcar #'name (game-rooms game))))))
      (when (probe-file root)
        (uiop:delete-directory-tree root :validate t)))))

(test source-schema-rejects-malformed-state-and-refs
  (is (contains-substring-p
       "State declaration must be"
       (error-message-from
        (lambda ()
          (source-node
           '(:entity :name "panel" :state (:open nil)))))))
  (is (contains-substring-p
       "State declaration must be"
       (error-message-from
        (lambda ()
          (source-node
           '(:entity :name "panel" :state ((:open nil :extra))))))))
  (is (contains-substring-p
       "Entity ref must be"
       (error-message-from
        (lambda ()
          (source-node
           '(:entity :name "panel" :refs (:door "door")))))))
  (is (contains-substring-p
       "Entity ref must be"
       (error-message-from
        (lambda ()
          (source-node
           '(:entity :name "panel" :refs ((:door "door" "extra")))))))))

(test generated-nodes-expose-traversal-methods
  (let* ((game (source-node
                '(:game
                  :start "room"
                  :rooms
                  ((:room
                    :id "room"
                    :body
                    ((:entity :name "door" :id "door")
                     (:entity :name "panel")
                     (:container
                      :name "box"
                      :contents
                      ((:item :name "key")
                       (:item :name "coin")))))))))
         (room (first (game-rooms game)))
         (door (first (entities room)))
         (panel (second (entities room)))
         (container-node (third (entities room))))
    (is (equal (list room) (node-children game)))
    (is (equal (list door panel container-node) (node-children room)))
    (is (equal "door" (node-id door)))
    (is (= 2 (length (node-children container-node))))))

(test state-effects-update-global-self-and-refs
  (multiple-value-bind (game door panel) (build-state-fixture)
    (let ((context (test-context game :self panel)))
      (execute-effect
       (source-node
        '(:set
          :target (:state :scope :global :key :recipe)
          :value t))
       context)
      (is (eq t (state-value (source-state :global :recipe) context)))

      (execute-effect
       (source-node '(:clear :target (:state :scope :global :key :recipe)))
       context)
      (is (not (state-value (source-state :global :recipe) context)))

      (execute-effect
       (source-node
        '(:set
          :target (:state :scope :self :key :switch)
          :value :on))
       context)
      (is (eq :on (state-value (source-state :self :switch) context)))

      (execute-effect
       (source-node '(:toggle :target (:state :scope :self :key :switch)))
       context)
      (is (eq :off (state-value (source-state :self :switch) context)))

      (execute-effect
       (source-node
        '(:inc
          :target (:state :scope :self :key :count)
          :amount 3))
       context)
      (is (= 3 (state-value (source-state :self :count) context)))

      (execute-effect
       (source-node
        '(:dec
          :target (:state :scope :self :key :count)
          :amount 1))
       context)
      (is (= 2 (state-value (source-state :self :count) context)))

      (execute-effect
       (source-node
        '(:set
          :target (:state :scope :ref :role :door :key :open)
          :value t))
       context)
      (let ((door-context (test-context game :self door)))
        (is (eq t (state-value (source-state :self :open) door-context))))

      (execute-effect
       (source-node '(:clear :target (:state :scope :self :key :switch)))
       context)
      (is (not (state-value (source-state :self :switch) context))))))

(test declared-entity-state-is-strict
  (multiple-value-bind (game door panel) (build-state-fixture)
    (let ((context (test-context game :self panel)))
      (is (contains-substring-p
           "has no declared state key :UNDECLARED-KEY"
           (error-message-from
            (lambda ()
              (execute-effect
               (source-node
                '(:toggle
                  :target (:state :scope :self :key :undeclared-key)))
               context)))))
      (signals error
        (execute-effect
         (source-node
          '(:set
            :target (:state :scope :self :key :undeclared-key)
            :value 42))
         context))
      (signals error
        (state-value (source-state :self :undeclared-key) context))
      (signals error
        (state-value (source-state :ref :switch :role :door) context))

      (execute-effect
       (source-node
        '(:set
          :target (:state :scope :self :key :switch)
          :value t))
       context)
      (signals error
        (execute-effect
         (source-node '(:toggle :target (:state :scope :self :key :switch)))
         context))

      (let ((door-context (test-context game :self door)))
        (execute-effect
         (source-node
          '(:set
            :target (:state :scope :self :key :open)
            :value :on))
         door-context)
        (signals error
          (execute-effect
           (source-node '(:toggle :target (:state :scope :self :key :open)))
           door-context))))))

(test declared-global-state-is-strict-when-present
  (let ((game
          (source-game-with-body
           '(:choice
             :options
             ((:option
               :label "Set declared"
               :do (:set
                    :target (:state :scope :global :key :known)
                    :value t)))))))
    (is (not (dunge::global-state-declared-p game))))
  (let ((game
          (source-node
           '(:game
             :start "room"
             :state ((:known nil))
             :rooms
             ((:room
               :id "room"
               :body
               ((:choice
                 :options
                 ((:option
                   :label "Set declared"
                   :do (:set
                        :target (:state :scope :global :key :known)
                        :value t)))))))))))
    (is (equal '(:known) (dunge::declared-global-state-keys game)))
    (is (not (state-value (source-state :global :known)
                          (test-context game)))))
  (is (contains-substring-p
       "undeclared key :MISSING"
       (error-message-from
        (lambda ()
          (source-node
           '(:game
             :start "room"
             :state ((:known nil))
             :rooms
             ((:room
               :id "room"
               :body
               ((:choice
                 :options
                 ((:option
                   :label "Set undeclared"
                   :do (:set
                        :target (:state :scope :global :key :missing)
                        :value t)))))))))))))
  (is (contains-substring-p
       "declares state key :KNOWN more than once"
       (error-message-from
        (lambda ()
          (source-node
           '(:game
             :start "room"
             :state ((:known nil) (:known t))
             :rooms
             ((:room :id "room")))))))))

(defun build-save-load-fixture ()
  (source-node
   '(:game
     :start "start"
     :state ((:clue nil)
             (:visits 0))
     :rooms
     ((:room
       :id "start"
       :title "Start"
       :body
       ((:entity
         :name "panel"
         :id "panel"
         :state ((:open nil))
         :body
         ((:action
           :label "Open panel"
           :do
           ((:set
             :target (:state :scope :self :key :open)
             :value t)))))
        (:choice
         :options
         ((:option
           :label "Find clue"
           :id :find-clue
           :once t
           :do (:sequence
                :effects
                ((:set
                  :target (:state :scope :global :key :clue)
                  :value t)
                 (:inc
                  :target (:state :scope :global :key :visits)))))
          (:option
           :label "Go to notes"
           :do (:goto :room "notes"))
          (:option
           :label "Quit"
           :do (:quit))))))
      (:room
       :id "notes"
       :title "Notes"
       :body
       ((:p :text "The notes are organized.")))))))

(test runtime-state-captures-and-restores-current-room-state-and-taken-choices
  (let* ((game (build-save-load-fixture))
         (session (make-runtime-session game)))
    (multiple-value-bind (output result)
        (run-session-script session (format nil "2~%1~%2~%"))
      (is (typep result 'room))
      (is (contains-substring-p "The notes are organized." output)))
    (let ((state (capture-runtime-state session)))
      (is (equal "notes" (getf state :current-room)))
      (is (equal '(:find-clue) (getf state :taken-choices)))
      (is (equal '((:clue . t) (:visits . 1))
                 (getf state :globals)))
      (let* ((fresh-game (build-save-load-fixture))
             (restored-session (restore-runtime-state fresh-game state))
             (restored-context (test-context fresh-game))
             (start-room (first (game-rooms fresh-game)))
             (panel (gethash "panel" (dunge::scene-index start-room))))
        (is (equal "notes"
                   (runtime-session-current-room-name restored-session)))
        (is (state-value (source-state :global :clue)
                         restored-context))
        (is (= 1 (state-value (source-state :global :visits)
                              restored-context)))
        (is (state-value (source-state :self :open)
                         (test-context fresh-game :self panel)))
        (is (dunge::choice-taken-p
             (first
              (options
               (second (entities start-room))))
             restored-context))))))

(test runtime-state-round-trips-through-safe-file-reader
  (let* ((game (build-save-load-fixture))
         (session (make-runtime-session game))
         (path (merge-pathnames
                (format nil "dunge-runtime-state-~A.sexp" (gensym))
                (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (run-session-script session (format nil "2~%1~%2~%"))
           (write-runtime-state-file session path)
           (let* ((fresh-game (build-save-load-fixture))
                  (loaded-session (load-runtime-state-file fresh-game path)))
             (is (equal "notes"
                        (runtime-session-current-room-name loaded-session)))
             (is (state-value (source-state :global :clue)
                              (test-context fresh-game)))))
      (when (probe-file path)
        (delete-file path)))))

(test runtime-state-validation-rejects-malformed-session-input
  (let ((game (build-save-load-fixture)))
    (is (contains-substring-p
         "return stack must be a proper list"
         (error-message-from
          (lambda ()
            (make-runtime-session game :return-stack "start")))))
    (is (contains-substring-p
         "return stack entry must be a room id string"
         (error-message-from
          (lambda ()
            (make-runtime-session game :return-stack '(42))))))
    (let ((state (list :current-room "start" :globals nil)))
      (setf (cddr state) state)
      (is (contains-substring-p
           "state must be a proper, non-circular list"
           (error-message-from
            (lambda ()
              (restore-runtime-state game state))))))))

(test runtime-state-reader-rejects-dispatch-macros
  (is (contains-substring-p
       "does not allow # reader syntax"
       (error-message-from
        (lambda ()
          (with-input-from-string
              (stream "#1=(:current-room \"start\" :return-stack #1#)")
            (dunge::read-runtime-state-form stream "runtime-state")))))))

(test malformed-conditions-fail-source-or-game-validation
  (signals error
    (source-game-with-body
     '(:branch
       :when 42
       :then ((:p :text "bad")))))
  (signals error
    (source-game-with-body
     '(:choice
       :options
       ((:option :label "Bad" :do (:quit) :when 42)))))
  (signals error
    (source-game-with-body
     '(:branch
       :when (:eq
              :left (:eq :left t :right t)
              :right t)
       :then ((:p :text "bad")))))
  (signals error
    (source-game-with-body
     '(:entity
       :name "panel"
       :body
       ((:action
         :label "Bad conditional"
         :do
         ((:if :when 42
           :then ((:set
                   :target (:state :scope :global :key :x)
                   :value t))))))))))

(test condition-operators-read-state
  (multiple-value-bind (game door panel) (build-state-fixture)
    (declare (ignore door))
    (let ((context (test-context game :self panel)))
      (execute-effect
       (source-node
        '(:set
          :target (:state :scope :global :key :recipe)
          :value t))
       context)
      (is (evaluate-condition
           (source-state :global :recipe)
           context))
      (is (evaluate-condition
           (source-node
            '(:eq
              :left (:state :scope :self :key :switch)
              :right :off))
           context))
      (is (not (evaluate-condition
                (source-node
                 '(:not
                   :condition (:state :scope :global :key :recipe)))
                context)))
      (is (evaluate-condition
           (source-node
            '(:and
              :conditions
              ((:state :scope :global :key :recipe)
               (:eq
                :left (:state :scope :self :key :switch)
                :right :off))))
           context))
      (is (evaluate-condition
           (source-node
            '(:or
              :conditions
              ((:eq
                :left (:state :scope :self :key :switch)
                :right :on)
               (:eq
                :left (:state :scope :self :key :switch)
                :right :off))))
           context)))))

(test branch-selects-active-children
  (let ((game (source-game-with-body))
        (node (source-node
               '(:branch
                 :when (:state :scope :global :key :recipe)
                 :then ((:p :text "You know the recipe."))
                 :else ((:p :text "You are missing the recipe."))))))
    (let ((without-recipe
            (with-output-to-string (output)
              (let ((*output* output))
                (describe-entity node (test-context game))))))
      (is (contains-substring-p "missing the recipe" without-recipe)))
    (execute-effect
     (source-node
      '(:set
        :target (:state :scope :global :key :recipe)
        :value t))
     (test-context game))
    (let ((with-recipe
            (with-output-to-string (output)
              (let ((*output* output))
                (describe-entity node (test-context game))))))
      (is (contains-substring-p "know the recipe" with-recipe)))))

(test once-and-conditional-choices
  (let* ((game
           (source-game-with-body
            '(:choice
              :options
              ((:option
                :label "Take the recipe"
                :do (:quit)
                :id :take-recipe
                :once t
                :when (:state :scope :global :key :recipe))))))
         (choice-node (first (entities (first (game-rooms game)))))
         (take-recipe (first (options choice-node))))
    (let ((context (test-context game)))
      (is (not (dunge::choice-visible-p take-recipe context)))
      (execute-effect
       (source-node
        '(:set
          :target (:state :scope :global :key :recipe)
          :value t))
       context)
      (is (dunge::choice-visible-p take-recipe context))
      (dunge::mark-choice-taken take-recipe context)
      (is (not (dunge::choice-visible-p take-recipe context))))))

(test bare-effect-choice-target-refreshes
  (let* ((game
           (source-game-with-body
            '(:choice
              :options
              ((:option
                :label "Set flag"
                :do (:set
                     :target (:state :scope :global :key :flag)
                     :value t))
               (:option :label "Quit" :do (:quit))))))
         (result (let ((*input* (make-string-input-stream (format nil "1~%2~%")))
                       (*output* (make-string-output-stream)))
                   (evaluate game))))
    (is (typep result 'quit))
    (is (state-value (source-state :global :flag) (test-context game)))))

(test action-with-nil-effects-is-a-no-op-refresh
  (let* ((game
           (source-game-with-body
            '(:entity
              :name "panel"
              :body
              ((:action :label "Wait")))))
         (panel (first (entities (first (game-rooms game)))))
         (action-node (first (entities panel))))
    (is (typep (evaluate action-node (test-context game)) 'dunge::refresh))))

(test actions-store-and-use-entity-owners
  (let* ((game
           (source-game-with-body
            '(:entity
              :name "panel"
              :state ((:switch :off))
              :body
              ((:action
                :label "Flip"
                :do
                ((:set
                  :target (:state :scope :self :key :switch)
                  :value :on)))))))
         (panel (first (entities (first (game-rooms game)))))
         (action-node (first (entities panel)))
         (context (test-context game)))
    (is (eq panel (action-owner action-node)))
    (let ((choice (first (collect-choices action-node context))))
      (is (eq action-node (target choice)))
      (evaluate (target choice) context)
      (is (eq :on (state-value (source-state :self :switch)
                               (test-context game :self panel)))))))

(test nested-actions-keep-containing-entity-owner
  (let* ((game
           (source-game-with-body
            '(:entity
              :name "panel"
              :state ((:switch :off))
              :body
              ((:branch
                :when (:eq :left t :right t)
                :then
                ((:action
                  :label "Flip"
                  :do
                  ((:set
                    :target (:state :scope :self :key :switch)
                    :value :on)))))))))
         (panel (first (entities (first (game-rooms game)))))
         (choice (first (collect-choices panel (test-context game))))
         (action-node (target choice)))
    (is (eq panel (action-owner action-node)))
    (evaluate action-node (test-context game))
    (is (eq :on (state-value (source-state :self :switch)
                             (test-context game :self panel))))))

(test action-validation-is-structural
  (let* ((panel
           (source-node
            '(:entity
              :name "panel"
              :body
              ((:action
                :label "Flip"
                :do
                ((:set
                  :target (:state :scope :global :key :x)
                  :value t)))))))
         (unprepared-game
           (dunge::%make-game
            :rooms (list (dunge::%make-room
                          :name "room"
                          :entities (list panel))))))
    (is (null (action-owner (first (entities panel)))))
    (is (eq unprepared-game (validate-game unprepared-game)))))

(test room-validation-allows-unresolved-navigation-targets
  (let ((room (load-dunge-string
               "(:room :id \"start\" :body ((:choice :options ((:option :label \"Next\" :do (:goto :room \"missing\"))))))")))
    (is (typep room 'room))
    (is (eq room (validate-room room)))))

(test room-validation-catches-local-authoring-errors
  (signals error
    (load-dunge-string
     "(:room :id \"start\" :body ((:entity :name \"first\" :id \"same\") (:entity :name \"second\" :id \"same\")))"))
  (signals error
    (load-dunge-string
     "(:room :id \"start\" :body ((:entity :name \"panel\" :refs ((:door \"missing-door\")))))"))
  (signals error
    (load-dunge-string
     "(:room :id \"start\" :body ((:choice :options ((:option :label \"Once\" :do (:quit) :once t)))))")))

(test validator-catches-authoring-errors
  (signals error
    (source-game-with-body
     '(:choice
       :options
       ((:option :label "Missing room" :do (:goto :room "missing"))))))
  (signals error
    (source-game-with-body
     '(:choice
       :options
       ((:option :label "Once without id" :do (:quit) :once t)))))
  (signals error
    (source-node
     '(:game
       :start "missing"
       :rooms
       ((:room :id "start")))))
  (signals error
    (source-node
     '(:game
       :start "start"
       :rooms
       ((:room :id "start")
        (:room :id "start")))))
  (signals error
    (source-game-with-body
     '(:entity
       :name "panel"
       :refs ((:door "missing-door")))))
  (signals error
    (source-game-with-body
     '(:action
       :label "Loose action"
       :do
       ((:set
         :target (:state :scope :global :key :x)
         :value t))))))

(test validator-catches-duplicate-ids-and-malformed-state-refs
  (signals error
    (source-game-with-body
     '(:choice
       :options
       ((:option :label "First" :do (:quit) :id :same)
        (:option :label "Second" :do (:quit) :id :same)))))
  (signals error
    (source-game-with-body
     '(:entity :name "first" :id "same")
     '(:entity :name "second" :id "same")))
  (signals error
    (source-game-with-body
     '(:entity
       :name "panel"
       :body
       ((:action
         :label "Bad ref"
         :do
         ((:set
           :target (:state :scope :global :key "recipe")
           :value t))))))))

(test malformed-key-shapes-are-rejected
  (signals error
    (source-game-with-body
     '(:entity
       :name "panel"
       :state ((switch :off)))))
  (signals error
    (source-game-with-body
     '(:entity :name "door" :id "door")
     '(:entity
       :name "panel"
       :refs ((door "door")))))
  (signals error
    (source-game-with-body
     '(:entity :name "door" :id :door)))
  (signals error
    (source-game-with-body
     '(:entity :name "door" :id "door")
     '(:entity
       :name "panel"
       :refs ((:door :door)))))
  (signals error
    (source-game-with-body
     '(:choice
       :options
       ((:option :label "Take" :do (:quit) :id "take" :once t)))))
  (signals error
    (source-node '(:state :scope :self :key "switch")))
  (signals error
    (source-node '(:state :scope self :key :switch))))

(test effect-lists-error-and-empty-else-branches-are-safe
  (is (contains-substring-p
       "(:sequence :effects ...)"
       (error-message-from
        (lambda ()
          (execute-effect
           (list (source-node
                  '(:set
                    :target (:state :scope :global :key :x)
                    :value t))))))))
  (let ((game (source-game-with-body)))
    (is (null (execute-effect
               (source-node
                '(:if
                  :when (:eq :left nil :right t)
                  :then
                  ((:set
                    :target (:state :scope :global :key :x)
                    :value t))))
               (test-context game))))))

(test sequence-stops-after-first-control-result
  (let* ((game
           (source-node
            '(:game
              :start "start"
              :rooms
              ((:room :id "start")
               (:room :id "next")))))
         (context (test-context game))
         (result
           (execute-effect
            (source-node
             '(:sequence
               :effects
               ((:set
                 :target (:state :scope :global :key :before-control)
                 :value t)
                (:goto :room "next")
                (:set
                 :target (:state :scope :global :key :after-control)
                 :value t))))
            context)))
    (is (typep result 'goto))
    (is (equal "next" (room-name result)))
    (is (state-value (source-state :global :before-control) context))
    (is (not (state-value (source-state :global :after-control) context)))))

(test once-choice-disappears-in-scripted-game
  (let* ((game
           (source-game-with-body
            '(:choice
              :options
              ((:option
                :label "Take key"
                :do (:sequence
                     :effects
                     ((:set
                       :target (:state :scope :global :key :key)
                       :value t)))
                :id :take-key
                :once t)
               (:option :label "Leave" :do (:quit))))))
         (output (run-game-with-input game (format nil "1~%1~%"))))
    (is (= 1 (substring-count "Take key" output)))
    (is (= 2 (substring-count "Leave" output)))))

(test paragraph-output-uses-blank-lines
  (let* ((game (source-game-with-body
                '(:p :text "First paragraph.")
                '(:p :text "Second paragraph.")))
         (output (run-game-with-input game "")))
    (is (contains-substring-p
         (format nil "First paragraph.~%~%Second paragraph.")
         output))))

(test say-output-uses-blank-lines-before-refresh
  (let* ((game
           (source-game-with-body
            '(:choice
              :options
              ((:option :label "Speak" :do (:say :text "A spoken beat."))
               (:option :label "Leave" :do (:quit))))))
         (output (run-game-with-input game (format nil "1~%2~%"))))
    (is (contains-substring-p
         (format nil "A spoken beat.~%~%room")
         output))))

(test gosub-and-back-return-to-calling-room
  (let* ((game
           (source-node
            '(:game
              :start "start"
              :rooms
              ((:room
                :id "start"
                :body
                ((:p :text "The start chamber waits.")
                 (:choice
                  :options
                  ((:option :label "Visit alcove" :do (:gosub :room "alcove"))
                   (:option :label "Leave" :do (:quit))))))
               (:room
                :id "alcove"
                :body
                ((:p :text "The alcove hums.")
                 (:choice
                  :options
                  ((:option :label "Back" :do (:back))))))))))
         (output (run-game-with-input game (format nil "1~%1~%2~%"))))
    (is (= 2 (substring-count "The start chamber waits." output)))
    (is (= 1 (substring-count "The alcove hums." output)))))

(test example-loaders-read-dunge-source-files
  (let ((basic (dunge-examples:load-basic-example))
        (control-panel (dunge-examples:load-control-panel-example)))
    (is (typep basic 'game))
    (is (equal '("entrance" "hallway")
               (mapcar #'name (game-rooms basic))))
    (is (typep control-panel 'game))
    (is (equal '("hallway" "hidden room")
               (mapcar #'name (game-rooms control-panel))))))

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
    (is (contains-substring-p "Hidden Room" output))))
