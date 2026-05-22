
(uiop:define-package #:dunge
  (:use #:cl)
  (:mix #:trivia)
  (:shadow #:room
	   #:sequence)
  (:export
   #:*input*
   #:*output*
   #:action
   #:back
   #:choice
   #:close-choice
   #:condition-and
   #:condition-eq
   #:condition-not
   #:condition-or
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
   #:evaluate-condition
   #:evaluate
   #:execute-effect
   #:game
   #:game-player
   #:game-rooms
   #:game-start
   #:gain
   #:gosub
   #:goto
   #:have?
   #:interaction-label
   #:interaction-target
   #:item
   #:label
   #:lose
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
   #:sequence
   #:shown-when
   #:state-clear
   #:state-dec
   #:state-inc
   #:state-ref
   #:state-set
   #:state-toggle
   #:target
   #:text
   #:toggle
   #:viewed-container))

(uiop:define-package #:dunge-user
  (:use #:cl #:dunge)
  (:shadowing-import-from #:dunge
			  #:room
			  #:sequence))
