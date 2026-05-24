(uiop:define-package #:dunge-styles
  (:use #:cl)
  (:import-from #:dunge
                #:evaluate
                #:load-dunge-file)
  (:export
   #:load-styles-game
   #:play-styles
   #:styles-game-path))
