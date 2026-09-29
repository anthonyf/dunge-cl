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

;;; Known divergences. Each asserts that the runtimes still differ, so the fix
;;; for a divergence fails its test until the marker is removed.

(def-parity-test parity-stateful-entity-without-id
    (:known-divergence
     "The browser only initializes state for entities with an :id.")
    (load-dunge-string
     "(:game
       :start \"r\"
       :rooms
       ((:room
         :id \"r\"
         :title \"R\"
         :body
         ((:entity
           :name \"lamp\"
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
  '(1 1 2))

(def-parity-test parity-gosub-into-room-without-choices
    (:known-divergence
     "The console returns from a choiceless room; the browser dead-ends.")
    (load-dunge-string
     "(:game
       :start \"hub\"
       :rooms
       ((:room
         :id \"hub\"
         :title \"Hub\"
         :body
         ((:p \"You are at the hub.\")
          (:choice \"Peek into the nook\" (:gosub \"nook\"))
          (:choice \"Quit\" (:quit))))
        (:room
         :id \"nook\"
         :title \"Nook\"
         :body
         ((:p \"The nook is empty.\")))))")
  '(1 2))

(def-parity-test parity-say-before-quit
    (:known-divergence
     "The browser never shows :say text from the choice that quits.")
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

(def-parity-test parity-adaptation-generated-room
    (:known-divergence
     "Generated-room text and combat differ between runtimes.")
    (dunge-examples:load-instanced-adaptation-example)
  ;; Approach, enter the generated chamber, attack, take loot, eat, return.
  '(1 1 1 1 1 1 1))
