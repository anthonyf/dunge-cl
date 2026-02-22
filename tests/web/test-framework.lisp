;;; test-framework.lisp — Minimal JSCL-compatible test harness
;;;
;;; Registers named test thunks, runs them, writes results to DOM #test-results.

(defpackage #:dunge/web-tests
  (:use #:cl)
  (:export #:define-web-test #:web-assert #:run-web-tests))

(in-package #:dunge/web-tests)

(defvar *web-tests* nil
  "Alist of (name . thunk) for registered web tests.")

(defmacro define-web-test (name &body body)
  "Register a named test. NAME is a symbol."
  `(push (cons ',name (lambda () ,@body)) *web-tests*))

(defun web-assert (condition message)
  "Signal an error when CONDITION is false."
  (unless condition
    (error message)))

(defun run-web-tests ()
  "Run all registered tests. Write results to DOM element #test-results."
  (let ((tests (reverse *web-tests*))
        (passed 0)
        (failed 0)
        (failure-messages nil))
    (dolist (entry tests)
      (let ((name (car entry))
            (thunk (cdr entry)))
        (handler-case
            (progn
              (funcall thunk)
              (incf passed))
          (error (e)
            (incf failed)
            (push (format nil "FAILED ~A: ~A" name e) failure-messages)))))
    ;; Build result string
    (let ((result-text
           (if (zerop failed)
               (format nil "PASS: ~A passed, 0 failed" passed)
               (let ((header (format nil "FAIL: ~A passed, ~A failed" passed failed)))
                 (let ((lines (list header)))
                   (dolist (msg (reverse failure-messages))
                     (push msg lines))
                   (let ((out header))
                     (dolist (msg (reverse failure-messages))
                       (setq out (concatenate 'string out (string #\Newline) msg)))
                     out))))))
      ;; Write to DOM
      (let ((el ((jscl::oget #j:document "getElementById") (jscl::jsstring "test-results"))))
        (setf (jscl::oget el "textContent") (jscl::jsstring result-text))))))
