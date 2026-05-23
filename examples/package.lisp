(uiop:define-package #:dunge-examples
  (:use #:cl #:dunge)
  (:shadowing-import-from #:dunge
                          #:room
                          #:sequence)
  (:export
   #:basic-example
   #:control-panel-example
   #:load-basic-example
   #:load-control-panel-example))
