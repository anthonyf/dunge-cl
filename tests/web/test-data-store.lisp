;;; test-data-store.lisp — data-store setf tests for JSCL
;;;
;;; Exercises the (setf lookup) JSCL patch.

(in-package #:dunge/web-tests)

(define-web-test test-setf-lookup-single-key
    (let ((dunge:*data-store* nil))
      (setf (dunge:lookup "foo") 42)
      (web-assert (= (dunge:lookup "foo") 42)
                  "setf lookup single key failed")))

(define-web-test test-setf-lookup-nested-keys
    (let ((dunge:*data-store* nil))
      (setf (dunge:lookup "a" "b") 99)
      (web-assert (= (dunge:lookup "a" "b") 99)
                  "setf lookup nested keys failed")))

(define-web-test test-setf-lookup-deeply-nested
    (let ((dunge:*data-store* nil))
      (setf (dunge:lookup "a" "b" "c") 'deep)
      (web-assert (eq (dunge:lookup "a" "b" "c") 'deep)
                  "setf lookup deeply nested failed")))

(define-web-test test-setf-lookup-nil-removes
    (let ((dunge:*data-store* nil))
      (setf (dunge:lookup "foo") 42)
      (setf (dunge:lookup "foo") nil)
      (web-assert (null (dunge:lookup "foo"))
                  "setf lookup nil removal failed")))

(define-web-test test-setf-lookup-preserves-siblings
    (let ((dunge:*data-store* nil))
      (setf (dunge:lookup "rooms" "a") 'room-a)
      (setf (dunge:lookup "rooms" "b") 'room-b)
      (web-assert (eq (dunge:lookup "rooms" "a") 'room-a)
                  "setf lookup sibling a lost")
      (web-assert (eq (dunge:lookup "rooms" "b") 'room-b)
                  "setf lookup sibling b lost")))
