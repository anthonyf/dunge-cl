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

;;; Golden adaptation transcripts.
;;;
;;; tests/golden/adaptation.sexp records the console frames for scripted runs
;;; of the adaptation example. The console must reproduce them exactly, and
;;; the browser must match the console. Refactors of the crawler must leave
;;; them unchanged; when a change is intended, review the new frames and
;;; rewrite the file with (dunge-tests::write-adaptation-golden).

(defparameter *adaptation-golden-scenarios*
  '((:name :default-seed-player-falls
     :inputs (1 1 1))
    (:name :victory-loot-and-deeper-room
     :seed 1
     :inputs (1 1 1 1 2 1 1 1 1 1))
    (:name :wounded-eats-ration-mid-fight
     :seed 27
     :inputs (1 1 1 2 1 1 1 1))
    (:name :flee-then-loot
     :seed 2
     :inputs (1 1 2 1 1 1))
    (:name :gold-loot
     :seed 4
     :inputs (1 1 1 1 1))
    (:name :delver-armor-absorbs-hit
     :seed 7
     :background :delver
     :inputs (1 1 1 1 1 1)))
  "Each scenario plays INPUTS through the instanced adaptation example built
with SEED (default: the game's own) and BACKGROUND (default :wanderer).")

(defparameter *adaptation-golden-path*
  (asdf:system-relative-pathname "dunge/tests" "tests/golden/adaptation.sexp"))

(defun adaptation-scenario-game (scenario)
  (dunge-examples:load-instanced-adaptation-example
   :seed (getf scenario :seed)
   :background (getf scenario :background :wanderer)))

(defun adaptation-scenario (name)
  (or (find name *adaptation-golden-scenarios*
            :key (lambda (scenario) (getf scenario :name)))
      (error "No adaptation golden scenario named ~S." name)))

(defun read-adaptation-golden ()
  (with-open-file (stream *adaptation-golden-path* :external-format :utf-8)
    (let ((*read-eval* nil)
          (*package* (find-package '#:dunge-tests)))
      (read stream))))

(defun write-adaptation-golden ()
  "Record the console frames of every adaptation golden scenario."
  (with-open-file (stream *adaptation-golden-path*
                          :direction :output
                          :if-exists :supersede
                          :external-format :utf-8)
    (let ((*package* (find-package '#:dunge-tests))
          (*print-case* :downcase)
          (*print-right-margin* 100))
      (format stream ";;; Golden console frames for the adaptation example. ~
                      See tests/runtime-parity.lisp.~%")
      (pprint (loop for scenario in *adaptation-golden-scenarios*
                    collect (list (getf scenario :name)
                                  (dunge-parity:console-frames
                                   (adaptation-scenario-game scenario)
                                   (getf scenario :inputs))))
              stream)
      (terpri stream)))
  *adaptation-golden-path*)

(test adaptation-console-matches-golden-transcripts
  (let ((golden (read-adaptation-golden)))
    (is (equal (mapcar (lambda (scenario) (getf scenario :name))
                       *adaptation-golden-scenarios*)
               (mapcar #'first golden)))
    (dolist (scenario *adaptation-golden-scenarios*)
      (let ((expected (second (assoc (getf scenario :name) golden)))
            (actual (dunge-parity:console-frames
                     (adaptation-scenario-game scenario)
                     (getf scenario :inputs))))
        (is (equal expected actual)
            "Adaptation scenario ~S changed.~%~A"
            (getf scenario :name)
            (dunge-parity::describe-frame-mismatch expected actual))))))

(defmacro def-adaptation-parity-test (name scenario-name &rest options)
  `(def-parity-test ,name ,options
       (adaptation-scenario-game (adaptation-scenario ,scenario-name))
     (getf (adaptation-scenario ,scenario-name) :inputs)))

(def-adaptation-parity-test parity-adaptation-default-seed-player-falls
  :default-seed-player-falls)
(def-adaptation-parity-test parity-adaptation-victory-loot-and-deeper-room
  :victory-loot-and-deeper-room)
(def-adaptation-parity-test parity-adaptation-wounded-eats-ration-mid-fight
  :wounded-eats-ration-mid-fight)
(def-adaptation-parity-test parity-adaptation-flee-then-loot
  :flee-then-loot)
(def-adaptation-parity-test parity-adaptation-gold-loot
  :gold-loot)
(def-adaptation-parity-test parity-adaptation-delver-armor-absorbs-hit
  :delver-armor-absorbs-hit)
;; Reload mid-fight: the encounter, player, and generator must all be saved.
(def-adaptation-parity-test parity-adaptation-reload-mid-fight
  :wounded-eats-ration-mid-fight
  :reload-after 3)
(def-adaptation-parity-test parity-adaptation-reload-in-deeper-room
  :victory-loot-and-deeper-room
  :reload-after 5)

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
       (:choice \"Overflow before a keyword\"
        ((:say (:add 9007199254740991 1 (:global :mood)))))
       (:choice \"Quit\" (:quit))))))")

(def-parity-test parity-expressions-arithmetic-comparisons-and-interpolation ()
    (load-dunge-string *parity-expression-game*)
  ;; Weigh, loot (gold 10), weigh again, report, hit twice (hp 2 then 0), quit.
  '(2 1 2 4 3 3 9))

(def-parity-test parity-expressions-overflow-is-an-error ()
    (load-dunge-string *parity-expression-game*)
  '(5))

(def-parity-test parity-expressions-non-integer-operand-is-an-error ()
    (load-dunge-string *parity-expression-game*)
  '(6))

(def-parity-test parity-expressions-increment-overflow-is-an-error ()
    (load-dunge-string *parity-expression-game*)
  '(7))

(def-parity-test parity-expressions-report-the-first-arithmetic-error ()
    (load-dunge-string *parity-expression-game*)
  ;; Operands are evaluated left to right, so the overflow comes before the
  ;; keyword operand's type error in both runtimes.
  '(8))

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

;;; Dice: the browser's generator matches the console's roll for roll.

(defun load-parity-lcg-game (seed)
  "A game whose single choice shows the next 100 generator states.
A die with 2^31 sides rolls one more than the state it draws."
  (compile-dunge-source
   `(:game
     :start "lcg"
     :seed ,seed
     :state ((:round 0))
     :rooms
     ((:room
       :id "lcg"
       :title "Generator"
       :body
       ((:choice "Draw"
         ((:inc :target (:global :round))
          (:say (:concat
                 ,@(loop repeat 100
                         append (list '(:sub (:roll "1d2147483648") 1) " "))))))
        (:choice "Quit" (:quit))))))))

(def-parity-test parity-lcg-matches-for-ten-thousand-states ()
    (load-parity-lcg-game 1)
  (make-list 100 :initial-element 1))

(def-parity-test parity-lcg-matches-from-a-large-seed ()
    ;; Beyond both 2^31 and 2^53: the browser gets the seed modulo 2^31.
    (load-parity-lcg-game (+ (expt 2 60) 7))
  (make-list 5 :initial-element 1))

(defparameter *parity-dice-game*
  "(:game
    :start \"arena\"
    :seed 20260929
    :state ((:armor 2) (:hp 30) (:last 0) (:rolls 0))
    :rooms
    ((:room
      :id \"arena\"
      :title \"Arena\"
      :body
      ((:p \"Dice clatter on the sand.\")
       (:choice \"Roll a spread\"
        ((:inc :target (:global :rolls) :amount 5)
         (:say \"Spread; {global:rolls} spread dice so far.\")
         (:say (:roll \"1d6\"))
         (:say (:roll \"2d6+1\" :label :attack))
         (:say (:roll \"d20\"))
         (:say (:roll \"3d4-2\"))
         (:say (:roll :dice \"1d100\" :label :percentile))))
       (:choice \"Strike\"
        ((:set :target (:global :last)
               :value (:max 0 (:sub (:roll \"1d8\" :label :damage) (:global :armor))))
         (:set :target (:global :hp)
               :value (:max 0 (:sub (:global :hp) (:global :last))))
         (:if :when (:gte (:global :last) 4)
          :then ((:say \"A heavy blow: {global:last}. HP {global:hp}.\"))
          :else ((:say \"A glancing blow: {global:last}. HP {global:hp}.\")))))
       (:choice \"Roll twice and add\"
        ((:say (:add (:roll \"1d6\") (:roll \"1d6\") (:mul 2 (:roll \"1d4\"))))))
       (:choice \"Quit\" (:quit))))))")

(def-parity-test parity-dice-rolls-match ()
    (load-dunge-string *parity-dice-game*)
  ;; 50 rolls: 5 spreads of 5, 16 strikes of 1, and 3 sums of 3.
  '(1 2 3 1 2 2 3 1 2 2 2 1 3 2 2 2 2 1 2 2 2 2 2 2 4))

(def-parity-test parity-dice-continue-after-reload
    (:reload-after 3)
    (load-dunge-string *parity-dice-game*)
  ;; Reload mid-sequence; the next rolls must continue the same stream.
  '(1 2 2 1 3 2 4))

(def-parity-test parity-dice-continue-after-reload-at-start
    (:reload-after 1)
    (load-dunge-string *parity-dice-game*)
  '(2 2 1 4))

(defun load-parity-dice-damage-game ()
  "A duel against an enemy whose damage is dice, so the browser must roll it."
  (let* ((game (load-dunge-string
                "(:game
                  :start \"hall\"
                  :seed 99
                  :player (:player :name \"Mara\" :hp 12 :armor 1
                           :inventory ((:supply :ration :count 2)))
                  :rooms
                  ((:room
                    :id \"hall\"
                    :title \"Hall\"
                    :body
                    ((:choice \"Enter the pit\" (:go \"generated:pit:1\"))
                     (:choice \"Quit\" (:quit))))))"))
         (room (create-generated-room game
                                      :id "generated:pit:1"
                                      :zone :pit
                                      :title "Pit"
                                      :results '((:encounter :pit-brute))
                                      :exits '((:back . "hall")))))
    (ensure-room-encounter-state game room '(:encounter :pit-brute)
                                 :hp 9 :armor 1 :damage "1d4+1")
    game))

(def-parity-test parity-encounter-dice-damage-is-rolled ()
    (load-parity-dice-damage-game)
  ;; Enter, then attack until the fight ends, eating when offered.
  '(1 1 1 2 1 1 1 1 1))
