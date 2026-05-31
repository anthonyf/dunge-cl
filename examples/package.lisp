(uiop:define-package #:dunge-examples
  (:use #:cl #:dunge)
  (:shadowing-import-from #:dunge
                          #:room
                          #:sequence)
  (:import-from #:dunge-html
                #:write-index-html)
  (:export
   #:adaptation-example
   #:adaptation-browser-demo-path
   #:basic-example
   #:control-panel-example
   #:ensure-adaptation-first-room
   #:ensure-adaptation-room-encounter
   #:ensure-adaptation-room-exit
   #:find-adaptation-choice
   #:install-adaptation-entrance-flow
   #:generated-adaptation-example
   #:instanced-adaptation-example
   #:install-adaptation-player
   #:load-adaptation-example
   #:load-basic-example
   #:load-control-panel-example
   #:load-generated-adaptation-example
   #:load-instanced-adaptation-example
   #:make-adaptation-player
   #:write-adaptation-browser-demo))
