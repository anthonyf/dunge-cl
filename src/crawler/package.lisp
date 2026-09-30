(uiop:define-package #:dunge.crawler
  (:use #:cl #:dunge)
  (:shadowing-import-from #:dunge
                          #:room
                          #:sequence)
  (:import-from #:dunge
                #:ensure-runtime-property-list
                #:generated-room-display-lower
                #:generated-room-display-word
                #:non-negative-integer-value
                #:positive-integer-value
                #:proper-list-length-value)
  (:export
   #:create-generated-room
   #:encounter-entity-form
   #:encounter-spec
   #:inventory-entry-count
   #:inventory-entry-id
   #:inventory-entry-kind
   #:inventory-entry-slots
   #:item-catalog
   #:loot-choice-form
   #:player-declarations
   #:ration-choice-form
   #:resolve-table-result-data
   #:table-loot-entries
   #:table-result-encounters
   #:table-result-exits
   #:table-result-kind
   #:table-result-loot-p
   #:table-result-loot-results
   #:used-slots-expression
   #:+inventory-capacity+))
