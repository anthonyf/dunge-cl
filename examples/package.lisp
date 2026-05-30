(uiop:define-package #:dunge-examples
  (:use #:cl #:dunge)
  (:shadowing-import-from #:dunge
                          #:room
                          #:sequence)
  (:export
   #:adaptation-example
   #:basic-example
   #:control-panel-example
   #:ensure-adaptation-first-room
   #:generated-adaptation-example
   #:instanced-adaptation-example
   #:install-adaptation-player
   #:load-adaptation-example
   #:load-basic-example
   #:load-control-panel-example
   #:load-generated-adaptation-example
   #:load-instanced-adaptation-example
   #:make-adaptation-player))
