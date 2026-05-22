
(uiop:define-package #:dunge
  (:use #:cl)
  (:mix #:trivia)
  (:shadow #:room
           #:sequence)
  (:export
   #:*input*
   #:*output*
   #:action
   #:action-owner
   #:back
   #:branch
   #:choice
   #:choice-condition
   #:choice-id
   #:choice-once-p
   #:choices
   #:close-choice
   #:condition-and
   #:condition-eq
   #:condition-not
   #:condition-or
   #:conditional-effect
   #:collect-choices
   #:container
   #:container-view
   #:define-ast-node
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
   #:node-children
   #:node-id
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
   #:make-runtime-context
   #:runtime-context
   #:runtime-context-game
   #:runtime-context-scene
   #:runtime-context-self
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
   #:walk-node-tree
   #:viewed-container))

(uiop:define-package #:dunge-user
  (:use #:cl #:dunge)
  (:shadowing-import-from #:dunge
                          #:room
                          #:sequence))
