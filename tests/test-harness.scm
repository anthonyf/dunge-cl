;;; test-harness.scm — ECE-native test framework
;;; Uses ECE's built-in assert macro for assertions.
;;; test-step is registered as a CL primitive by run-tests.lisp.

;; Utility
(define (string-contains? haystack needle)
  "Return #t if needle appears anywhere in haystack."
  (let ((hlen (string-length haystack))
        (nlen (string-length needle)))
    (if (> nlen hlen) nil
        (let loop ((i 0))
          (cond
            ((> (+ i nlen) hlen) nil)
            ((equal? (substring haystack i (+ i nlen)) needle) t)
            (else (loop (+ i 1))))))))

;; Test Registry
(define *tests* '())

(define-macro (define-test name . body)
  "Register a named test. Body should use assert for checks."
  (let ((fn-sym (gensym)))
    `(begin
       (define (,fn-sym) ,@body 'ok)
       (set *tests* (append *tests* (list (list ,name ',fn-sym)))))))

;; State Reset
(define-macro (with-fresh-state . body)
  "Reset all game state before running body."
  `(begin
     (init-player!)
     (set *current-room* nil)
     (set *current-encounter* nil)
     (set *resume-continuation* nil)
     (set *top-continuation* nil)
     ,@body))

;; Test Runner
(define (run-tests)
  "Run all registered tests via try-eval. Returns number of failures."
  (let ((passed 0)
        (failed 0)
        (total (length *tests*)))
    (for-each
      (lambda (test-entry)
        (let* ((name (car test-entry))
               (fn-sym (cadr test-entry))
               (result (try-eval (list fn-sym))))
          (if result
              (begin
                (set passed (+ passed 1))
                (display "  PASS  ")
                (display name)
                (newline))
              (begin
                (set failed (+ failed 1))
                (display "  FAIL  ")
                (display name)
                (newline)))))
      *tests*)
    (newline)
    (if (= failed 0)
        (begin
          (display (fmt "All " total " tests passed."))
          (newline))
        (begin
          (display (fmt failed " of " total " tests failed."))
          (newline)))
    (newline)
    failed))
