(uiop:define-package #:dunge-tests
  (:use #:cl #:fiveam #:dunge)
  (:shadowing-import-from #:dunge
                          #:room
                          #:sequence)
  (:import-from #:dunge-parity
                #:def-parity-test))
