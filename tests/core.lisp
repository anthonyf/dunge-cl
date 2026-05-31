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
     '(:player :conditions ("deprived"))))
  (signals error
    (source-game-with-player
     '(:player :inventory ((:gold 1)))))
  (signals error
    (source-game-with-player
     '(:player :inventory ((:item "dagger")))))
  (signals error
    (source-game-with-player
     '(:player :inventory ((:supply :ration :count 0)))))
  (signals error
    (source-game-with-player
     '(:player :inventory ((:item :rope :unknown t)))))
  (signals error
    (source-game-with-player
     '(:player :inventory ((:item :rope :tags ("gear")))))))

(test player-inventory-data-model-computes-slots-and-status
  (let* ((game
           (source-game-with-player
            '(:player
              :inventory ((:item :rusted-dagger)
                          (:item :mail :bulky t :tags (:armor))
                          (:supply :ration :count 3)
                          (:item :coin-purse :slots 0))
              :fatigue 2)))
         (player (game-player game))
         (dagger (first (player-inventory player)))
         (mail (second (player-inventory player)))
         (ration (third (player-inventory player)))
         (coin-purse (fourth (player-inventory player))))
    (is (eq :item (inventory-entry-kind dagger)))
    (is (eq :rusted-dagger (inventory-entry-id dagger)))
    (is (= 1 (inventory-entry-count dagger)))
    (is (= 1 (inventory-entry-slots dagger)))
    (is (inventory-entry-bulky-p mail))
    (is (= 2 (inventory-entry-slots mail)))
    (is (equal '(:armor) (inventory-entry-tags mail)))
    (is (= 3 (inventory-entry-count ration)))
    (is (= 1 (inventory-entry-slots ration)))
    (is (= 0 (inventory-entry-slots coin-purse)))
    (is (= 6 (player-inventory-used-slots player)))
    (is (= 4 (player-inventory-free-slots player)))
    (is (not (player-inventory-full-p player)))
    (is (not (player-deprived-p player)))
    (setf (player-fatigue player) 6)
    (is (player-inventory-full-p player))
    (is (player-deprived-p player))))

(test player-inventory-mutators-stack-and-remove-counted-entries
  (let ((player (make-instance 'player
                               :inventory '((:supply :ration :count 2)
                                            (:item :torch)))))
    (add-player-inventory-entry player '(:supply :ration) :count 3)
    (is (equal '((:supply :ration :count 5)
                 (:item :torch))
               (player-inventory player)))
    (add-player-inventory-entry player '(:item :torch))
    (is (= 2 (player-inventory-count player :item :torch)))
    (is (equal '(:item :torch :count 2)
               (find-player-inventory-entry player :item :torch)))
    (add-player-inventory-entry player '(:item :torch :condition :lit))
    (is (= 3 (player-inventory-count player :item :torch)))
    (is (equal '((:supply :ration :count 5)
                 (:item :torch :count 2)
                 (:item :torch :condition :lit))
               (player-inventory player)))
    (remove-player-inventory-entry player :supply :ration :count 4)
    (is (equal '((:supply :ration)
                 (:item :torch :count 2)
                 (:item :torch :condition :lit))
               (player-inventory player)))
    (remove-player-inventory-entry player :item :torch :count 2)
    (is (equal '((:supply :ration)
                 (:item :torch :condition :lit))
               (player-inventory player)))
    (signals error
      (remove-player-inventory-entry player :supply :ration :count 2))))

(test player-recovery-and-ration-use-mutates-state
  (let ((player (make-instance 'player
                               :hp 2
                               :max-hp 4
                               :inventory '((:supply :ration :count 2))
                               :fatigue 2
                               :conditions '(:deprived :poisoned))))
    (is (player-condition-p player :deprived))
    (recover-player player
                    :hp 5
                    :fatigue 1
                    :clear-conditions '(:deprived))
    (is (= 4 (player-hp player)))
    (is (= 1 (player-fatigue player)))
    (is (not (player-condition-p player :deprived)))
    (is (player-condition-p player :poisoned))
    (use-player-ration player)
    (is (= 1 (player-inventory-count player :supply :ration)))
    (is (= 0 (player-fatigue player)))))

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

(test runtime-state-rejects-malformed-player-inventory
  (let* ((game (source-game-with-player
                '(:player :name "Mara" :str 12 :hp 4)))
         (session (make-runtime-session game))
         (state (capture-runtime-state session))
         (player-state (copy-list (getf state :player))))
    (setf (getf player-state :inventory) '((:gold 1))
          (getf state :player) player-state)
    (signals error
      (restore-runtime-state (source-game-with-body) state))))

(test encounter-state-starts-from-table-results-and-round-trips-runtime-state
  (let* ((game (source-game-with-player
                '(:player :name "Mara" :hp 4 :armor 1)))
         (room (create-generated-room
                game
                :zone :dungeon
                :results '((:encounter :watchful-shadow
                             :reaction :uncertain))))
         (encounter-result (first (table-result-encounters
                                   (generated-room-results room))))
         (encounter (ensure-room-encounter-state
                     game
                     room
                     encounter-result
                     :hp 5
                     :str 8
                     :damage 2))
         (session (make-runtime-session game :current-room (name room)))
         (state (capture-runtime-state session)))
    (is (eq encounter (find-encounter-state game room)))
    (is (eq :watchful-shadow (encounter-enemy-id encounter)))
    (is (eq :uncertain (encounter-reaction encounter)))
    (is (= 5 (encounter-hp encounter)))
    (is (= 8 (encounter-str encounter)))
    (is (= 1 (length (getf state :encounters))))
    (let* ((fresh-game (source-game-with-body))
           (restored-session (restore-runtime-state fresh-game state))
           (restored-encounter (find-encounter-state
                                fresh-game
                                (name room)
                                :errorp t)))
      (is (equal (name room)
                 (runtime-session-current-room-name restored-session)))
      (is (eq :watchful-shadow
              (encounter-enemy-id restored-encounter)))
      (is (= 5 (encounter-hp restored-encounter)))
      (is (= 2 (encounter-damage restored-encounter)))
      (is (equal encounter-result
                 (encounter-source restored-encounter))))))

(test encounter-combat-attacks-and-flee-update-state
  (let* ((game (source-game-with-player
                '(:player :name "Mara" :hp 4 :armor 1)))
         (player (game-player game))
         (encounter (make-encounter-state
                     :room "room"
                     :enemy-id :watchful-shadow
                     :hp 3
                     :damage 2)))
    (register-encounter-state game encounter)
    (let ((result (attack-encounter game player encounter :damage 1)))
      (is (equal :attack (getf result :action)))
      (is (= 2 (encounter-hp encounter)))
      (is (= 3 (player-hp player)))
      (is (= 1 (encounter-round encounter)))
      (is (eq :active (encounter-status encounter))))
    (let ((result (attack-encounter game player encounter :damage 2)))
      (is (= 0 (encounter-hp encounter)))
      (is (= 3 (player-hp player)))
      (is (= 2 (encounter-round encounter)))
      (is (eq :defeated (getf result :status)))
      (is (eq :defeated (encounter-status encounter))))
    (let ((fleeing (make-encounter-state
                    :room "room"
                    :enemy-id :watchful-shadow)))
      (is (eq :escaped
              (getf (flee-encounter fleeing) :status)))
      (is (= 1 (encounter-round fleeing)))
      (is (encounter-finished-p fleeing)))))

(test generated-room-active-encounter-renders-combat-choices
  (let* ((game (source-game-with-player
                '(:player :name "Mara" :hp 4)))
         (room (create-generated-room
                game
                :zone :dungeon
                :title "Shadowed Room"
                :results '((:encounter :watchful-shadow))
                :exits '((:back . "room"))))
         (encounter (ensure-room-encounter-state
                     game
                     room
                     '(:encounter :watchful-shadow)
                     :hp 1
                     :damage 1))
         (session (make-runtime-session game :current-room (name room))))
    (multiple-value-bind (output result)
        (run-session-script session (format nil "1~%1~%"))
      (is (equal "room" (name result)))
      (is (contains-substring-p "Encounter: Watchful Shadow" output))
      (is (contains-substring-p "1. Attack watchful-shadow" output))
      (is (contains-substring-p "Watchful Shadow falls." output))
      (is (contains-substring-p "1. Return" output))
      (is (eq :defeated (encounter-status encounter))))))

(test generated-room-active-encounter-allows-ration-use
  (let* ((game (source-game-with-player
                '(:player
                  :name "Mara"
                  :hp 3
                  :max-hp 4
                  :inventory ((:supply :ration)))))
         (player (game-player game))
         (room (create-generated-room
                game
                :zone :dungeon
                :title "Shadowed Room"
                :results '((:encounter :watchful-shadow))
                :exits '((:back . "room"))))
         (encounter (ensure-room-encounter-state
                     game
                     room
                     '(:encounter :watchful-shadow)
                     :hp 1
                     :damage 1))
         (session (make-runtime-session game :current-room (name room))))
    (multiple-value-bind (output result)
        (run-session-script session (format nil "2~%1~%1~%"))
      (is (equal "room" (name result)))
      (is (contains-substring-p "2. Eat ration" output))
      (is (contains-substring-p "3. Flee" output))
      (is (contains-substring-p "You eat a ration and recover." output))
      (is (= 4 (player-hp player)))
      (is (= 0 (player-inventory-count player :supply :ration)))
      (is (eq :defeated (encounter-status encounter))))))

(test generated-room-loot-choices-claim-and-persist
  (let* ((game (source-game-with-player
                '(:player :name "Mara" :hp 4)))
         (room (create-generated-room
                game
                :zone :dungeon
                :title "Looted Room"
                :results '((:supply :ration)
                           (:gold 3)
                           (:room-detail :old-bones))
                :exits '((:back . "room"))))
         (session (make-runtime-session game :current-room (name room))))
    (multiple-value-bind (output result)
        (run-session-script session (format nil "1~%1~%1~%"))
      (is (equal "room" (name result)))
      (is (contains-substring-p "1. Take ration" output))
      (is (contains-substring-p "You take ration." output))
      (is (contains-substring-p "1. Take 3 gold" output))
      (is (contains-substring-p "You take 3 gold." output))
      (is (= 1 (player-inventory-count (game-player game) :supply :ration)))
      (is (= 3 (player-gold (game-player game))))
      (is (equal '(0 1) (generated-room-claimed-results room))))
    (let* ((state (capture-runtime-state session))
           (fresh-game (source-game-with-player
                        '(:player :name "Mara" :hp 4)))
           (restored-session (restore-runtime-state fresh-game state))
           (restored-room (find-generated-room fresh-game
                                               (name room)
                                               :errorp t)))
      (declare (ignore restored-session))
      (is (equal '(0 1) (generated-room-claimed-results restored-room)))
      (multiple-value-bind (output result)
          (run-session-script
           (make-runtime-session fresh-game :current-room (name restored-room))
           (format nil "1~%"))
        (is (equal "room" (name result)))
        (is (not (contains-substring-p "Take ration" output)))
        (is (not (contains-substring-p "Take 3 gold" output)))
        (is (contains-substring-p "1. Return" output))))))

(test generated-room-ration-use-recovers-in-exploration
  (let* ((game (source-game-with-player
                '(:player
                  :name "Mara"
                  :hp 2
                  :max-hp 3
                  :inventory ((:supply :ration :count 2))
                  :fatigue 1
                  :conditions (:deprived))))
         (player (game-player game))
         (room (create-generated-room
                game
                :zone :dungeon
                :title "Quiet Room"
                :exits '((:back . "room"))))
         (session (make-runtime-session game :current-room (name room))))
    (multiple-value-bind (output result)
        (run-session-script session (format nil "1~%1~%"))
      (is (equal "room" (name result)))
      (is (contains-substring-p "1. Eat ration" output))
      (is (contains-substring-p "You eat a ration and recover." output))
      (is (= 3 (player-hp player)))
      (is (= 0 (player-fatigue player)))
      (is (not (player-condition-p player :deprived)))
      (is (= 1 (player-inventory-count player :supply :ration))))))

(test generated-rooms-register-render-and-round-trip-runtime-state
  (let* ((game (source-game-with-body))
         (room (create-generated-room
                game
                :zone :dungeon
                :depth 1
                :title "Flooded Guardroom"
                :description "Cold water covers the floor."
                :results '((:room-detail :flooded-floor)
                           (:loot :minor))
                :exits '((:back . "room"))))
         (session (make-runtime-session game :current-room (name room)))
         (state (capture-runtime-state session)))
    (is (eq room (find-generated-room game (name room) :errorp t)))
    (is (equal (name room) (runtime-session-current-room-name session)))
    (is (= 1 (game-generated-room-counter game)))
    (is (= 1 (length (getf state :generated-rooms))))
    (let ((room-state (first (getf state :generated-rooms))))
      (is (equal (name room) (getf room-state :id)))
      (is (equal "Flooded Guardroom" (getf room-state :title)))
      (is (eq :dungeon (getf room-state :zone)))
      (is (equal '((:back . "room")) (getf room-state :exits))))
    (let* ((fresh-game (source-game-with-body))
           (restored-session (restore-runtime-state fresh-game state))
           (restored-room (find-generated-room fresh-game
                                               (name room)
                                               :errorp t)))
      (is (equal (name room)
                 (runtime-session-current-room-name restored-session)))
      (is (equal "Cold water covers the floor."
                 (generated-room-description restored-room)))
      (is (equal '((:room-detail :flooded-floor)
                   (:loot :minor))
                 (generated-room-results restored-room)))
      (multiple-value-bind (output result)
          (run-session-script restored-session (format nil "1~%"))
        (is (contains-substring-p "Flooded Guardroom" output))
        (is (contains-substring-p "Cold water covers the floor." output))
        (is (contains-substring-p "Room Detail: Flooded Floor." output))
        (is (contains-substring-p "Loot: Minor." output))
        (is (contains-substring-p "1. Return" output))
        (is (equal "room" (name result)))
        (is (generated-room-visited-p restored-room))))))

(test generated-room-restore-keeps-counter-ahead-of-explicit-ids
  (let* ((game (source-game-with-body))
         (session (restore-runtime-state
                   game
                   '(:current-room "generated:dungeon:7"
                     :generated-room-counter 0
                     :generated-rooms
                     ((:id "generated:dungeon:7"
                       :title "Seventh Room"
                       :zone :dungeon
                       :exits ((:back . "room")))))))
         (next-room (create-generated-room game :zone :dungeon)))
    (declare (ignore session))
    (is (= 8 (game-generated-room-counter game)))
    (is (equal "generated:dungeon:8" (name next-room)))))

(test generated-room-graph-helpers-link-and-replace-exits
  (let* ((game (source-game-with-body))
         (entry (create-generated-room game
                                       :zone :dungeon
                                       :depth 1))
         (deeper (create-generated-room game
                                        :zone :dungeon
                                        :depth 2)))
    (is (null (generated-room-exit-target entry :deeper)))
    (link-generated-rooms entry :deeper deeper :reverse-direction :back)
    (is (equal (name deeper)
               (generated-room-exit-target entry :deeper)))
    (is (equal (name entry)
               (generated-room-exit-target deeper :back)))
    (set-generated-room-exit entry :deeper "room")
    (is (equal "room" (generated-room-exit-target entry :deeper)))
    (is (= 1 (count :deeper
                    (generated-room-exits entry)
                    :key #'car
                    :test #'eq)))
    (signals error
      (set-generated-room-exit entry "north" "room"))
    (signals error
      (generated-room-exit-target "not a room" :north))
    (let ((source (create-generated-room game
                                         :zone :dungeon
                                         :depth 3))
          (target (create-generated-room game
                                         :zone :dungeon
                                         :depth 4)))
      (signals error
        (link-generated-rooms source
                              :north
                              target
                              :reverse-direction "south"))
      (is (null (generated-room-exits source)))
      (is (null (generated-room-exits target)))
      (signals error
        (link-generated-rooms source
                              :north
                              "generated:dungeon:5"
                              :reverse-direction :south))
      (is (null (generated-room-exits source)))
      (is (null (generated-room-exits target))))))

(test runtime-state-rejects-malformed-generated-room-state
  (signals error
    (restore-runtime-state
     (source-game-with-body)
     '(:current-room "room"
       :generated-rooms
       ((:id 42
         :zone :dungeon)))))
  (signals error
    (restore-runtime-state
     (source-game-with-body)
     '(:current-room "room"
       :generated-rooms
       ((:id "generated:dungeon:1"
         :zone :dungeon
         :results ((:gold 1))
         :claimed-results (1)))))))

(test runtime-state-rejects-malformed-encounter-state
  (signals error
    (restore-runtime-state
     (source-game-with-body)
     '(:current-room "room"
       :encounters
       ((:room "room"
         :enemy "watchful-shadow"
         :hp 1
         :max-hp 1
         :str 8
         :max-str 8)))))
  (signals error
    (restore-runtime-state
     (source-game-with-body)
     '(:current-room "room"
       :encounters
       ((:room "room"
         :enemy :watchful-shadow
         :hp 1
         :max-hp 1
         :str 8
         :max-str 8)
        (:room "room"
         :enemy :watchful-shadow
         :hp 1
         :max-hp 1
         :str 8
         :max-str 8))))))

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
  (let ((first-game (source-game-with-seeded-tables 314 nil))
        (second-game (source-game-with-seeded-tables 314 nil)))
    (is (equal (loop repeat 3
                     collect (roll-dice first-game "1d6" :label :test-die))
               (loop repeat 3
                     collect (roll-dice second-game "1d6" :label :test-die))))
    (is (= 3 (length (game-roll-log first-game))))
    (let ((entry (first (game-roll-log first-game))))
      (is (equal "1d6" (getf entry :dice)))
      (is (= 1 (getf entry :count)))
      (is (= 6 (getf entry :sides)))
      (is (equal :test-die (getf entry :label)))
      (is (equal (first (getf entry :rolls))
                 (getf entry :result)))))
  (let ((game (source-game-with-seeded-tables 1 nil)))
    (multiple-value-bind (value record)
        (roll-dice-value game 6 :label :static-value)
      (is (= 6 value))
      (is (null record))
      (is (null (game-roll-log game))))))

(test table-result-resolvers-normalize-amounts-and-apply-player-mutations
  (let* ((game (source-game-with-player
                '(:player
                  :name "Resolver"
                  :gold 2
                  :inventory ((:supply :ration :count 1)))))
         (player (game-player game))
         (resolved (resolve-table-result-data
                    game
                    '((:gold "1d6")
                      (:supply :ration :count "1d4")
                      (:item :chalk :slots 0)
                      (:room-detail :flooded-floor)))))
    (is (= 2 (length (game-roll-log game))))
    (is (equal '(:result-gold :result-count)
               (mapcar (lambda (entry)
                         (getf entry :label))
                       (game-roll-log game))))
    (let ((gold (second (first resolved)))
          (ration-count (getf (second resolved) :count)))
      (is (<= 1 gold 6))
      (is (<= 1 ration-count 4))
      (is (equal (list (first resolved)
                       (second resolved)
                       (third resolved))
                 (table-result-loot-results resolved)))
      (apply-resolved-table-result-to-player player resolved)
      (is (= (+ 2 gold) (player-gold player)))
      (is (= (+ 1 ration-count)
             (player-inventory-count player :supply :ration)))
      (is (find-player-inventory-entry player :item :chalk))
      (is (equal '(:item :torch :count 2)
                 (apply-table-result-to-player
                  game
                  player
                  '(:item :torch :count 2))))
      (is (= 2 (player-inventory-count player :item :torch))))))

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
    (is (contains-substring-p "You take ration." output))
    (is (contains-substring-p "This chamber sits at depth 2" output))
    (is (not (contains-substring-p "Placeholder Chamber" output)))))

(test adaptation-character-creation-uses-dice-and-starting-gear
  (let ((game (dunge-examples:load-adaptation-example)))
    (multiple-value-bind (returned-game player)
        (dunge-examples:install-adaptation-player game
                                                  :name "Nia"
                                                  :background :delver)
      (is (eq game returned-game))
      (is (eq player (game-player game)))
      (is (equal "Nia" (player-name player)))
      (is (eq :delver (player-background player)))
      (is (<= 5 (player-str player) 15))
      (is (<= 5 (player-dex player) 15))
      (is (<= 5 (player-wil player) 15))
      (is (<= 1 (player-hp player) 6))
      (is (<= 1 (player-gold player) 6))
      (is (= 1 (player-armor player)))
      (is (equal '((:item :rusted-dagger)
                   (:item :lantern)
                   (:supply :ration :count 1))
                 (player-inventory player)))
      (is (equal '(:adaptation-str
                   :adaptation-dex
                   :adaptation-wil
                   :adaptation-hp
                   :adaptation-gold)
                 (mapcar (lambda (entry)
                           (getf entry :label))
                         (game-roll-log game)))))))

(test generated-adaptation-example-loads-with-created-player
  (let* ((game (dunge-examples:load-generated-adaptation-example))
         (player (game-player game)))
    (is (equal "Generated Delver" (player-name player)))
    (is (eq :wanderer (player-background player)))
    (is (equal '((:item :lantern)
                 (:supply :ration :count 2))
               (player-inventory player)))
    (is (= 5 (length (game-roll-log game))))))

(test adaptation-generated-room-instances-use-authored-tables-and-persist
  (let* ((game (dunge-examples:load-adaptation-example))
         (room (dunge-examples:ensure-adaptation-first-room game))
         (roll-log-length (length (game-roll-log game))))
    (is (typep room 'generated-room))
    (is (eq :dungeon (generated-room-zone room)))
    (is (= 1 (generated-room-depth room)))
    (is (= 4 (length (generated-room-results room))))
    (is (equal '(:room-segment
                 :starter-loot
                 :starter-encounter
                 :starter-exit
                 :dungeon-link
                 :room-segment
                 :starter-loot
                 :starter-encounter)
               (remove nil
                       (mapcar (lambda (entry)
                                 (getf entry :table))
                               (game-roll-log game)))))
    (is (= 2 (length (game-generated-rooms game))))
    (let* ((deeper-id (generated-room-exit-target room :deeper))
           (deeper-room (find-generated-room game deeper-id :errorp t)))
      (is (equal `((:back . "threshold") (:deeper . ,(name deeper-room)))
                 (generated-room-exits room)))
      (is (= 2 (generated-room-depth deeper-room)))
      (is (equal (name room)
                 (generated-room-exit-target deeper-room :back)))
      (is (eq deeper-room
              (dunge-examples:ensure-adaptation-room-exit
               game
               room
               :deeper))))
    (is (= 2 (player-inventory-count (game-player game) :supply :ration)))
    (is (= 2 (gethash :rooms-generated (game-global-state game))))
    (is (= 2 (gethash :dungeon-depth (game-global-state game))))
    (is (gethash :first-room-generated (game-global-state game)))
    (is (= 2 (length (game-encounter-states game))))
    (is (find-encounter-state game room :active-only t))
    (is (eq room (dunge-examples:ensure-adaptation-first-room game)))
    (is (= roll-log-length (length (game-roll-log game))))
    (let* ((session (make-runtime-session game :current-room (name room)))
           (state (capture-runtime-state session))
           (fresh-game (dunge-examples:load-adaptation-example))
           (restored-session (restore-runtime-state fresh-game state))
           (restored-room (find-generated-room fresh-game
                                               (name room)
                                               :errorp t)))
      (is (equal (name room)
                 (runtime-session-current-room-name restored-session)))
      (is (equal (generated-room-results room)
                 (generated-room-results restored-room)))
      (is (= 2 (length (game-generated-rooms fresh-game))))
      (is (= 2 (length (game-encounter-states fresh-game))))
      (multiple-value-bind (output result)
          (run-session-script restored-session (format nil "2~%1~%2~%2~%2~%"))
        (is (contains-substring-p (room-title restored-room) output))
        (is (contains-substring-p "A first find waits here" output))
        (is (contains-substring-p "Encounter: Watchful Shadow" output))
        (is (contains-substring-p "2. Flee" output))
        (is (contains-substring-p "1. Take ration" output))
        (is (contains-substring-p "You take ration." output))
        (is (contains-substring-p "1. Return" output))
        (is (contains-substring-p "2. Continue deeper" output))
        (is (contains-substring-p "This chamber sits at depth 2" output))
        (is (typep result 'quit))
        (is (= 3 (player-inventory-count (game-player fresh-game)
                                          :supply
                                          :ration)))
        (is (equal '(1) (generated-room-claimed-results restored-room)))
        (is (equal (name restored-room)
                   (runtime-session-current-room-name restored-session)))))))

(test instanced-adaptation-example-loads-with-first-generated-room
  (let ((game (dunge-examples:load-instanced-adaptation-example)))
    (is (game-player game))
    (is (= 2 (length (game-generated-rooms game))))
    (is (= 2 (length (game-encounter-states game))))
    (is (= 2 (player-inventory-count (game-player game) :supply :ration)))
    (is (= 13 (length (game-roll-log game))))
    (let* ((room (dunge-examples:ensure-adaptation-first-room game))
           (choice (dunge-examples:find-adaptation-choice game
                                                          :enter-first-room))
           (effect (target choice)))
      (is (typep effect 'goto))
      (is (equal (name room) (room-name effect))))))

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
    (is (contains-substring-p "id='dunge-status'" html))
    (is (contains-substring-p "dunge-status-section" html))
    (is (contains-substring-p "#dunge-status { border-color: #474035; }"
                              html))
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
    (is (contains-substring-p "\"inventoryCapacity\":10" script))
    (is (contains-substring-p "\"inventory\":[[{\"type\":\"keyword\",\"name\":\"item\"}"
                              script))
    (is (contains-substring-p "function copyJsonValue" script))
    (is (contains-substring-p "function renderStatusPanel" script))
    (is (contains-substring-p "function renderPlayerStatus" script))
    (is (contains-substring-p "function inventoryUsedSlots" script))
    (is (contains-substring-p "function renderInventoryList" script))
    (is (contains-substring-p "'player' : copyJsonValue(PLAYER)" script))
    (is (contains-substring-p "if (state['player'] !== undefined)" script))))

(test html-compiler-lowers-encounter-state-for-browser-panel
  (let* ((game
           (source-game-with-player
            '(:player
              :name "Mara"
              :hp 4)
            '(:p "A shadow waits.")))
         (encounter (make-encounter-state
                     :room "room"
                     :enemy-id :watchful-shadow
                     :reaction :uncertain
                     :hp 2
                     :max-hp 3
                     :str 8
                     :max-str 10
                     :armor 1
                     :damage "1d4"
                     :round 2)))
    (register-encounter-state game encounter)
    (let ((script (dunge-html:compile-game-script game)))
      (is (contains-substring-p "\"encounters\":[{\"room\":\"room\""
                                script))
      (is (contains-substring-p "\"enemy\":{\"type\":\"keyword\",\"name\":\"watchful-shadow\"}"
                                script))
      (is (contains-substring-p "\"reaction\":{\"type\":\"keyword\",\"name\":\"uncertain\"}"
                                script))
      (is (contains-substring-p "\"damage\":\"1d4\"" script))
      (is (contains-substring-p "\"status\":{\"type\":\"keyword\",\"name\":\"active\"}"
                                script))
      (is (contains-substring-p "function encounterForCurrentRoom" script))
      (is (contains-substring-p "var roomId = fallbackCurrentRoomId();"
                                script))
      (is (contains-substring-p "function renderEncounterStatus" script))
      (is (contains-substring-p "renderStatusPanel();" script)))))

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
