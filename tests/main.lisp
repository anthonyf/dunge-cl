(defpackage #:dunge/tests/main
  (:use #:cl #:dunge #:rove)
  (:shadowing-import-from #:dunge #:room #:char-name #:item))
(in-package #:dunge/tests/main)

;; NOTE: To run this test file, execute `(asdf:test-system :dunge)' in your Lisp.

(deftest test-target-1
  (testing "should (= 1 1) to be true"
    (ok (= 1 1))))
