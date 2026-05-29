(uiop:define-package #:dunge-examples
  (:use #:cl #:dunge)
  (:shadowing-import-from #:dunge
                          #:room
                          #:sequence)
  (:export
   #:adaptation-example
   #:basic-example
   #:control-panel-example
   #:load-adaptation-example
   #:load-basic-example
   #:load-control-panel-example))
