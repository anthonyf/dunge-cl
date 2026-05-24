(uiop:define-package #:dunge-html
  (:use #:cl)
  (:import-from #:parenscript
                #:@
                #:chain
                #:create
                #:false
                #:getprop
                #:typeof
                #:undefined)
  (:export
   #:compile-game-data
   #:compile-game-script
   #:compile-index-html
   #:write-index-html))
