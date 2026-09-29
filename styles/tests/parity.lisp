(in-package #:dunge-styles-tests)

;;; Every Styles ending plays the same in the console and browser runtimes.

(def-suite :dunge-styles-parity
  :in :dunge-styles-tests
  :description "Styles renders the same in the console and browser runtimes.")
(in-suite :dunge-styles-parity)

(def-parity-test styles-wrong-accusation-parity ()
    (load-styles-game)
  ;; Same route as STYLES-WRONG-ACCUSATION-ENDING-IS-PLAYABLE.
  '(4 3 4 1 3 7 4 1))

(def-parity-test styles-poirot-led-parity ()
    (load-styles-game)
  (append *styles-shared-investigation-choices* '(4 4 5 1)))

(def-parity-test styles-player-led-parity ()
    (load-styles-game)
  (append *styles-shared-investigation-choices* '(4 4 4 4 4 1)))
