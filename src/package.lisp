
(uiop:define-package #:dunge
  (:use #:cl)
  (:mix #:trivia)
  (:shadow #:room)
  (:export
   #:*input*
   #:*output*
   #:action
   #:back
   #:choice
   #:close-choice
   #:collect-choices
   #:container
   #:container-view
   #:contents
   #:describe-entity
   #:description
   #:enter
   #:enter-target
   #:entity
   #:entities
   #:evaluate
   #:game
   #:game-player
   #:game-rooms
   #:game-start
   #:gosub
   #:goto
   #:interaction-label
   #:interaction-target
   #:item
   #:label
   #:name
   #:open-choice
   #:option
   #:options
   #:p
   #:placed
   #:placed-thing
   #:placement-description
   #:quit
   #:room
   #:room-name
   #:say
   #:shown-when
   #:target
   #:text
   #:toggle
   #:viewed-container))

(uiop:define-package #:dunge-user
  (:use #:cl #:dunge)
  (:shadowing-import-from #:dunge #:room))
