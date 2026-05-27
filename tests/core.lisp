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

(defun source-game-with-tables (tables &rest body)
  (source-node
   `(:game
     :start "room"
     :tables ,tables
     :rooms
     ((:room :id "room" :body ,body)))))

(defun source-game-with-seeded-tables (seed tables &rest body)
  (source-node
   `(:game
     :start "room"
     :seed ,seed
     :tables ,tables
     :rooms
     ((:room :id "room" :body ,body)))))

(defun source-game-with-player (player &rest body)
  (source-node
   `(:game
     :start "room"
     :player ,player
     :rooms
     ((:room :id "room" :body ,body)))))

(defun sorted-keywords (keywords)
  (sort (copy-list keywords)
        #'string<
        :key #'symbol-name))

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

(defun run-session-script (session input &key debug)
  (let (result)
    (values
     (with-output-to-string (output)
       (let ((*input* (make-string-input-stream input))
             (*output* output))
         (setf result
               (if debug
                   (evaluate-session session :debug t)
                   (evaluate-session session)))))
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
    (source-node '(:option :label "Retired" :do (:quit))))
  (signals error
    (source-game-with-body
     '(:choice
       :options
       ((:option :label "Retired" :do (:quit))))))
  (signals error
    (source-node '(:goto :room "retired")))
  (signals error
    (source-node '(:gosub :room "retired")))
  (signals error
    (source-node '(:%choice :label "Private" :do (:quit))))
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
            "(:room :id \"start\" :body ((:choice (:quit))))")
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
                  "while compiling :ROOM -> field :BODY -> :CHOICE"
                  message))
             (is (contains-substring-p ":CHOICE expects"
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
             "Set declared"
             (:set
              :target (:state :scope :global :key :known)
              :value t)))))
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
                 "Set declared"
                 (:set
                  :target (:state :scope :global :key :known)
                  :value t)))))))))
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
                 "Set undeclared"
                 (:set
                  :target (:state :scope :global :key :missing)
                  :value t)))))))))))
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
        (:once
         :id :find-clue
         (:choice
          "Find clue"
          (:sequence
           :effects
           ((:set
             :target (:state :scope :global :key :clue)
             :value t)
            (:inc
             :target (:state :scope :global :key :visits))))))
        (:choice "Go to notes" (:go "notes"))
        (:choice "Quit" (:quit))))
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
             (second (entities start-room))
             restored-context))))))

(test player-source-form-parses-and-validates-core-state
  (let* ((game
           (source-game-with-player
            '(:player
              :name "Mara"
              :background :soldier
              :str 12
              :dex 11
              :wil 9
              :hp 4
              :armor 1
              :gold 8
              :fate 1
              :inventory ((:item :rusted-dagger)
                          (:supply :ration :count 3))
              :fatigue 1
              :conditions (:deprived))))
         (player (game-player game)))
    (is (typep player 'player))
    (is (equal "Mara" (player-name player)))
    (is (eq :soldier (player-background player)))
    (is (= 12 (player-str player)))
    (is (= 12 (player-max-str player)))
    (is (= 4 (player-hp player)))
    (is (= 4 (player-max-hp player)))
    (is (equal '((:item :rusted-dagger)
                 (:supply :ration :count 3))
               (player-inventory player)))
    (is (equal '(:deprived) (player-conditions player)))))

(test malformed-player-source-fails-validation
  (signals error
    (source-game-with-player
     '(:player :str -1)))
  (signals error
    (source-game-with-player
     '(:player :str 12 :max-str 10)))
  (signals error
    (source-game-with-player
     '(:player :conditions ("deprived")))))

(test runtime-state-captures-and-restores-player-state
  (let* ((game
           (source-game-with-player
            '(:player
              :name "Mara"
              :background :soldier
              :str 12
              :dex 11
              :wil 9
              :hp 4
              :armor 1
              :gold 8
              :fate 1
              :inventory ((:item :rusted-dagger))
              :conditions (:deprived))))
         (session (make-runtime-session game))
         (player (game-player game)))
    (setf (player-hp player) 2
          (player-gold player) 13
          (player-inventory player) '((:item :rusted-dagger)
                                      (:supply :ration :count 2))
          (player-conditions player) '(:deprived :poisoned))
    (let* ((state (capture-runtime-state session))
           (fresh-game
             (source-game-with-player
              '(:player
                :name "Mara"
                :background :soldier
                :str 12
                :dex 11
                :wil 9
                :hp 4
                :armor 1
                :gold 8
                :fate 1
                :inventory ((:item :rusted-dagger))
                :conditions (:deprived))))
           (restored-session (restore-runtime-state fresh-game state))
           (restored-player (game-player fresh-game)))
      (declare (ignore restored-session))
      (is (equal "Mara" (getf (getf state :player) :name)))
      (is (= 2 (player-hp restored-player)))
      (is (= 4 (player-max-hp restored-player)))
      (is (= 13 (player-gold restored-player)))
      (is (equal '((:item :rusted-dagger)
                   (:supply :ration :count 2))
                 (player-inventory restored-player)))
      (is (equal '(:deprived :poisoned)
                 (player-conditions restored-player))))))

(test runtime-state-restores-saved-player-into-game-without-authored-player
  (let* ((game (source-game-with-player
                '(:player :name "Mara" :str 12 :hp 4)))
         (session (make-runtime-session game))
         (state (capture-runtime-state session))
         (fresh-game (source-game-with-body)))
    (restore-runtime-state fresh-game state)
    (is (game-player fresh-game))
    (is (equal "Mara" (player-name (game-player fresh-game))))
    (is (= 12 (player-str (game-player fresh-game))))))

(test console-debug-undo-restores-previous-choice-state
  (let* ((game (build-save-load-fixture))
         (session (make-runtime-session game)))
    (multiple-value-bind (output result)
        (run-session-script session (format nil "2~%4~%4~%") :debug t)
      (is (typep result 'quit))
      (is (contains-substring-p "4. Undo" output))
      (is (= 2 (substring-count "Find clue" output)))
      (let ((context (test-context game)))
        (is (not (state-value (source-state :global :clue) context)))
        (is (= 0 (state-value (source-state :global :visits) context)))
        (is (not (gethash :find-clue (game-taken-choices game))))))))

(test console-debug-undo-works-from-fall-through-room
  (let* ((game (build-save-load-fixture))
         (session (make-runtime-session game)))
    (multiple-value-bind (output result)
        (run-session-script session (format nil "2~%2~%1~%4~%4~%") :debug t)
      (is (typep result 'quit))
      (is (contains-substring-p "The notes are organized." output))
      (is (contains-substring-p "1. Undo" output))
      (is (contains-substring-p "4. Undo" output))
      (is (equal "start" (runtime-session-current-room-name session)))
      (let ((context (test-context game)))
        (is (not (state-value (source-state :global :clue) context)))
        (is (= 0 (state-value (source-state :global :visits) context)))))))

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
     '(:choice "Bad" (:quit) :when 42)))
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
            '(:when (:state :scope :global :key :recipe)
              (:once :id :take-recipe
               (:choice "Take the recipe" (:quit))))))
         (branch-node (first (entities (first (game-rooms game))))))
    (let ((context (test-context game)))
      (is (null (collect-choices branch-node context)))
      (execute-effect
       (source-node
        '(:set
          :target (:state :scope :global :key :recipe)
          :value t))
       context)
      (let ((take-recipe (first (collect-choices branch-node context))))
        (is (dunge::choice-visible-p take-recipe context))
        (dunge::mark-choice-taken take-recipe context)
        (is (null (collect-choices branch-node context)))))))

(test availability-protocol-keeps-choice-conditions-and-consumption-general
  (let* ((game
           (source-game-with-body
            '(:choice
              "Open secret"
              (:quit)
              :when (:marked? :secret-open)
              :once t
              :id :open-secret)))
         (context (test-context game))
         (choice (first (entities (first (game-rooms game))))))
    (is (typep choice 'availability-mixin))
    (is (typep choice 'consumable-mixin))
    (is (not (available-p choice context)))
    (execute-effect (source-node '(:mark :secret-open)) context)
    (is (available-p choice context))
    (consume-node choice context)
    (is (consumed-p choice context))
    (is (not (available-p choice context)))))

(test table-source-forms-parse-index-and-retain-entry-metadata
  (let* ((game
           (source-game-with-tables
            '((:table
               :id :minor-loot
               :mode :weighted
               :entries
               ((:table-entry
                 :id :coins
                 :weight 3
                 :tags (:loot :coin)
                 :result (:gold "1d6"))
                (:table-entry
                 :weight 1
                 :when (:marked? :found-cache)
                 :tags (:loot :rare)
                 :result (:item :silver-ring)))))))
         (table (find :minor-loot (game-tables game) :key #'table-id)))
    (is (not (null table)))
    (is (eq table (gethash :minor-loot (table-index game))))
    (is (eq :weighted (table-mode table)))
    (is (= 2 (length (table-entries table))))
    (let ((entry (first (table-entries table))))
      (is (eq :coins (table-entry-id entry)))
      (is (= 3 (table-entry-weight entry)))
      (is (equal '(:loot :coin) (node-tags entry)))
      (is (equal '(:gold "1d6") (table-entry-result entry))))))

(test table-source-validation-catches-bad-definitions
  (signals error
    (source-game-with-tables
     '((:table :id "loot" :entries
        ((:table-entry :result :nothing))))))
  (signals error
    (source-game-with-tables
     '((:table :id :loot :mode :mystery :entries
        ((:table-entry :result :nothing))))))
  (signals error
    (source-game-with-tables
     '((:table :id :loot :entries
        ((:table-entry :weight 0 :result :nothing))))))
  (signals error
    (source-game-with-tables
     '((:table :id :loot :mode :roll :entries
        ((:table-entry :result :nothing))))))
  (signals error
    (source-game-with-tables
     '((:table :id :loot :mode :roll :entries
        ((:table-entry :range (1 3) :result :first)
         (:table-entry :range (3 4) :result :second))))))
  (signals error
    (source-game-with-tables
     '((:table :id :loot :entries
        ((:table-entry :result (:table :missing)))))))
  (signals error
    (source-game-with-tables
     '((:table :id :loot :entries
        ((:table-entry :tags (:loot "bad") :result :nothing))))))
  (signals error
    (source-game-with-tables
     '((:table :id :same :entries
        ((:table-entry :result :first)))
       (:table :id :same :entries
        ((:table-entry :result :second)))))))

(test table-roll-modes-resolve-with-conditions-and-state
  (let* ((game
           (source-game-with-tables
            '((:table
               :id :stateful
               :mode :weighted
               :entries
               ((:table-entry
                 :when (:marked? :unlocked)
                 :result :open)
                (:table-entry
                 :when (:not (:marked? :unlocked))
                 :result :closed)))
              (:table
               :id :ordered
               :mode :sequence
               :entries
               ((:table-entry :result :first)
                (:table-entry :result :second)))
              (:table
               :id :roll-result
               :mode :roll
               :entries
               ((:table-entry :range 1 :result :rolled)))
              (:table
               :id :match
               :mode :first-match
               :entries
               ((:table-entry
                 :when (:marked? :unlocked)
                 :result :unlocked)
                (:table-entry :result :fallback)))
              (:table
               :id :inner
               :mode :sequence
               :entries
               ((:table-entry :result :inner-result)))
              (:table
               :id :bundle
               :mode :bundle
               :entries
               ((:table-entry :result :gold)
                (:table-entry :result (:table :inner)))))))
         (context (test-context game)))
    (is (eq :closed (roll-table game :stateful :context context)))
    (is (eq :fallback (roll-table game :match :context context)))
    (execute-effect (source-node '(:mark :unlocked)) context)
    (is (eq :open (roll-table game :stateful :context context)))
    (is (eq :unlocked (roll-table game :match :context context)))
    (is (eq :first (roll-table game :ordered)))
    (is (eq :second (roll-table game :ordered)))
    (is (eq :second (roll-table game :ordered)))
    (is (eq :rolled (roll-table game :roll-result)))
    (is (equal '(:gold :inner-result)
               (roll-table game :bundle)))))

(test deck-table-draws-without-replacement-before-reshuffling
  (let* ((game
           (source-game-with-tables
            '((:table
               :id :deck
               :mode :deck
               :entries
               ((:table-entry :result :first)
                (:table-entry :result :second))))))
         (first-two (list (roll-table game :deck)
                          (roll-table game :deck)))
         (third (roll-table game :deck)))
    (is (equal '(:first :second) (sorted-keywords first-two)))
    (is (member third '(:first :second)))))

(defun build-table-state-fixture ()
  (source-game-with-tables
   '((:table
      :id :ordered
      :mode :sequence
      :entries
      ((:table-entry :result :first)
       (:table-entry :result :second)
       (:table-entry :result :third)))
     (:table
      :id :deck
      :mode :deck
      :entries
      ((:table-entry :result :left)
       (:table-entry :result :right))))))

(test table-runtime-state-captures-and-restores-sequence-and-deck-progress
  (let* ((game (build-table-state-fixture))
         (session (make-runtime-session game)))
    (is (eq :first (roll-table game :ordered)))
    (is (eq :second (roll-table game :ordered)))
    (let* ((deck-first (roll-table game :deck))
           (state (capture-runtime-state session))
           (fresh-game (build-table-state-fixture)))
      (restore-runtime-state fresh-game state)
      (is (eq :third (roll-table fresh-game :ordered)))
      (let ((deck-next (roll-table fresh-game :deck)))
        (is (member deck-next '(:left :right)))
        (is (not (eq deck-first deck-next)))))))

(defun build-seeded-table-fixture (&optional (seed 17))
  (source-game-with-seeded-tables
   seed
   '((:table
      :id :weighted
      :mode :weighted
      :entries
      ((:table-entry :weight 1 :result :first)
       (:table-entry :weight 1 :result :second)
       (:table-entry :weight 1 :result :third)))
     (:table
      :id :certain-roll
      :mode :roll
      :entries
      ((:table-entry :range 1 :result :only)))
     (:table
      :id :ordered
      :mode :sequence
      :entries
      ((:table-entry :result :first)
       (:table-entry :result :second))))))

(test table-rolls-use-game-seed-and-record-roll-log
  (let ((first-game (build-seeded-table-fixture 314))
        (second-game (build-seeded-table-fixture 314)))
    (is (= 314 (game-random-seed first-game)))
    (let ((first-results (loop repeat 5
                               collect (roll-table first-game :weighted)))
          (second-results (loop repeat 5
                                collect (roll-table second-game :weighted))))
      (is (equal first-results second-results)))
    (is (= 5 (length (game-roll-log first-game)))))
  (let ((game (build-seeded-table-fixture 9)))
    (is (eq :only (roll-table game :certain-roll)))
    (is (equal (list (list :table :certain-roll
                           :mode :roll
                           :entry 0
                           :roll 1
                           :die 1
                           :result :only))
               (game-roll-log game))))
  (let ((game (build-seeded-table-fixture 9)))
    (is (eq :first (roll-table game :ordered)))
    (is (eq :second (roll-table game :ordered)))
    (is (equal '(:first :second)
               (mapcar (lambda (entry)
                         (getf entry :result))
                       (game-roll-log game))))
    (is (equal '(0 1)
               (mapcar (lambda (entry)
                         (getf entry :entry))
                       (game-roll-log game))))))

(test game-seed-must-be-non-negative
  (signals error
    (source-game-with-seeded-tables
     -1
     nil)))

(test runtime-state-captures-and-restores-rng-state-and-roll-log
  (let* ((game (build-seeded-table-fixture 123))
         (session (make-runtime-session game)))
    (roll-table game :weighted)
    (let* ((state (capture-runtime-state session))
           (expected-next (roll-table game :weighted))
           (fresh-game (build-seeded-table-fixture 123))
           (restored-session (restore-runtime-state fresh-game state)))
      (declare (ignore restored-session))
      (is (getf state :rng-state))
      (is (= 1 (length (getf state :roll-log))))
      (is (= 1 (length (game-roll-log fresh-game))))
      (is (eq expected-next (roll-table fresh-game :weighted)))
      (is (= 2 (length (game-roll-log fresh-game)))))))

(test author-facing-shorthands-keep-control-flow-composable
  (let* ((game
           (source-node
            '(:game
              :start "room"
              :flags (:seen-note)
              :marked (:knows-recipe)
              :rooms
              ((:room
                :id "room"
                :body
                ((:when (:marked? :knows-recipe)
                   (:p "You know the recipe."))
                 (:when (:not (:marked? :seen-note))
                   (:p "The note is still unread."))
                 (:once
                  :id :read-note
                  (:choice
                   "Read the note"
                   ((:mark :seen-note)
                    (:say "The note confirms the recipe."))))
                 (:choice
                  "Forget the recipe"
                  ((:unmark :knows-recipe)
                   (:say "The recipe slips away.")))
                 (:choice "Leave" (:quit))))))))
         (output (run-game-with-input game (format nil "1~%1~%2~%"))))
    (is (= 1 (substring-count "Read the note" output)))
    (is (contains-substring-p "You know the recipe." output))
    (is (contains-substring-p "The note is still unread." output))
    (is (state-value (source-state :global :seen-note)
                     (test-context game)))
    (is (not (state-value (source-state :global :knows-recipe)
                          (test-context game))))))

(test bare-effect-choice-target-refreshes
  (let* ((game
           (source-game-with-body
            '(:choice
              "Set flag"
              (:set
               :target (:state :scope :global :key :flag)
               :value t))
            '(:choice "Quit" (:quit))))
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
               "(:room :id \"start\" :body ((:choice \"Next\" (:go \"missing\"))))")))
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
     "(:room :id \"start\" :body ((:choice \"Once\" (:quit) :once t)))")))

(test validator-catches-authoring-errors
  (signals error
    (source-game-with-body
     '(:choice "Missing room" (:go "missing"))))
  (signals error
    (source-game-with-body
     '(:choice "Once without id" (:quit) :once t)))
  (signals error
    (source-game-with-body
     '(:once (:choice "Once without id" (:quit)))))
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
     '(:once :id :same (:choice "First" (:quit)))
     '(:once :id :same (:choice "Second" (:quit)))))
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
     '(:once :id "take" (:choice "Take" (:quit)))))
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
                (:go "next")
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
            '(:once
              :id :take-key
              (:choice
               "Take key"
               (:sequence
                :effects
                ((:set
                  :target (:state :scope :global :key :key)
                  :value t)))))
            '(:choice "Leave" (:quit))))
         (output (run-game-with-input game (format nil "1~%1~%"))))
    (is (= 1 (substring-count "Take key" output)))
    (is (= 2 (substring-count "Leave" output)))))

(test room-title-output-is-underlined
  (let* ((game
           (source-node
            '(:game
              :start "start"
              :rooms
              ((:room :id "start" :title "Scene Title")))))
         (output (run-game-with-input game "")))
    (is (contains-substring-p
         (format nil "Scene Title~%===========~%~%")
         output))))

(test game-output-starts-with-blank-line
  (let* ((game
           (source-node
            '(:game
              :start "start"
              :rooms
              ((:room :id "start" :title "Scene Title")))))
         (output (run-game-with-input game "")))
    (is (char= #\Newline (char output 0)))))

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
            '(:choice "Speak" (:say :text "A spoken beat."))
            '(:choice "Leave" (:quit))))
         (output (run-game-with-input game (format nil "1~%2~%"))))
    (is (contains-substring-p
         (format nil "A spoken beat.~%~%room")
         output))))

(test say-output-can-pause-before-refresh
  (let* ((game
           (source-game-with-body
            '(:choice "Speak" (:say :text "A spoken beat."))
            '(:choice "Leave" (:quit))))
         (output
           (with-output-to-string (stream)
             (let ((*input* (make-string-input-stream
                             (format nil "1~%~%2~%")))
                   (*output* stream)
                   (*pause-after-say* t))
               (evaluate game)))))
    (is (contains-substring-p
         (format nil "A spoken beat.~%~%Press Enter to continue.~%room")
         output))))

(test choice-submit-adds-spacing-before-next-output
  (let* ((game
           (source-game-with-body
            '(:choice "Speak" (:say :text "A spoken beat."))
            '(:choice "Leave" (:quit))))
         (output (run-game-with-input game (format nil "1~%2~%"))))
    (is (contains-substring-p
         (format nil "2. Leave~%> ~%A spoken beat.")
         output))))

(test choice-submit-keeps-next-scene-heading-tight
  (let* ((game
           (source-node
            '(:game
              :start "start"
              :rooms
              ((:room
                :id "start"
                :body
                ((:choice "Go" (:go "next"))))
               (:room :id "next" :title "Next Room")))))
         (output (run-game-with-input game (format nil "1~%"))))
    (is (contains-substring-p
         (format nil "1. Go~%> ~%Next Room~%=========~%~%")
         output))
    (is (not (contains-substring-p
              (format nil "Next Room~%~%=========")
              output)))))

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
                 (:choice "Visit alcove" (:gosub "alcove"))
                 (:choice "Leave" (:quit))))
               (:room
                :id "alcove"
                :body
                ((:p :text "The alcove hums.")
                 (:choice "Back" (:back))))))))
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

(test html-compiler-generates-single-file-index-shell
  (let* ((game (source-game-with-body
                '(:p "A compiled room.")
                '(:choice "Leave" (:quit))))
         (html (dunge-html:compile-index-html game :title "Compiled Dunge")))
    (is (contains-substring-p "<!doctype html>" html))
    (is (contains-substring-p "<body><main id='dunge-app'>" html))
    (is (contains-substring-p "id='dunge-new-game'" html))
    (is (contains-substring-p "id='dunge-scene-title'" html))
    (is (contains-substring-p "id='dunge-scene-body'" html))
    (is (contains-substring-p "id='dunge-choices'" html))
    (is (contains-substring-p "window.DUNGE_GAME_DATA = " html))
    (is (contains-substring-p "document.addEventListener('DOMContentLoaded', bootDungeGame);"
                              html))
    (is (not (contains-substring-p "<script src=" html)))
    (is (not (contains-substring-p "&quot;" html)))))

(test html-compiler-lowers-stateful-ast-data-for-browser-runtime
  (let* ((game
           (source-game-with-body
            '(:entity
              :name "panel"
              :id "panel"
              :state ((:switch :off))
              :body
              ((:action
                :label "Flip"
                :do
                ((:toggle
                  :target (:state :scope :self :key :switch))))))
            '(:when (:eq
                     :left (:state :scope :global :key :seen)
                     :right t)
              (:p "Seen."))
            '(:once
              :id :look
              (:choice
               "Look"
               ((:set
                 :target (:state :scope :global :key :seen)
                 :value t)
                (:say "Noted."))))))
         (script (dunge-html:compile-game-script game)))
    (is (contains-substring-p "\"type\":\"keyword\",\"name\":\"off\""
                              script))
    (is (contains-substring-p "\"type\":\"toggle\"" script))
    (is (contains-substring-p "\"type\":\"eq\"" script))
    (is (contains-substring-p "\"id\":\"look\"" script))
    (is (contains-substring-p "STATE['taken-choices']" script))
    (is (not (contains-substring-p "STATE.takenChoices" script)))
    (is (contains-substring-p "window.DUNGE_GAME_SIGNATURE = " script))
    (is (contains-substring-p "window.DUNGE_GAME_SAVE_KEY = \"dunge-save:"
                              script))
    (is (contains-substring-p "window.DUNGE_GAME_DEBUG = false" script))
    (is (contains-substring-p "function captureRuntimeState" script))
    (is (contains-substring-p "function returnStackRoomId" script))
    (is (contains-substring-p "function restoreRuntimeState" script))
    (is (contains-substring-p "function restoreSavedGame" script))
    (is (contains-substring-p "function rememberUndoState" script))
    (is (contains-substring-p "function undoLastChoice" script))
    (is (contains-substring-p "function bindDebugControls" script))
    (is (contains-substring-p "function debugQueryFlagP" script))
    (is (contains-substring-p "part === 'debug=1'" script))
    (is (contains-substring-p "function debugHashFlagP" script))
    (is (contains-substring-p "hash === '#debug'" script))
    (is (contains-substring-p "debugQueryFlagP(window.location.search)"
                              script))
    (is (not (contains-substring-p "containsTextP" script)))
    (is (contains-substring-p "node.stateData" script))
    (is (contains-substring-p "window.localStorage.setItem" script))
    (is (contains-substring-p "currentRoom" script))
    (is (contains-substring-p "takenChoices" script))
    (is (contains-substring-p "'messages' : copyArray(VISIBLEMESSAGES)"
                              script))
    (is (contains-substring-p "MESSAGES = copyArray(state['messages']);"
                              script))
    (is (contains-substring-p "VISIBLEMESSAGES = copyArray(MESSAGES);"
                              script))
    (is (contains-substring-p "VISIBLEMESSAGES = [];" script))
    (is (contains-substring-p "beforeunload" script))
    (is (contains-substring-p "var __PS_MV_REG = [];" script))
    (is (contains-substring-p "function executeEffect" script))
    (is (contains-substring-p "function renderChoiceButton" script))
    (is (contains-substring-p "function renderChoices" script))))

(test html-compiler-lowers-player-state-for-browser-runtime
  (let* ((game
           (source-game-with-player
            '(:player
              :name "Mara"
              :background :soldier
              :str 12
              :hp 4
              :inventory ((:item :rusted-dagger))
              :conditions (:deprived))))
         (script (dunge-html:compile-game-script game)))
    (is (contains-substring-p "\"player\":{\"name\":\"Mara\"" script))
    (is (contains-substring-p "\"background\":{\"type\":\"keyword\",\"name\":\"soldier\"}"
                              script))
    (is (contains-substring-p "\"maxStr\":12" script))
    (is (contains-substring-p "\"inventory\":[[{\"type\":\"keyword\",\"name\":\"item\"}"
                              script))
    (is (contains-substring-p "function copyJsonValue" script))
    (is (contains-substring-p "'player' : copyJsonValue(PLAYER)" script))
    (is (contains-substring-p "if (state['player'] !== undefined)" script))))

(test html-compiler-can-enable-debug-controls
  (let* ((game (source-game-with-body
                '(:choice "Leave" (:quit))))
         (script (dunge-html:compile-game-script game :debug t))
         (html (dunge-html:compile-index-html game :debug t)))
    (is (contains-substring-p "window.DUNGE_GAME_DEBUG = true" script))
    (is (contains-substring-p "window.DUNGE_GAME_DEBUG = true" html))))

(test html-compiler-escapes-script-breaking-game-data
  (let* ((separator (string (code-char #x2028)))
         (game (source-game-with-body
                `(:p ,(format nil "</script><p>bad</p>~Aafter" separator))))
         (html (dunge-html:compile-index-html game)))
    (is (not (contains-substring-p "</script><p>bad</p>" html)))
    (is (contains-substring-p "\\u003C/script>" html))
    (is (contains-substring-p "\\u2028after" html))))

(test html-compiler-rejects-non-integer-numeric-data
  (signals error
    (dunge-html:compile-index-html
     (source-node
      '(:game
        :start "room"
        :state ((:visits 1/2))
        :rooms
        ((:room :id "room"))))))
  (signals error
    (dunge-html:compile-index-html
     (source-game-with-body
      '(:choice
        "Count"
        (:inc
         :target (:state :scope :global :key :visits)
         :amount 1.0d0))))))

(test html-compiler-runtime-surfaces-invalid-state-and-room-errors
  (let* ((game (source-game-with-body
                '(:choice
                  "Count"
                  (:inc :target (:state :scope :global :key :visits)))))
         (script (dunge-html:compile-game-script game)))
    (is (contains-substring-p "typeof number === 'number'" script))
    (is (contains-substring-p
         "Cannot increment or decrement non-numeric state value."
         script))
    (is (contains-substring-p "throw Error(message);" script))
    (is (not (contains-substring-p "new(Error(message))" script)))
    (is (contains-substring-p "Cannot toggle non-toggleable state value."
                              script))
    (is (contains-substring-p "No room named " script))))

(test html-compiler-writes-index-html-file
  (let* ((game (source-game-with-body
                '(:p "A written room.")))
         (path (merge-pathnames
                (format nil "dunge-html-~A/index.html" (gensym))
                (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (dunge-html:write-index-html game path :title "Written Dunge")
           (is (probe-file path))
           (with-open-file (stream path :direction :input)
             (let ((contents (make-string (file-length stream))))
               (read-sequence contents stream)
               (is (contains-substring-p "Written Dunge" contents))
               (is (contains-substring-p "window.DUNGE_GAME_DATA" contents)))))
      (let ((directory (uiop:pathname-directory-pathname path)))
        (when (probe-file directory)
          (uiop:delete-directory-tree directory :validate t))))))
