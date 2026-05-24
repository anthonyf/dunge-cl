(require 'asdf)

(asdf:defsystem "dunge-styles"
  :depends-on ("dunge")
  :serial t
  :description "The Mysterious Affair at Styles, authored for Dunge"
  :components ((:module "styles"
                :components ((:file "package")
                             (:static-file "game.dunge")
                             (:module "rooms"
                              :components
                              ((:static-file "station.dunge")
                               (:static-file "tea-table.dunge")
                               (:static-file "night-crisis.dunge")
                               (:static-file "bedroom.dunge")
                               (:static-file "servants-hall.dunge")
                               (:static-file "poirot.dunge")
                               (:static-file "suspect-board.dunge")
                               (:static-file "chemist.dunge")
                               (:static-file "dispensary.dunge")
                               (:static-file "final-drawing-room.dunge")
                               (:static-file "ending-player-led.dunge")
                               (:static-file "ending-poirot-led.dunge")
                               (:static-file "ending-wrong-accusation.dunge")))
                             (:file "main")))))

(asdf:defsystem "dunge-styles/tests"
  :depends-on ("dunge-styles"
               :fiveam)
  :serial t
  :description "Tests for the Styles Dunge adaptation"
  :components ((:module "styles-tests"
                :pathname "styles/tests"
                :components ((:file "package")
                             (:file "core"))))
  :perform (test-op (op c)
             (uiop:symbol-call :fiveam :run! :dunge-styles-tests)))
