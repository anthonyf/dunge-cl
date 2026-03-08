;;; browser-boot.scm — Browser I/O via call/cc
;;; Pre-parsed at build time, evaluated in the browser.

(define *top-continuation* nil)
(define *resume-continuation* nil)

(define (browser-step input)
  "Called by JS. First call starts game, subsequent calls provide input."
  (call/cc (lambda (exit)
    (set *top-continuation* exit)
    (if *resume-continuation*
        (*resume-continuation* input)
        (start)))))

(define (browser-read-line)
  "Replaces read-line in browser mode. Suspends via call/cc."
  (call/cc (lambda (k)
    (set *resume-continuation* k)
    (*top-continuation* 'waiting))))
