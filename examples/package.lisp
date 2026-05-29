(uiop:define-package #:dunge-examples
  (:use #:cl #:dunge)
  (:shadowing-import-from #:dunge
                          #:room
                          #:sequence)
  (:export
   #:adaptation-example
   #:basic-example
   #:control-panel-example
   #:generated-adaptation-example
   #:install-adaptation-player
   #:load-adaptation-example
   #:load-basic-example
   #:load-control-panel-example
   #:load-generated-adaptation-example
   #:make-adaptation-player))
