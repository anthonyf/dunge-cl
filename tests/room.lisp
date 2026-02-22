(defpackage #:dunge/tests/room
  (:use #:cl #:dunge #:rove)
  (:shadowing-import-from #:dunge #:room #:char-name #:item))
(in-package #:dunge/tests/room)

;;; run-once tests

(deftest test-run-once-executes-body
    (testing "run-once executes the body on first perform"
             (let* ((*data-store* nil)
                    (counter 0)
                    (*vignette-stack* nil))
               (make-room 'test-run-once "Test"
                          (run-once (incf counter)))
               (let ((r (room 'test-run-once)))
                 (setf *vignette-stack* (list r))
                 (perform (make-instance 'print-context) r)
                 (ok (= counter 1) "body should have run once")))))

(deftest test-run-once-skips-on-second-perform
    (testing "run-once skips the body on second perform"
             (let* ((*data-store* nil)
                    (counter 0)
                    (*vignette-stack* nil))
               (make-room 'test-run-once-2 "Test"
                          (run-once (incf counter)))
               (let ((r (room 'test-run-once-2)))
                 (setf *vignette-stack* (list r))
                 (perform (make-instance 'print-context) r)
                 (perform (make-instance 'print-context) r)
                 (ok (= counter 1) "body should not have run a second time")))))

(deftest test-multiple-run-once-independent
    (testing "multiple run-once blocks in the same room are independent"
             (let* ((*data-store* nil)
                    (counter-a 0)
                    (counter-b 0)
                    (*vignette-stack* nil))
               (make-room 'test-run-once-multi "Test"
                          (run-once (incf counter-a))
                          (run-once (incf counter-b)))
               (let ((r (room 'test-run-once-multi)))
                 (setf *vignette-stack* (list r))
                 (perform (make-instance 'print-context) r)
                 (ok (= counter-a 1) "first run-once should have run")
                 (ok (= counter-b 1) "second run-once should have run")
                 (perform (make-instance 'print-context) r)
                 (ok (= counter-a 1) "first run-once should not run again")
                 (ok (= counter-b 1) "second run-once should not run again")))))
