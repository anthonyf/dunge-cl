(uiop:define-package #:dunge-examples
  (:use #:cl #:dunge #:dunge.crawler)
  (:shadowing-import-from #:dunge
                          #:room
                          #:sequence)
  (:import-from #:dunge-html
                #:write-index-html)
  (:export
   #:adaptation-example
   #:adaptation-browser-demo-path
   #:basic-example
   #:build-adaptation
   #:control-panel-example
   #:load-adaptation-example
   #:load-basic-example
   #:load-control-panel-example
   #:load-instanced-adaptation-example
   #:make-adaptation-player
   #:write-adaptation-browser-demo))
