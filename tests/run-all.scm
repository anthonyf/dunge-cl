;;; run-all.scm — Pure ECE test runner for dunge
;;;
;;; Usage: ece tests/run-all.scm
;;; Exit code: 0 = all pass, 1 = failures

;; Load ECE's test framework
(load "~/.local/share/ece/ece-unit.scm")

;; Load game files
(load "game/engine.scm")
(load "game/dice.scm")
(load "game/items.scm")
(load "game/combat.scm")
(load "game/bestiary.scm")
(load "game/content.scm")

;; Load browser-boot for integration tests
(load "browser-boot.scm")

;; Wire read-line to browser-read-line for test-step integration
(define (read-line) (browser-read-line))

;;; Output capture for integration tests.
;;; We override display and newline globally to write to a buffer when
;;; *in-test-step?* is true. This approach is robust to call/cc crossing
;;; (parameterize on current-output-port is not, because the dynamic
;;; extent is restored when a captured continuation is re-invoked, which
;;; routes output to a stale port after test-step returns).

(define *test-output-buffer* "")
(define *in-test-step?* #f)

(define *original-display* display)
(define *original-newline* newline)

(define (display x)
  (if *in-test-step?*
      (set *test-output-buffer*
           (string-append *test-output-buffer*
             (if (string? x) x (write-to-string x))))
      (*original-display* x)))

(define (newline)
  (if *in-test-step?*
      (set *test-output-buffer* (string-append *test-output-buffer* "\n"))
      (*original-newline*)))

(define (test-step input)
  "Call browser-step with INPUT, capture all output to buffer.
   Returns the captured output string."
  (set *test-output-buffer* "")
  (set *in-test-step?* #t)
  (browser-step input)
  (set *in-test-step?* #f)
  *test-output-buffer*)

;; State reset macro for integration tests
(define-macro (with-fresh-state . body)
  "Reset all game state before running body."
  `(begin
     (init-player!)
     (set *current-encounter* #f)
     (set *resume-continuation* #f)
     (set *top-continuation* #f)
     ,@body))

;; Substring helper (kept for test compatibility)
(define (string-contains? haystack needle)
  "Return #t if needle appears anywhere in haystack."
  (let ((hlen (string-length haystack))
        (nlen (string-length needle)))
    (if (> nlen hlen) #f
        (let loop ((i 0))
          (cond
            ((> (+ i nlen) hlen) #f)
            ((equal? (substring haystack i (+ i nlen)) needle) #t)
            (else (loop (+ i 1))))))))

;; Load test files (each calls `test` to register tests)
(load "tests/unit/test-dice.scm")
(load "tests/unit/test-items.scm")
(load "tests/unit/test-combat.scm")
(load "tests/integration/test-char-creation.scm")
(load "tests/integration/test-navigation.scm")

;; Run tests and report using the ORIGINAL display (not the override)
(let* ((result (run-tests))
       (collected (list-ref result 0))
       (ran (list-ref result 1))
       (passes (list-ref result 2))
       (failures (list-ref result 3))
       (failure-msgs (list-ref result 4)))
  (*original-display* (fmt "=== " ran " ran, " passes " passed, " failures " failed ==="))
  (*original-newline*)
  (when (> failures 0)
    (*original-newline*)
    (*original-display* "Failures:")
    (*original-newline*)
    (for-each (lambda (msg)
                (*original-display* (fmt "  " (car msg) ": " (cadr msg)))
                (*original-newline*))
              failure-msgs))
  (exit (if (= failures 0) 0 1)))
