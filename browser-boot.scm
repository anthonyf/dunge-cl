;;; browser-boot.scm — Browser I/O via call/cc
;;; Pre-parsed at build time, evaluated in the browser.

(define *top-continuation* #f)
(define *resume-continuation* #f)

(define (browser-step input)
  "Called by JS. First call starts game, subsequent calls provide input."
  (call/cc (lambda (exit)
    (set *top-continuation* exit)
    (if *resume-continuation*
        (let ((k *resume-continuation*))
          (set *resume-continuation* #f)
          (k input))
        (start)))))

(define (browser-read-line)
  "Replaces read-line in browser mode. Suspends via call/cc."
  (call/cc (lambda (k)
    (set *resume-continuation* k)
    (*top-continuation* 'waiting))))

;; Override read-line to use browser-read-line. Loading this file means you
;; want browser-style I/O (suspend via continuations), so the same override
;; applies to the test runner and the browser build.
(define (read-line) (browser-read-line))

;; Initialize the player record so `(start)` can access it via `character-*`
;; accessors. In terminal mode, `game/main.scm` calls this; the web build
;; and tests load this file instead, so we do it here.
(init-player!)

;; Export browser-step to JavaScript via ECE FFI.
;;
;; The FFI callback receives JS arguments as js-ref handles — not scheme
;; strings. We wrap browser-step in a lambda that unwraps the js-ref into
;; a scheme value before calling browser-step, so the same browser-step
;; works in both CLI (direct call with scheme values) and browser (via
;; this FFI wrapper) modes.
;;
;; The whole block is wrapped in `guard` so this file is also loadable
;; from the `ece` CLI, where js-eval/js-set!/js-callback are unbound.
(guard (e (#t #f))
  (js-set! (js-eval "window") "browserStep"
    (js-callback
      (lambda (js-input)
        (let ((input (if (js-null? js-input)
                         #f
                         (js-ref->string js-input))))
          (browser-step input))))))
