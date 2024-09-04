(defsystem "dunge"
  :version "0.1.0"
  :author ""
  :license ""
  :class :package-inferred-system
  :depends-on (#:dunge/src/main)
  :description ""
  :in-order-to ((test-op (test-op "dunge/tests"))))

(defsystem "dunge/tests"
  :author ""
  :license ""
  :class :package-inferred-system
  :depends-on (#:dunge/tests/main)
  :description "Test system for dunge"
  :perform (test-op (op c) (symbol-call :rove :run c)))
