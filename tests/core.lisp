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

(defvar *test-worlds* (make-hash-table :test 'eq :weakness :key))

(defun test-world (game)
  "The world test contexts for GAME share by default, made on first use."
  (or (gethash game *test-worlds*)
      (setf (gethash game *test-worlds*) (make-world game))))

(defun test-context (game &key scene self (world (test-world game)))
  (make-runtime-context
   :game game
   :world world
   :scene scene
   :self self))

(defun world-of (thing)
  "The world THING plays in: a world, session, or context."
  (etypecase thing
    (world thing)
    (runtime-session (runtime-session-world thing))
    (runtime-context (runtime-context-world thing))))

(defun player-of (thing)
  (world-player (world-of thing)))

(defun globals-of (thing)
  (world-globals (world-of thing)))

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
  "Play GAME from the start in its test world, feeding it INPUT."
  (with-output-to-string (output)
    (let ((*input* (make-string-input-stream input))
          (*output* output))
      (terpri *output*)
      (evaluate-session (make-runtime-session game :world (test-world game))))))

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

(test define-dunge-node-builder-names-ignore-print-case
  ;; The builder is named from the symbol's name, not by printing it.
  (let ((expansion (let ((*print-case* :downcase))
                     (macroexpand-1
                      '(dunge::define-dunge-node case-sample-node () ())))))
    (is (find-if (lambda (form)
                   (and (consp form)
                        (eq (first form) 'defun)
                        (string= "%MAKE-CASE-SAMPLE-NODE"
                                 (symbol-name (second form)))))
                 (rest expansion)))))

(test source-errors-keep-their-cause
  (let ((condition (handler-case
                       (load-dunge-string "(:game :start \"r\" :seed -1
                                            :rooms ((:room :id \"r\" :body ())))")
                     (dunge-source-error (condition) condition))))
    (is (typep condition 'dunge-source-error))
    (is (typep (dunge-source-error-cause condition) 'error))
    (is (not (typep (dunge-source-error-cause condition) 'dunge-source-error)))
    (is (contains-substring-p "non-negative integer"
                              (princ-to-string condition)))))

(test define-dunge-node-rejects-unknown-options
  (signals error
    (macroexpand-1
     '(dunge::define-dunge-node invalid-sample-ast-node ()
       ()
       (:unknown-option t)))))

(test source-shorthands-expand-to-canonical-forms
  (flet ((expands (shorthand canonical)
           (is (equal canonical (dunge::expand-dunge-source-form shorthand)))))
    (expands '(:p "Hi.") '(:p :text "Hi."))
    (expands '(:say "Hi.") '(:say :text "Hi."))
    (expands '(:say (:self :hp)) '(:say :text (:self :hp)))
    (expands '(:go "hall") '(:go :room "hall"))
    (expands '(:gosub "hall") '(:gosub :room "hall"))
    (expands '(:not (:marked? :x)) '(:not :condition (:marked? :x)))
    (expands '(:and (:marked? :x) (:marked? :y))
             '(:and :conditions ((:marked? :x) (:marked? :y))))
    (expands '(:or (:marked? :x) (:marked? :y))
             '(:or :conditions ((:marked? :x) (:marked? :y))))
    (expands '(:choice "Leave" (:quit) :when (:marked? :x))
             '(:choice :label "Leave" :do (:quit) :when (:marked? :x)))
    (expands '(:once :id :leave (:choice "Leave" (:quit)))
             '(:choice :label "Leave" :do (:quit) :id :leave :once t))
    (expands '(:when (:marked? :x) (:p "A.") (:p "B."))
             '(:branch :when (:marked? :x) :then ((:p "A.") (:p "B."))))
    (expands '(:global :lamp) '(:state :scope :global :key :lamp))
    (expands '(:self :switch) '(:state :scope :self :key :switch))
    (expands '(:ref :door :open) '(:state :scope :ref :role :door :key :open))
    (expands '(:marked? :lamp) '(:state :scope :global :key :lamp))
    (expands '(:mark :lamp)
             '(:set :target (:state :scope :global :key :lamp) :value t))
    (expands '(:unmark :lamp)
             '(:set :target (:state :scope :global :key :lamp) :value nil))
    ;; Keyword-field spellings are canonical and compile as written.
    (dolist (form '((:p :text "Hi.")
                    (:say :text "Hi.")
                    (:go :room "hall")
                    (:gosub :room "hall")
                    (:choice :label "Leave" :do (:quit))
                    (:not :condition (:global :x))
                    (:and :conditions ((:global :x)))
                    (:state :scope :self :key :switch)))
      (expands form form))))

(test source-canonical-and-shorthand-spellings-compile-alike
  (is (typep (source-node '(:go :room "hall")) 'goto))
  (is (equal "hall" (room-name (source-node '(:go "hall")))))
  (is (typep (source-node '(:gosub :room "hall")) 'gosub))
  (let ((choice (source-node '(:choice :label "Leave" :do (:quit) :id :leave :once t))))
    (is (typep choice 'choice))
    (is (eq :leave (consumable-id choice)))
    (is (consumable-once-p choice)))
  (let ((reference (source-node '(:ref :door :open))))
    (is (eq :ref (dunge::state-ref-scope reference)))
    (is (eq :door (dunge::state-ref-role reference)))
    (is (eq :open (dunge::state-ref-key reference))))
  (is (eq :self (dunge::state-ref-scope (source-node '(:self :switch)))))
  (is (eq :global (dunge::state-ref-scope (source-node '(:global :lamp)))))
  ;; Malformed shorthands are source errors.
  (signals dunge-source-error (source-node '(:self)))
  (signals dunge-source-error (source-node '(:global :a :b)))
  (signals dunge-source-error (source-node '(:ref :door)))
  (signals dunge-source-error (source-node '(:go "hall" "yard")))
  (signals dunge-source-error (source-node '(:choice "Label only"))))

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
    (source-node '(:p :text (:quit))))
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
              "(:game :start \"start\" :rooms ((:room :id \"start\" :body ((:p :text (:quit))))))"
              :source-name "diagnostics.dunge")))))
    (is (contains-substring-p "Dunge source error in diagnostics.dunge"
                              message))
    (is (contains-substring-p
         "while compiling :GAME -> field :ROOMS -> :ROOM -> field :BODY -> :P -> field :TEXT"
         message))
    (is (contains-substring-p "Expected an expression form, got (:QUIT)" message))))

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
             (restored-context (test-context fresh-game
                                             :world (world-of restored-session)))
             (start-room (first (game-rooms fresh-game)))
             (panel (gethash "panel" (dunge::scene-index start-room))))
        (is (equal "notes"
                   (runtime-session-current-room-name restored-session)))
        (is (state-value (source-state :global :clue)
                         restored-context))
        (is (= 1 (state-value (source-state :global :visits)
                              restored-context)))
        (is (state-value (source-state :self :open)
                         (test-context fresh-game
                                       :self panel
                                       :world (world-of restored-session))))
        (is (dunge::choice-taken-p
             (second (entities start-room))
             restored-context))))))

(defparameter *mara-player*
  '((:name "Mara") (:background :soldier)
    (:hp 4) (:max-hp 4) (:armor 1) (:gold 8)
    (:fatigue 0) (:deprived nil)
    (:rusted-dagger 1) (:ration 3)))

(test player-state-is-declared-and-read-like-global-state
  (let* ((game (source-game-with-player *mara-player*))
         (context (test-context game)))
    (is (equal "Mara" (state-value (source-node '(:player :name)) context)))
    (is (= 4 (evaluate-expression (source-node '(:player :hp)) context)))
    (is (equal "Mara has 3 rations."
               (evaluate-expression
                (compile-dunge-source '(:concat "{player:name} has "
                                        (:player :ration) " rations."))
                context)))
    (execute-effect (source-node '(:dec :target (:player :ration) :amount 2))
                    context)
    (is (= 1 (gethash :ration (player-of context))))
    ;; The game is only a definition: a fresh world starts over.
    (is (= 3 (gethash :ration (player-of (make-world game))))))
  (flet ((rejects (player &rest body)
           (is (not (null (error-message-from
                           (lambda ()
                             (apply #'source-game-with-player player body))))))))
    (rejects '((:hp 1)) '(:choice "Heal" (:inc :target (:player :max-hp))))
    (rejects '((:hp 1) (:hp 2)))
    (rejects '((:hp 9007199254740992)))))

(test crawler-player-declarations-count-inventory
  (is (equal '((:name "Mara") (:background :soldier)
               (:str 12) (:max-str 12) (:dex 10) (:max-dex 10)
               (:wil 10) (:max-wil 10) (:hp 4) (:max-hp 4)
               (:armor 1) (:gold 0) (:fate 0) (:fatigue 0) (:deprived nil)
               (:rusted-dagger 1) (:ration 3) (:chalk 0))
             (player-declarations
              :name "Mara" :background :soldier :str 12 :hp 4 :armor 1
              :inventory '((:item :rusted-dagger)
                           (:supply :ration :count 2)
                           (:supply :ration))
              :catalog (item-catalog '((:item :chalk :slots 0)
                                       (:supply :ration :count 9))))))
  (signals error
    (player-declarations :inventory '((:item :hp))))
  ;; Malformed stats and starting kits are rejected.
  (signals error (player-declarations :armor -1))
  (signals error (player-declarations :inventory '((:item :torch :unknown t))))
  ;; One counter per id cannot hold both an item and a supply.
  (signals error (item-catalog '((:item :ration) (:supply :ration))))
  (signals error (used-slots-expression (item-catalog '((:item :rope :slots -1))))))

(test player-current-and-maximum-stats-are-validated
  (flet ((rejects (player)
           (is (not (null (error-message-from
                           (lambda () (source-game-with-player player))))))))
    (rejects '((:hp 5) (:max-hp 3)))
    (rejects '((:hp "four") (:max-hp 4)))
    (rejects '((:str -1) (:max-str 10))))
  (is (typep (source-game-with-player '((:hp 3) (:max-hp 4) (:name "Mara")))
             'game)))

(test loot-choice-ids-stay-distinct
  (let ((ids (list (dunge.crawler::loot-choice-id "a:b" 0)
                   (dunge.crawler::loot-choice-id "a-b" 0)
                   (dunge.crawler::loot-choice-id "A-b" 0)
                   (dunge.crawler::loot-choice-id "a-b" 1))))
    (is (= 4 (length (remove-duplicates ids))))
    (is (= 4 (length (remove-duplicates
                      (mapcar (lambda (id) (string-downcase (symbol-name id)))
                              ids)
                      :test #'string=))))))

(test html-compiler-starts-the-player-from-declared-values
  ;; The compiler emits the game's definition; play state lives in worlds.
  (let ((game (source-game-with-player '((:hp 4) (:max-hp 4)))))
    (is (contains-substring-p "\"values\":{\"hp\":4,\"max-hp\":4}"
                              (dunge-html:compile-game-script game)))))

(test built-room-entity-state-is-saved-and-reset
  (multiple-value-bind (game room)
      (plan-one-room nil
                     :zone :dungeon
                     :exits '((:back . "room"))
                     :options '((:entity
                                 :name "lever"
                                 :id "lever"
                                 :state ((:pulled nil))
                                 :body ((:action :label "Pull the lever"
                                         :do ((:set :target (:self :pulled)
                                                    :value t)))))))
    (let ((lever (gethash "lever" (dunge::scene-index room)))
          (session (make-runtime-session game :current-room (name room))))
      (run-session-script session (format nil "1~%"))
      (is (eq t (gethash :pulled (entity-state (world-of session) lever))))
      (is (find (name room) (getf (capture-runtime-state session) :locals)
                :key (lambda (entry) (getf entry :room))
                :test #'equal))
      (is (null (gethash :pulled (entity-state (make-world game) lever)))))))

(test crawler-used-slots-follow-inventory-rules
  ;; A dagger uses a slot, bulky mail two, a supply stack one however many,
  ;; and a purse with explicit :SLOTS 0 none; fatigue fills slots too.
  (let* ((catalog (item-catalog '((:item :rusted-dagger)
                                  (:item :mail :bulky t)
                                  (:supply :ration :count 3)
                                  (:item :coin-purse :slots 0))))
         (used (used-slots-expression catalog))
         (game (source-game-with-player
                '((:hp 4) (:max-hp 4) (:fatigue 2) (:deprived nil)
                  (:rusted-dagger 1) (:mail 1) (:ration 3) (:coin-purse 1))
                (ration-choice-form :used-slots used)))
         (context (test-context game))
         (ration (first (entities (first (game-rooms game))))))
    (is (equal '(:add (:player :fatigue)
                 (:mul 1 (:player :rusted-dagger))
                 (:mul 2 (:player :mail))
                 (:min 1 (:player :ration)))
               used))
    (is (= 6 (evaluate-expression (compile-dunge-source used) context)))
    ;; Rested, healthy, and not deprived: no ration.
    (setf (gethash :fatigue (player-of context)) 0)
    (is (not (available-p ration context)))
    ;; A full inventory counts as deprived.
    (setf (gethash :mail (player-of context)) 4)
    (is (= 10 (evaluate-expression (compile-dunge-source used) context)))
    (is (available-p ration context))))

(test crawler-ration-choice-recovers-and-consumes
  (let* ((game (source-game-with-player
                '((:hp 2) (:max-hp 4) (:fatigue 2) (:deprived t) (:ration 2))
                (ration-choice-form)))
         (context (test-context game))
         (state (player-of context))
         (ration (first (entities (first (game-rooms game))))))
    (is (available-p ration context))
    (with-output-to-string (*output*)
      (execute-effect (target ration) context))
    (is (= 3 (gethash :hp state)))
    (is (= 1 (gethash :fatigue state)))
    (is (null (gethash :deprived state)))
    (is (= 1 (gethash :ration state)))
    (setf (gethash :hp state) 4
          (gethash :fatigue state) 0)
    (is (not (available-p ration context)))
    (setf (gethash :hp state) 1
          (gethash :ration state) 0)
    (is (not (available-p ration context)))))

(test validating-a-game-leaves-play-state-alone
  (let* ((game (build-save-load-fixture))
         (session (make-runtime-session game)))
    (run-session-script session (format nil "2~%1~%2~%"))
    (let ((before (capture-runtime-state session)))
      (validate-game game)
      (is (equal before (capture-runtime-state session)))
      ;; A new world starts over; the session's world is untouched.
      (is (= 0 (gethash :visits (globals-of (make-world game)))))
      (is (= 1 (gethash :visits (globals-of session)))))))

(test worlds-restore-location-and-roll-tables-in-the-given-world
  (let* ((game (build-save-load-fixture))
         (session (make-runtime-session game)))
    (run-session-script session (format nil "2~%1~%2~%"))
    (let ((world (plist->world game (capture-runtime-state session))))
      (is (equal "notes" (name (world-location world))))
      ;; A session over a restored world starts where the world is.
      (is (equal "notes" (runtime-session-current-room-name
                          (make-runtime-session game :world world))))))
  (let* ((game (build-seeded-table-fixture 5))
         (context (test-context game))
         (other (make-world game)))
    (roll-table game :weighted :world other :context context)
    (is (= 1 (length (world-rolls other))))
    (is (null (world-rolls (runtime-context-world context))))))

(test undo-copies-leave-the-world-independent
  (let* ((game (source-game-with-player '((:hp 4))))
         (world (make-world game))
         (copy (copy-world world)))
    (setf (gethash :hp (player-of world)) 1)
    (is (= 4 (gethash :hp (player-of copy))))
    (dunge::restore-world-contents world copy)
    (is (= 4 (gethash :hp (player-of world))))))

(test runtime-state-captures-and-restores-player-state
  (let* ((game (source-game-with-player *mara-player*))
         (session (make-runtime-session game)))
    (setf (gethash :hp (player-of session)) 2
          (gethash :ration (player-of session)) 1)
    (let* ((state (capture-runtime-state session))
           (fresh-game (source-game-with-player *mara-player*)))
      (is (equal '(:hp . 2) (assoc :hp (getf state :player))))
      (let ((restored (restore-runtime-state fresh-game state)))
        (is (= 2 (gethash :hp (player-of restored))))
        (is (= 4 (gethash :max-hp (player-of restored))))
        (is (= 1 (gethash :ration (player-of restored)))))
      (setf (getf state :player) '((:mana . 3)))
      (signals error
        (restore-runtime-state (source-game-with-player *mara-player*)
                               state)))))

(defun built-game (player builder &rest body)
  "Build a game whose start room holds BODY, planning rooms with BUILDER."
  (build-game `(:game
                :start "room"
                :player ,player
                :rooms ((:room :id "room" :body ,body)))
              :builder builder))

(defun plan-one-room (player &rest plan-arguments)
  "Build a game with one planned room. Return the game and that room."
  (let (plan)
    (let ((game (built-game player
                            (lambda (build)
                              (setf plan (apply #'create-generated-room
                                                build plan-arguments))))))
      (values game (dunge::find-room game (room-plan-id plan))))))

(defun encounter-entity (room)
  (gethash "encounter" (dunge::scene-index room)))

(defun encounter-value (thing room key)
  "The encounter in ROOM's KEY, in the world THING plays in."
  (gethash key (entity-state (world-of thing) (encounter-entity room))))

(defun shadow-room-game (&key (player '((:hp 4) (:max-hp 4) (:armor 1)))
                              (hp 1) (damage 1) options encounter-options)
  "A game whose planned room holds a watchful shadow."
  (let ((results '((:encounter :watchful-shadow :reaction :uncertain))))
    (plan-one-room player
                   :zone :dungeon
                   :title "Shadowed Room"
                   :results results
                   :exits '((:back . "room"))
                   :options options
                   :encounter (encounter-spec
                               (first (table-result-encounters results))
                               :hp hp
                               :damage damage)
                   :encounter-options encounter-options)))

(test encounters-are-entities-whose-state-is-saved
  (multiple-value-bind (game room) (shadow-room-game :hp 5 :damage 2)
    (is (equal '(:enemy :watchful-shadow :hp 5 :max-hp 5 :armor 0 :damage 2)
               (encounter-spec '(:encounter :watchful-shadow)
                               :hp 5 :damage 2)))
    (is (equal "Watchful Shadow" (name (encounter-entity room))))
    (let* ((session (make-runtime-session game :current-room (name room)))
           (state (progn
                    (is (eq :active (encounter-value session room :status)))
                    (is (= 5 (encounter-value session room :hp)))
                    (setf (gethash :hp (entity-state (world-of session)
                                                     (encounter-entity room)))
                          3)
                    (capture-runtime-state session))))
      (is (find (name room) (getf state :locals)
                :key (lambda (entry) (getf entry :room))
                :test #'equal))
      (multiple-value-bind (fresh-game fresh-room)
          (shadow-room-game :hp 5 :damage 2)
        (let ((restored-session (restore-runtime-state fresh-game state)))
          (is (equal (name room)
                     (runtime-session-current-room-name restored-session)))
          (is (= 3 (encounter-value restored-session fresh-room :hp)))
          (is (eq :active (encounter-value restored-session fresh-room :status))))))))

(test encounter-specs-are-validated
  (signals error (encounter-spec '(:encounter :shade) :hp 5 :max-hp 2))
  (signals error (encounter-spec '(:encounter :shade) :damage -1))
  (signals error (encounter-spec '(:encounter :shade) :damage "2x6"))
  (is (equal "1d4" (getf (encounter-spec '(:encounter :shade) :damage "1d4")
                         :damage)))
  (signals dunge-source-error (source-node '(:generated-exits))))

(test encounter-attack-and-flee-update-entity-state
  (multiple-value-bind (game room) (shadow-room-game :hp 1)
    (let ((session (make-runtime-session game :current-room (name room))))
      (multiple-value-bind (output result)
          (run-session-script session (format nil "1~%1~%"))
        (declare (ignore result))
        ;; Any roll beats 1 HP and no armor.
        (is (contains-substring-p "Watchful Shadow falls." output))
        (is (eq :defeated (encounter-value session room :status)))
        (is (= 0 (encounter-value session room :hp)))
        (is (= 1 (encounter-value session room :round)))
        (is (<= 1 (encounter-value session room :dealt) 6)))))
  (multiple-value-bind (game room) (shadow-room-game :hp 3)
    (let ((session (make-runtime-session game :current-room (name room))))
      (multiple-value-bind (output result)
          (run-session-script session (format nil "2~%1~%"))
        (is (contains-substring-p "You escape from Watchful Shadow." output))
        (is (contains-substring-p "Encounter: Watchful Shadow (escaped, HP 3/3)."
                                  output))
        (is (equal "room" (name result)))
        (is (eq :escaped (encounter-value session room :status)))
        (is (= 1 (encounter-value session room :round)))))))

(test generated-room-active-encounter-renders-combat-choices
  (multiple-value-bind (game room) (shadow-room-game)
    (let ((session (make-runtime-session game :current-room (name room))))
      (multiple-value-bind (output result)
          (run-session-script session (format nil "1~%1~%"))
        (is (equal "room" (name result)))
        (is (contains-substring-p "Encounter: Watchful Shadow" output))
        (is (contains-substring-p "1. Attack watchful shadow" output))
        (is (contains-substring-p "Watchful Shadow falls." output))
        (is (contains-substring-p "1. Return" output))
        (is (eq :defeated (encounter-value session room :status)))))))

(test generated-room-active-encounter-allows-ration-use
  (multiple-value-bind (game room)
      (shadow-room-game :player '((:hp 3) (:max-hp 4) (:armor 0)
                                  (:fatigue 0) (:deprived nil) (:ration 1))
                        :encounter-options (list (ration-choice-form)))
    (let ((session (make-runtime-session game :current-room (name room))))
      (multiple-value-bind (output result)
          (run-session-script session (format nil "2~%1~%1~%"))
        (is (equal "room" (name result)))
        (is (contains-substring-p "2. Eat ration" output))
        (is (contains-substring-p "3. Flee" output))
        (is (contains-substring-p "You eat a ration and recover." output))
        (is (= 4 (gethash :hp (player-of session))))
        (is (= 0 (gethash :ration (player-of session))))
        (is (eq :defeated (encounter-value session room :status)))))))

(test generated-room-loot-choices-are-taken-once-and-saved
  (flet ((looted-room ()
           (plan-one-room '((:hp 4) (:gold 0) (:ration 0))
                          :zone :dungeon
                          :title "Looted Room"
                          :results '((:supply :ration)
                                     (:gold 3)
                                     (:room-detail :old-bones))
                          :exits '((:back . "room")))))
    (multiple-value-bind (game room) (looted-room)
      (let ((session (make-runtime-session game :current-room (name room))))
        (multiple-value-bind (output result)
            (run-session-script session (format nil "1~%1~%1~%"))
          (is (equal "room" (name result)))
          (is (contains-substring-p "Room Detail: Old Bones." output))
          (is (contains-substring-p "1. Take ration" output))
          (is (contains-substring-p "You take ration." output))
          (is (contains-substring-p "1. Take 3 gold" output))
          (is (contains-substring-p "You take 3 gold." output))
          (is (= 1 (gethash :ration (player-of session))))
          (is (= 3 (gethash :gold (player-of session)))))
        (let ((state (capture-runtime-state session)))
          (multiple-value-bind (fresh-game fresh-room) (looted-room)
            (multiple-value-bind (output result)
                (run-session-script
                 (make-runtime-session fresh-game
                                       :current-room (name fresh-room)
                                       :world (plist->world fresh-game state))
                 (format nil "1~%"))
              (is (equal "room" (name result)))
              (is (not (contains-substring-p "Take ration" output)))
              (is (not (contains-substring-p "Take 3 gold" output)))
              (is (contains-substring-p "1. Return" output)))))))))

(test generated-room-ration-use-recovers-in-exploration
  (multiple-value-bind (game room)
      (plan-one-room '((:hp 2) (:max-hp 3) (:fatigue 1) (:deprived t) (:ration 2))
                     :zone :dungeon
                     :title "Quiet Room"
                     :exits '((:back . "room"))
                     :options (list (ration-choice-form)))
    (let* ((session (make-runtime-session game :current-room (name room)))
           (state (player-of session)))
      (multiple-value-bind (output result)
          (run-session-script session (format nil "1~%1~%"))
        (is (equal "room" (name result)))
        (is (contains-substring-p "1. Eat ration" output))
        (is (contains-substring-p "You eat a ration and recover." output))
        (is (= 3 (gethash :hp state)))
        (is (= 0 (gethash :fatigue state)))
        (is (null (gethash :deprived state)))
        (is (= 1 (gethash :ration state)))))))

(test planned-rooms-become-ordinary-rooms
  (multiple-value-bind (game room)
      (plan-one-room nil
                     :zone :dungeon
                     :title "Flooded Guardroom"
                     :description "Cold water covers the floor."
                     :results '((:room-detail :flooded-floor)
                                (:loot :minor))
                     :exits '((:back . "room")))
    (is (eq 'room (type-of room)))
    (is (equal "generated:dungeon:1" (name room)))
    (is (member room (game-rooms game)))
    (is (equal '(p p p choice) (mapcar #'type-of (entities room))))
    (multiple-value-bind (output result)
        (run-session-script (make-runtime-session game :current-room (name room))
                            (format nil "1~%"))
      (is (contains-substring-p "Flooded Guardroom" output))
      (is (contains-substring-p "Cold water covers the floor." output))
      (is (contains-substring-p "Room Detail: Flooded Floor." output))
      (is (contains-substring-p "Loot: Minor." output))
      (is (contains-substring-p "1. Return" output))
      (is (equal "room" (name result))))))

(test planned-rooms-replace-authored-rooms-by-id
  (let ((game (built-game nil
                          (lambda (build)
                            (create-generated-room build
                                                   :id "vault"
                                                   :title "Planned Vault"
                                                   :exits '((:back . "room"))))
                          '(:choice "Enter the vault" (:go "vault")))))
    (is (equal '("room" "vault") (mapcar #'name (game-rooms game)))))
  (let ((game (build-game
               '(:game
                 :start "room"
                 :rooms ((:room :id "room" :body ((:choice "Vault" (:go "vault"))))
                         (:room :id "vault" :title "Authored Vault" :body ())))
               :builder (lambda (build)
                          (create-generated-room build
                                                 :id "vault"
                                                 :title "Planned Vault")))))
    (is (equal "Planned Vault"
               (room-title (dunge::find-room game "vault"))))
    (is (= 2 (length (game-rooms game))))))

(test build-game-uses-its-own-dice-and-sets-initial-values
  (let* ((rolled nil)
         (game (build-game
                '(:game
                  :start "room"
                  :seed 42
                  :state ((:depth 0))
                  :flags (:ready)
                  :player ((:hp 1))
                  :rooms ((:room :id "room" :body ((:p "A room.")))))
                :builder (lambda (build)
                           (setf rolled (build-roll-dice build "1d100"))
                           (set-player build '((:hp 7)))
                           (set-initial-global build :depth 3)
                           (set-initial-global build :ready t)))))
    ;; Play starts from the seed with an empty roll log.
    (let ((world (make-world game)))
      (is (= 42 (world-rng-state world)))
      (is (null (world-rolls world)))
      (is (= 7 (gethash :hp (player-of world))))
      (is (= 3 (gethash :depth (globals-of world))))
      (is (eq t (gethash :ready (globals-of world))))
      ;; The build's first roll is not play's first roll.
      (is (/= rolled (roll-dice world "1d100"))))
    (signals error
      (build-game '(:game :start "room" :rooms ((:room :id "room" :body ())))
                  :builder (lambda (build)
                             (set-initial-global build :undeclared 1))))))

(test planned-rooms-keep-order-ids-and-empty-players
  ;; A replacement keeps its authored room's place, so an inferred start
  ;; room stays the same.
  (let ((game (build-game
               '(:game
                 :player ((:hp 3))
                 :rooms ((:room :id "hall" :body ((:choice "Go" (:go "yard"))))
                         (:room :id "yard" :body ((:choice "Back" (:go "hall"))))))
               :builder (lambda (build)
                          (create-generated-room build
                                                 :id "hall"
                                                 :title "Planned Hall"
                                                 :exits '((:out . "yard")))
                          (set-player build nil)))))
    (is (equal '("hall" "yard") (mapcar #'name (game-rooms game))))
    (is (equal "hall" (game-start game)))
    (is (null (game-player-state-declarations game))))
  ;; Automatic ids skip ids already planned explicitly.
  (built-game nil
              (lambda (build)
                (create-generated-room build :id "generated:dungeon:1")
                (is (equal "generated:dungeon:2"
                           (room-plan-id
                            (create-generated-room build :zone :dungeon)))))))

(test planned-room-ids-and-links
  (let ((plans nil))
    (built-game nil
                (lambda (build)
                  (let* ((entry (create-generated-room build :zone :dungeon))
                         (deeper (create-generated-room build :zone :dungeon))
                         (named (create-generated-room build :id "vault")))
                    (setf plans (list entry deeper named))
                    (is (equal '("generated:dungeon:1" "generated:dungeon:2" "vault")
                               (mapcar #'room-plan-id plans)))
                    (signals error (create-generated-room build :id "vault"))
                    (is (null (room-plan-exit entry :deeper)))
                    (link-rooms entry :deeper deeper :reverse-direction :back)
                    (is (equal (room-plan-id deeper) (room-plan-exit entry :deeper)))
                    (is (equal (room-plan-id entry) (room-plan-exit deeper :back)))
                    (set-room-plan-exit entry :deeper "room")
                    (is (equal "room" (room-plan-exit entry :deeper)))
                    (is (= 1 (count :deeper (room-plan-exits entry) :key #'car)))
                    (signals error (set-room-plan-exit entry "north" "room"))
                    ;; A failed link leaves both plans alone.
                    (signals error
                      (link-rooms named :north deeper :reverse-direction "south"))
                    (signals error
                      (link-rooms named :north "room" :reverse-direction :south))
                    (is (null (room-plan-exits named)))
                    (set-room-plan-exit entry :deeper deeper))))
    (is (= 3 (length plans)))))

(test console-debug-undo-restores-previous-choice-state
  (let* ((game (build-save-load-fixture))
         (session (make-runtime-session game)))
    (multiple-value-bind (output result)
        (run-session-script session (format nil "2~%4~%4~%") :debug t)
      (is (typep result 'quit))
      (is (contains-substring-p "4. Undo" output))
      (is (= 2 (substring-count "Find clue" output)))
      (let ((context (test-context game :world (world-of session))))
        (is (not (state-value (source-state :global :clue) context)))
        (is (= 0 (state-value (source-state :global :visits) context)))
        (is (not (gethash :find-clue (world-taken (world-of session)))))))))

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
                              (test-context fresh-game
                                            :world (world-of loaded-session))))))
      (when (probe-file path)
        (delete-file path)))))

(test runtime-state-validation-rejects-malformed-session-input
  (let ((game (build-save-load-fixture)))
    (is (contains-substring-p
         "return stack must be a proper, non-circular list"
         (error-message-from
          (lambda ()
            (make-runtime-session game :return-stack "start")))))
    (is (contains-substring-p
         "return stack entry must be a string"
         (error-message-from
          (lambda ()
            (make-runtime-session game :return-stack '(42))))))
    (let ((state (list :current-room "start" :globals nil)))
      (setf (cddr state) state)
      (is (contains-substring-p
           "state must be a proper property list"
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

(test dice-expressions-parse-and-reject-malformed-input
  (is (equal '(:expression "2d6+3" :count 2 :sides 6 :modifier 3)
             (parse-dice-expression "2d6+3")))
  (is (equal '(:expression "d8-1" :count 1 :sides 8 :modifier -1)
             (parse-dice-expression " d8-1 ")))
  (signals error
    (parse-dice-expression ""))
  (signals error
    (parse-dice-expression "2d"))
  (signals error
    (parse-dice-expression "0d6"))
  (signals error
    (parse-dice-expression "1d0"))
  (signals error
    (parse-dice-expression "1d6+bad")))

(test dice-rolls-use-game-seed-and-record-roll-log
  (let ((first-world (make-world (source-game-with-seeded-tables 314 nil)))
        (second-world (make-world (source-game-with-seeded-tables 314 nil))))
    (is (equal (loop repeat 3
                     collect (roll-dice first-world "1d6" :label :test-die))
               (loop repeat 3
                     collect (roll-dice second-world "1d6" :label :test-die))))
    (is (= 3 (length (world-rolls first-world))))
    (let ((entry (first (world-rolls first-world))))
      (is (equal "1d6" (getf entry :dice)))
      (is (= 1 (getf entry :count)))
      (is (= 6 (getf entry :sides)))
      (is (equal :test-die (getf entry :label)))
      (is (equal (first (getf entry :rolls))
                 (getf entry :result)))))
  (let ((world (make-world (source-game-with-seeded-tables 1 nil))))
    (multiple-value-bind (value record)
        (roll-dice-value world 6 :label :static-value)
      (is (= 6 value))
      (is (null record))
      (is (null (world-rolls world))))))

(test table-result-resolvers-normalize-amounts
  (let* ((world (make-world (source-game-with-body)))
         (resolved (resolve-table-result-data
                    world
                    '((:gold "1d6")
                      (:supply :ration :count "1d4")
                      (:item :chalk :slots 0)
                      (:room-detail :flooded-floor)))))
    (is (= 2 (length (world-rolls world))))
    (is (equal '(:result-gold :result-count)
               (mapcar (lambda (entry)
                         (getf entry :label))
                       (world-rolls world))))
    (let ((gold (second (first resolved)))
          (ration-count (getf (second resolved) :count)))
      (is (<= 1 gold 6))
      (is (<= 1 ration-count 4))
      (is (equal '(:item :chalk :slots 0) (third resolved)))
      (is (equal (list (first resolved)
                       (second resolved)
                       (third resolved))
                 (table-result-loot-results resolved))))))

(test table-result-resolvers-extract-exits-and-reject-bad-shapes
  (let ((game (source-game-with-body)))
    (is (equal '((:north . "generated:dungeon:2")
                 (:back . "room"))
               (table-result-exits
                (resolve-table-result-data
                 game
                 '((:exit :north "generated:dungeon:2")
                   (:room-detail :flooded-floor)
                   (:exit :back "room"))))))
    (is (contains-substring-p
         "Gold table result must be (:GOLD AMOUNT)"
         (error-message-from
          (lambda ()
            (resolve-table-result-data game '(:gold))))))
    (is (contains-substring-p
         "Exit table result must be (:EXIT DIRECTION ROOM-ID)"
         (error-message-from
          (lambda ()
            (resolve-table-result-data game '(:exit :north))))))
    (signals error
      (resolve-table-result-data game '(:item :torch :count 0)))))

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
    (is (eq :first (roll-table game :ordered :context context)))
    (is (eq :second (roll-table game :ordered :context context)))
    (is (eq :second (roll-table game :ordered :context context)))
    (is (eq :rolled (roll-table game :roll-result :context context)))
    (is (equal '(:gold :inner-result)
               (roll-table game :bundle :context context)))))

(test deck-table-draws-without-replacement-before-reshuffling
  (let* ((game
           (source-game-with-tables
            '((:table
               :id :deck
               :mode :deck
               :entries
               ((:table-entry :result :first)
                (:table-entry :result :second))))))
         (world (make-world game))
         (first-two (list (roll-table game :deck :world world)
                          (roll-table game :deck :world world)))
         (third (roll-table game :deck :world world)))
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
         (session (make-runtime-session game))
         (world (world-of session)))
    (is (eq :first (roll-table game :ordered :world world)))
    (is (eq :second (roll-table game :ordered :world world)))
    (let* ((deck-first (roll-table game :deck :world world))
           (state (capture-runtime-state session))
           (fresh-game (build-table-state-fixture))
           (fresh-world (world-of (restore-runtime-state fresh-game state))))
      (is (eq :third (roll-table fresh-game :ordered :world fresh-world)))
      (let ((deck-next (roll-table fresh-game :deck :world fresh-world)))
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
  (let* ((first-game (build-seeded-table-fixture 314))
         (first-world (make-world first-game))
         (second-game (build-seeded-table-fixture 314))
         (second-world (make-world second-game)))
    (is (= 314 (game-random-seed first-game)))
    (let ((first-results
            (loop repeat 5
                  collect (roll-table first-game :weighted :world first-world)))
          (second-results
            (loop repeat 5
                  collect (roll-table second-game :weighted :world second-world))))
      (is (equal first-results second-results)))
    (is (= 5 (length (world-rolls first-world)))))
  (let* ((game (build-seeded-table-fixture 9))
         (world (make-world game)))
    (is (eq :only (roll-table game :certain-roll :world world)))
    (is (equal (list (list :table :certain-roll
                           :mode :roll
                           :entry 0
                           :roll 1
                           :die 1
                           :result :only))
               (world-rolls world))))
  (let* ((game (build-seeded-table-fixture 9))
         (world (make-world game)))
    (is (eq :first (roll-table game :ordered :world world)))
    (is (eq :second (roll-table game :ordered :world world)))
    (is (equal '(:first :second)
               (mapcar (lambda (entry)
                         (getf entry :result))
                       (world-rolls world))))
    (is (equal '(0 1)
               (mapcar (lambda (entry)
                         (getf entry :entry))
                       (world-rolls world))))))

(test game-seed-must-be-non-negative
  (signals error
    (source-game-with-seeded-tables
     -1
     nil)))

(test runtime-state-captures-and-restores-rng-state-and-roll-log
  (let* ((game (build-seeded-table-fixture 123))
         (session (make-runtime-session game)))
    (roll-table game :weighted :world (world-of session))
    (let* ((state (capture-runtime-state session))
           (expected-next (roll-table game :weighted :world (world-of session)))
           (fresh-game (build-seeded-table-fixture 123))
           (fresh-world (world-of (restore-runtime-state fresh-game state))))
      (is (getf state :rng-state))
      (is (= 1 (length (getf state :roll-log))))
      (is (= 1 (length (world-rolls fresh-world))))
      (is (eq expected-next (roll-table fresh-game :weighted :world fresh-world)))
      (is (= 2 (length (world-rolls fresh-world)))))))

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
                   (evaluate-session
                    (make-runtime-session game :world (test-world game))))))
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
              :id "panel"
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
              :id "panel"
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
    ;; Rooms link their actions to owners when they are made.
    (is (eq panel (action-owner (first (entities panel)))))
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
  ;; Built rooms are ordinary rooms, so generated ids get no exemption.
  (signals error
    (source-game-with-body
     '(:choice "Generated room" (:go "generated:dungeon:1"))))
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

(test validator-requires-ids-on-stateful-entities
  (let ((message (error-message-from
                  (lambda ()
                    (source-game-with-body
                     '(:entity :name "lamp" :state ((:lit nil))))))))
    (is (search "Entity \"lamp\" declares :STATE but has no :ID" message)))
  ;; Room files check the rule on their own, before game validation.
  (signals error
    (source-node
     '(:room
       :id "room"
       :body ((:entity :name "lamp" :state ((:lit nil)))))))
  ;; Entities without state do not need an id.
  (is (typep (source-game-with-body
              '(:entity :name "rug" :body ((:p "A worn rug."))))
             'game)))

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
                    :value t)))
           nil)))))
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
        (control-panel (dunge-examples:load-control-panel-example))
        (adaptation (dunge-examples:load-adaptation-example)))
    (is (typep basic 'game))
    (is (equal '("entrance" "hallway")
               (mapcar #'name (game-rooms basic))))
    (is (typep control-panel 'game))
    (is (equal '("hallway" "hidden room")
               (mapcar #'name (game-rooms control-panel))))
    (is (typep adaptation 'game))
    (is (equal '("camp" "threshold" "placeholder-room")
               (mapcar #'name (game-rooms adaptation))))))

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

(test adaptation-example-scripted-transcript
  (let ((output (run-example-with-input #'dunge-examples:adaptation-example
                                        (format nil "1~%1~%2~%1~%2~%"))))
    (is (contains-substring-p "Dunge Crawler Testbed" output))
    (is (contains-substring-p "The first generated chamber waits in the run log."
                              output))
    (is (contains-substring-p "A first find waits here" output))
    (is (contains-substring-p "Encounter: Watchful Shadow" output))
    (is (contains-substring-p "You escape from Watchful Shadow." output))
    (is (contains-substring-p "You take chalk." output))
    (is (contains-substring-p "This chamber sits at depth 2" output))
    (is (not (contains-substring-p "Placeholder Chamber" output)))))

(defun build-adaptation-recording-scratch (&rest arguments)
  "Build the adaptation game; return it and the scratch game the build used."
  (let (scratch)
    (values (build-game (read-dunge-file (dunge-examples::adaptation-source-path))
                        :base-path (dunge-examples::adaptation-source-path)
                        :builder (lambda (build)
                                   (setf scratch (build-world build))
                                   (apply #'dunge-examples:build-adaptation
                                          build arguments)))
            scratch)))

(test adaptation-build-rolls-a-player-and-a-dungeon-before-play
  (multiple-value-bind (game scratch) (build-adaptation-recording-scratch)
    ;; The build rolled the player, then the rooms, on its own stream.
    (is (equal '(:adaptation-str :adaptation-dex :adaptation-wil
                 :adaptation-hp :adaptation-gold)
               (remove nil (mapcar (lambda (entry) (getf entry :label))
                                   (world-rolls scratch)))))
    (is (equal '(:room-segment :starter-loot :starter-encounter :starter-exit
                 :dungeon-link :room-segment :starter-loot :starter-encounter)
               (remove nil (mapcar (lambda (entry) (getf entry :table))
                                   (world-rolls scratch)))))
    ;; Play starts from the seed with an empty roll log.
    (is (= (game-random-seed game) (world-rng-state (make-world game))))
    (is (null (world-rolls (make-world game))))
    ;; The first chamber replaced the authored placeholder by id.
    (is (equal '("camp" "threshold" "placeholder-room" "generated:dungeon:1")
               (mapcar #'name (game-rooms game))))
    (let ((first-room (dunge::find-room game "placeholder-room"))
          (deeper-room (dunge::find-room game "generated:dungeon:1")))
      (is (not (equal "Placeholder Chamber" (room-title first-room))))
      (is (eq :active (encounter-value (make-world game) first-room :status)))
      (is (eq :active (encounter-value (make-world game) deeper-room :status))))
    ;; Initial values replace direct state writes.
    (let ((world (make-world game)))
      (is (= 2 (gethash :rooms-generated (globals-of world))))
      (is (= 2 (gethash :dungeon-depth (globals-of world))))
      (is (eq t (gethash :first-room-generated (globals-of world))))
      (is (equal "Generated Delver" (gethash :name (player-of world))))
      (is (= 2 (gethash :ration (player-of world))))
      (is (= 0 (gethash :chalk (player-of world)))))))

(test adaptation-character-creation-uses-dice-and-starting-gear
  (let* ((game (dunge-examples:load-instanced-adaptation-example
                :name "Nia" :background :delver))
         (player (player-of (make-world game))))
    (flet ((stat (key) (gethash key player)))
      (is (equal "Nia" (stat :name)))
      (is (eq :delver (stat :background)))
      (is (<= 5 (stat :str) 15))
      (is (<= 5 (stat :dex) 15))
      (is (<= 5 (stat :wil) 15))
      (is (<= 1 (stat :hp) 6))
      (is (= (stat :hp) (stat :max-hp)))
      (is (<= 1 (stat :gold) 6))
      (is (= 1 (stat :armor)))
      (is (= 1 (stat :rusted-dagger)))
      (is (= 1 (stat :lantern)))
      (is (= 1 (stat :ration)))
      (is (= 0 (stat :chalk))))))

(test adaptation-play-state-survives-save-and-restore
  (let* ((game (dunge-examples:load-instanced-adaptation-example :seed 1))
         (session (make-runtime-session game)))
    ;; Approach, enter, attack twice, take the loot.
    (run-session-script session (format nil "1~%1~%1~%1~%1~%"))
    (let* ((state (capture-runtime-state session))
           (fresh-game (dunge-examples:load-instanced-adaptation-example :seed 1))
           (restored-session (restore-runtime-state fresh-game state))
           (room (dunge::find-room fresh-game "placeholder-room")))
      (is (equal "placeholder-room"
                 (runtime-session-current-room-name restored-session)))
      (is (eq :defeated (encounter-value restored-session room :status)))
      (is (equal (gethash :ration (player-of session))
                 (gethash :ration (player-of restored-session))))
      (is (equal (sorted-keywords
                  (loop for key being the hash-keys of (world-taken (world-of session))
                        collect key))
                 (sorted-keywords
                  (loop for key being the hash-keys
                          of (world-taken (world-of restored-session))
                        collect key)))))))

(test adaptation-browser-demo-writes-repeatable-html-target
  (let ((path (merge-pathnames
               (format nil "adaptation-demo-~A/index.html" (gensym))
               (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (is (equal path
                      (dunge-examples:write-adaptation-browser-demo
                       :pathname path
                       :debug t)))
           (let ((contents (uiop:read-file-string path)))
             (is (contains-substring-p "Dunge Adaptation Testbed" contents))
             (is (contains-substring-p
                  "window.DUNGE_GAME_DEBUG = true"
                  contents))
             (is (contains-substring-p
                  "{\"type\":\"room\",\"id\":\"placeholder-room\""
                  contents))
             (is (contains-substring-p
                  "\"rooms-generated\":2"
                  contents))
             (is (contains-substring-p
                  "\"Enter the generated chamber\""
                  contents))
             (is (contains-substring-p
                  "\"value\":\"generated:dungeon:1\""
                  contents))
             (is (contains-substring-p
                  "\"id\":\"generated:dungeon:1\""
                  contents))
             (is (not (contains-substring-p
                       "id='dunge-status'"
                       contents)))
             (is (not (contains-substring-p
                       "renderStatusPanel"
                       contents)))))
      (let ((directory (uiop:pathname-directory-pathname path)))
        (when (probe-file directory)
          (uiop:delete-directory-tree directory :validate t))))))

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
    (is (not (contains-substring-p "id='dunge-status'" html)))
    (is (not (contains-substring-p "dunge-status-section" html)))
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
    ;; All play data lives in one world object that saves and undo copy.
    (is (contains-substring-p "WORLD.taken[" script))
    (is (contains-substring-p "'world' : copyJsonValue(WORLD)" script))
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
    (is (not (contains-substring-p "node.stateData" script)))
    (is (contains-substring-p "window.localStorage.setItem" script))
    (is (contains-substring-p "currentRoom" script))
    (is (not (contains-substring-p "takenChoices" script)))
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
  (let ((script (dunge-html:compile-game-script
                 (source-game-with-player
                  '((:name "Mara") (:background :soldier) (:hp 4) (:ration 2))
                  '(:choice "Eat" (:dec :target (:player :ration)))))))
    (is (contains-substring-p
         "\"player\":{\"keys\":[\"name\",\"background\",\"hp\",\"ration\"],\"values\":{\"name\":\"Mara\",\"background\":{\"type\":\"keyword\",\"name\":\"soldier\"},\"hp\":4,\"ration\":2}}"
         script))
    (is (contains-substring-p
         "\"target\":{\"type\":\"state\",\"scope\":\"player\",\"role\":null,\"key\":\"ration\"}"
         script))
    (is (contains-substring-p "'player' : initialState(GAME.player)" script))
    (is (not (contains-substring-p "inventory" script)))
    (is (not (contains-substring-p "function playerCanUseRationP" script)))))

(test html-compiler-lowers-encounters-as-entities
  (let ((script (dunge-html:compile-game-script (shadow-room-game :damage "1d4"))))
    (is (contains-substring-p "{\"type\":\"entity\",\"id\":\"encounter\",\"name\":\"Watchful Shadow\""
                              script))
    (is (contains-substring-p "\"keys\":[\"status\",\"hp\",\"max-hp\",\"armor\",\"dealt\",\"taken\",\"round\"]"
                              script))
    (is (contains-substring-p "{\"type\":\"roll\",\"dice\":\"1d4\",\"count\":1,\"sides\":4,\"modifier\":0,\"label\":\"enemy-damage\"}"
                              script))
    (is (contains-substring-p "\"label\":\"Attack watchful shadow\"" script))
    (is (contains-substring-p "\"label\":\"Return\"" script))
    (is (not (contains-substring-p "\"encounters\"" script)))
    (is (not (contains-substring-p "function attackEncounter" script)))))

(test html-compiler-lowers-built-rooms-as-ordinary-rooms
  (let ((script (dunge-html:compile-game-script
                 (dunge-examples:load-instanced-adaptation-example))))
    (is (contains-substring-p "{\"type\":\"room\",\"id\":\"generated:dungeon:1\""
                              script))
    (is (contains-substring-p "\"rooms-generated\":2" script))
    (is (contains-substring-p "\"dungeon-depth\":2" script))
    (is (contains-substring-p "\"first-room-generated\":true" script))
    ;; The body is ordinary content: paragraphs, choices, and an encounter.
    (is (contains-substring-p "\"label\":\"Eat ration\"" script))
    (is (contains-substring-p "\"label\":\"Attack watchful shadow\"" script))
    (is (contains-substring-p "{\"type\":\"choice\",\"label\":\"Continue deeper\",\"target\":{\"type\":\"goto\",\"room\":{\"type\":\"literal\",\"value\":\"generated:dungeon:1\"}}"
                              script))
    (is (not (contains-substring-p "generated-room" script)))
    (is (not (contains-substring-p "generatedRooms" script)))
    (is (not (contains-substring-p "\"exits\"" script)))))

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

(test html-compiler-output-depends-only-on-the-definition
  (let ((game (dunge-examples:load-instanced-adaptation-example)))
    (is (string= (dunge-html:compile-game-script game)
                 (dunge-html:compile-game-script game)))))

(test html-backend-uses-only-the-ast-protocol
  ;; The browser backend reads the AST only through DUNGE.AST: no DUNGE: or
  ;; DUNGE:: reference, in any case. (DUNGE.AST: does not contain "dunge:".)
  (dolist (file '("src/html-package.lisp" "src/html.lisp"))
    (is (not (search "dunge:"
                     (uiop:read-file-string
                      (asdf:system-relative-pathname "dunge" file))
                     :test #'char-equal))
        "~A refers to DUNGE directly instead of DUNGE.AST." file)))

(test html-compiler-output-is-repeatable
  ;; site/check.sh checks reproducibility across fresh builds; this catches
  ;; nondeterminism within one image, such as hash-table ordering.
  (flet ((build ()
           (dunge-html:compile-index-html
            (dunge-examples:load-instanced-adaptation-example))))
    (is (string= (build) (build)))))

(test html-save-signature-covers-data-and-runtime
  (let ((signature (dunge-html::game-save-signature "{\"data\":1}" "runtime();")))
    (is (string/= signature
                  (dunge-html::game-save-signature "{\"data\":2}" "runtime();")))
    (is (string/= signature
                  (dunge-html::game-save-signature "{\"data\":1}" "runtime2();")))
    (is (string= signature
                 (dunge-html::game-save-signature "{\"data\":1}" "runtime();")))))
