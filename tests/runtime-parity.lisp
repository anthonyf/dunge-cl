(in-package #:dunge-tests)

;;; Console/browser runtime parity. See tests/parity/support.lisp.

(def-suite :dunge-parity
  :in :dunge-tests
  :description "The console and browser runtimes render the same scripted play.")
(in-suite :dunge-parity)

(defparameter *parity-state-game*
  "(:game
    :start \"hall\"
    :flags (:lamp)
    :state ((:coins 0))
    :rooms
    ((:room
      :id \"hall\"
      :title \"Hall\"
      :body
      ((:branch
        :when (:marked? :lamp)
        :then ((:p \"The lamp is lit.\"))
        :else ((:p \"It is dark.\")))
       (:when (:eq :left (:state :scope :global :key :coins) :right 2)
        (:p \"Two coins glint in your palm.\"))
       (:choice \"Light the lamp\"
        ((:mark :lamp)
         (:say \"You light the lamp.\"))
        :id :light-lamp
        :once t)
       (:choice \"Take a coin\"
        ((:inc :target (:state :scope :global :key :coins))
         (:say \"You pocket a coin.\")))
       (:choice \"Drop a coin\"
        ((:dec :target (:state :scope :global :key :coins)))
        :when (:marked? :lamp))
       (:choice \"Rest in the nook\" (:gosub \"nook\"))
       (:choice \"Quit\" (:quit))))
     (:room
      :id \"nook\"
      :title \"Nook\"
      :body
      ((:p \"A quiet nook.\")
       (:choice \"Back\" (:back))))))")

(def-parity-test parity-basic-container-and-dead-end ()
    (dunge-examples:load-basic-example)
  ;; Open the chest, close it, then enter the hallway, which has no choices.
  '(1 1 2))

(def-parity-test parity-basic-leave ()
    (dunge-examples:load-basic-example)
  '(3))

(def-parity-test parity-control-panel-toggle-and-refs ()
    (dunge-examples:load-control-panel-example)
  ;; Flip, press, enter the passage, return, leave.
  '(1 2 1 1 4))

(def-parity-test parity-global-state-once-and-gosub ()
    (load-dunge-string *parity-state-game*)
  ;; Light (once), take two coins, drop one, rest and come back, quit.
  '(1 1 1 2 3 1 4))

(def-parity-test parity-ran-out-of-input ()
    (load-dunge-string *parity-state-game*)
  '(2))

(defparameter *parity-lamp-game*
  "(:game
    :start \"r\"
    :rooms
    ((:room
      :id \"r\"
      :title \"R\"
      :body
      ((:entity
        :name \"lamp\"
        :id \"lamp\"
        :state ((:lit nil))
        :body
        ((:branch
          :when (:state :scope :self :key :lit)
          :then ((:p \"The lamp is on.\"))
          :else ((:p \"The lamp is off.\")))
         (:action
          :label \"Flip\"
          :do ((:toggle :target (:state :scope :self :key :lit))))))
       (:choice \"Quit\" (:quit))))))")

(defun replace-all (string old new)
  (with-output-to-string (out)
    (loop with start = 0
          for position = (search old string :start2 start)
          do (write-string string out :start start :end position)
          while position
          do (write-string new out)
             (setf start (+ position (length old))))))

(defun strip-lamp-entity-id (script)
  "Remove the lamp's id from compiled browser data, which the validator would
never allow, to check that the browser still initializes its state."
  (let ((with-id "\"type\":\"entity\",\"id\":\"lamp\""))
    (unless (search with-id script)
      (error "Compiled script no longer contains ~A; update this test." with-id))
    (replace-all script with-id "\"type\":\"entity\",\"id\":null")))

(def-parity-test parity-stateful-entity-toggles ()
    (load-dunge-string *parity-lamp-game*)
  '(1 1 2))

(def-parity-test parity-browser-initializes-entities-without-ids
    (:transform-script #'strip-lamp-entity-id)
    (load-dunge-string *parity-lamp-game*)
  '(1 1 2))

(defparameter *parity-nook-game*
  "(:game
    :start \"hub\"
    :rooms
    ((:room
      :id \"hub\"
      :title \"Hub\"
      :body
      ((:p \"You are at the hub.\")
       (:choice \"Peek into the nook\" (:gosub \"nook\"))
       (:choice \"Walk to the alcove\" (:go \"alcove\"))
       (:choice \"Quit\" (:quit))))
     (:room
      :id \"nook\"
      :title \"Nook\"
      :body
      ((:p \"The nook is empty.\")))
     (:room
      :id \"alcove\"
      :title \"Alcove\"
      :body
      ((:p \"The alcove is a dead end.\")))))")

(def-parity-test parity-gosub-into-room-without-choices-offers-continue ()
    (load-dunge-string *parity-nook-game*)
  ;; Peek into the nook, continue back to the hub, quit.
  '(1 1 3))

(def-parity-test parity-room-without-choices-or-caller-ends-play ()
    (load-dunge-string *parity-nook-game*)
  '(2))

(defun load-parity-generated-cellar-game ()
  "A game whose hall leads into a generated room that has no exits, loot, or
encounter, so the generated room itself has no choices."
  (let ((game (load-dunge-string
               "(:game
                 :start \"hall\"
                 :rooms
                 ((:room
                   :id \"hall\"
                   :title \"Hall\"
                   :body
                   ((:p \"A trapdoor opens onto a cellar.\")
                    (:choice \"Peer into the cellar\" (:gosub \"generated:cellar:1\"))
                    (:choice \"Drop into the cellar\" (:go \"generated:cellar:1\"))
                    (:choice \"Quit\" (:quit))))))")))
    (create-generated-room game
                           :id "generated:cellar:1"
                           :zone :cellar
                           :title "Cellar"
                           :description "A bare cellar with no way onward.")
    game))

(def-parity-test parity-generated-room-without-choices-offers-continue ()
    (load-parity-generated-cellar-game)
  ;; Peer into the cellar, continue back to the hall, quit.
  '(1 1 3))

(def-parity-test parity-generated-room-without-choices-or-caller-ends-play ()
    (load-parity-generated-cellar-game)
  '(2))

(def-parity-test parity-say-before-quit-is-shown ()
    (load-dunge-string
     "(:game
       :start \"door\"
       :rooms
       ((:room
         :id \"door\"
         :title \"Door\"
         :body
         ((:choice \"Leave\"
           ((:say \"You close the door behind you.\")
            (:quit)))))))")
  '(1))

(def-parity-test parity-back-without-caller-ends-play ()
    (load-dunge-string
     "(:game
       :start \"door\"
       :rooms
       ((:room
         :id \"door\"
         :title \"Door\"
         :body
         ((:choice \"Step back\"
           ((:say \"There is nowhere to step back to.\")
            (:back)))))))")
  '(1))

;;; Known divergences. Each asserts that the runtimes still differ, so the fix
;;; for a divergence fails its test until the marker is removed.

(def-parity-test parity-adaptation-generated-room
    (:known-divergence
     "Generated-room text and combat differ between runtimes.")
    (dunge-examples:load-instanced-adaptation-example)
  ;; Approach, enter the generated chamber, attack, take loot, eat, return.
  '(1 1 1 1 1 1 1))

;;; Expressions: arithmetic, comparisons, interpolation, and value formatting.

(defparameter *parity-expression-game*
  "(:game
    :start \"camp\"
    :state ((:hp 5) (:gold 0) (:mood :calm) (:name nil) (:brave t))
    :rooms
    ((:room
      :id \"camp\"
      :title \"Camp\"
      :body
      ((:p \"A quiet camp.\")
       (:when (:lte (:global :hp) 2)
        (:p \"You are badly hurt.\"))
       (:when (:and (:gt (:global :gold) 0) (:lt (:global :gold) 10))
        (:p \"Your purse jingles.\"))
       (:when (:gte (:global :gold) 10)
        (:p \"Your purse is heavy.\"))
       (:entity
        :name \"chest\"
        :id \"chest\"
        :state ((:coins 5))
        :body
        ((:action
          :label \"Loot the chest\"
          :do
          ((:set :target (:global :gold)
                 :value (:add (:global :gold) (:mul 2 (:self :coins))))
           (:say \"You take {self:coins} coins, worth {global:gold}.\")
           (:set :target (:self :coins) :value 0)))))
       (:entity
        :name \"scale\"
        :id \"scale\"
        :refs ((:box \"chest\"))
        :body
        ((:action
          :label \"Weigh the chest\"
          :do ((:say \"The chest holds {ref:box:coins} coins.\")))))
       (:choice \"Take a hit\"
        ((:set :target (:global :hp)
               :value (:max 0 (:sub (:global :hp) 2 1)))
         (:say \"HP: {global:hp}, clamped with {{max}}.\")))
       (:choice \"Report\"
        ((:say \"Mood {global:mood}; name [{global:name}]; brave {global:brave}.\")
         (:say (:global :mood))
         (:say (:min 7 (:global :hp) 9))
         (:set :target (:global :name) :value \"Ada\")
         (:clear :target (:global :mood))
         (:say \"Mood [{global:mood}]; name {global:name}.\")))
       (:choice \"Overflow\"
        ((:set :target (:global :gold) :value (:mul 9007199254740991 2))))
       (:choice \"Add a keyword\"
        ((:say (:add 1 (:global :mood)))))
       (:choice \"Overflow by increment\"
        ((:set :target (:global :gold) :value 9007199254740991)
         (:inc :target (:global :gold))))
       (:choice \"Quit\" (:quit))))))")

(def-parity-test parity-expressions-arithmetic-comparisons-and-interpolation ()
    (load-dunge-string *parity-expression-game*)
  ;; Weigh, loot (gold 10), weigh again, report, hit twice (hp 2 then 0), quit.
  '(2 1 2 4 3 3 8))

(def-parity-test parity-expressions-overflow-is-an-error ()
    (load-dunge-string *parity-expression-game*)
  '(5))

(def-parity-test parity-expressions-non-integer-operand-is-an-error ()
    (load-dunge-string *parity-expression-game*)
  '(6))

(def-parity-test parity-expressions-increment-overflow-is-an-error ()
    (load-dunge-string *parity-expression-game*)
  '(7))

(def-parity-test parity-unset-state-equals-nil ()
    (load-dunge-string
     "(:game
       :start \"room\"
       :rooms
       ((:room
         :id \"room\"
         :title \"Room\"
         :body
         ((:when (:eq (:global :unset) nil)
           (:p \"Unset state equals nil.\"))
          (:when (:eq nil (:global :unset))
           (:p \"Nil equals unset state.\"))
          (:choice \"Show it\" (:say \"[{global:unset}]\"))
          (:choice \"Quit\" (:quit))))))")
  '(1 2))
