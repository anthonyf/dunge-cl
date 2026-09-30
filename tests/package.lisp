(uiop:define-package #:dunge-tests
  (:use #:cl #:fiveam #:dunge #:dunge.ast #:dunge.crawler)
  (:shadowing-import-from #:dunge
                          #:room
                          #:sequence)
  ;; White-box tests reach a few internals directly.
  (:import-from #:dunge
                #:availability-mixin
                #:available-p
                #:consumable-mixin
                #:collect-choices
                #:consume-node
                #:consumed-p
                #:describe-entity
                #:node-tags
                #:table-entry-id
                #:table-entry-weight
                #:table-index
                #:table-mode)
  (:import-from #:dunge-parity
                #:def-parity-test))
