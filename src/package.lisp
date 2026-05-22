
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
   #:branch
   #:choice
   #:choice-condition
   #:choice-id
   #:choice-once-p
   #:close-choice
   #:condition-and
   #:condition-eq
   #:condition-not
   #:condition-or
   #:conditional-effect
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
   #:evaluate-expression
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
   #:make-option
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
   #:shown-unless
   #:state-clear
   #:state-dec
   #:state-inc
   #:state-ref
   #:state-set
   #:state-toggle
   #:target
   #:text
   #:toggle
   #:validate-game
   #:validate-node
   #:viewed-container))

(uiop:define-package #:dunge-user
  (:use #:cl #:dunge)
  (:shadowing-import-from #:dunge
			  #:room
			  #:sequence))
