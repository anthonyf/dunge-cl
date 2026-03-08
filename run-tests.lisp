;;;; run-tests.lisp — Run ECE game tests from the command line
;;;;
;;;; Usage:  sbcl --non-interactive --load run-tests.lisp
;;;;
;;;; Exit code: 0 = all pass, 1 = failures

(require :uiop)

(defvar *project-root*
  (make-pathname :name nil :type nil :defaults *load-truename*))

;;; Load ECE
(load (merge-pathnames ".qlot/setup.lisp" *project-root*))
(asdf:load-system :ece)

;;; Output capture for integration tests
(defvar *output-buffer* "")
(defvar *suppress-stdout* nil)

;; Patch display/newline: always capture to buffer, optionally print to stdout
(defun ece::ece-display (obj)
  (let ((s (princ-to-string obj)))
    (setf *output-buffer* (concatenate 'string *output-buffer* s))
    (unless *suppress-stdout*
      (princ s)
      (finish-output)))
  obj)

(defun ece::ece-newline ()
  (setf *output-buffer*
        (concatenate 'string *output-buffer* (string #\Newline)))
  (unless *suppress-stdout*
    (terpri)
    (finish-output))
  nil)

;; CL primitive: clear buffer, run browser-step with stdout suppressed, return buffer
(defun ece-test-step (input)
  (setf *output-buffer* "")
  (let ((*suppress-stdout* t))
    (ece:evaluate (list (intern "BROWSER-STEP" :ece) input)))
  *output-buffer*)

;;; Load game files and run tests
(let ((*default-pathname-defaults* *project-root*))
  (format t "Loading game files...~%")
  (ece:evaluate '(ece:load "game/engine.scm"))
  (ece:evaluate '(ece:load "game/dice.scm"))
  (ece:evaluate '(ece:load "game/items.scm"))
  (ece:evaluate '(ece:load "game/combat.scm"))
  (ece:evaluate '(ece:load "game/bestiary.scm"))
  (ece:evaluate '(ece:load "game/content.scm"))

  ;; Load browser-boot.scm for call/cc integration test support
  (format t "Loading browser-boot...~%")
  (ece:evaluate '(ece:load "browser-boot.scm"))

  ;; Install browser-read-line as read-line
  (ece:evaluate
   `(ece:define (,(intern "READ-LINE" :ece))
      (,(intern "BROWSER-READ-LINE" :ece))))

  ;; Register test-step as ECE primitive (bridges CL output buffer to ECE)
  (ece::define-variable! (intern "TEST-STEP" :ece)
    (list (intern "PRIMITIVE" :ece) 'ece-test-step)
    ece:*global-env*)

  ;; Load test harness and test files
  (format t "Loading tests...~%")
  (ece:evaluate '(ece:load "tests/test-harness.scm"))
  (ece:evaluate '(ece:load "tests/unit/test-dice.scm"))
  (ece:evaluate '(ece:load "tests/unit/test-items.scm"))
  (ece:evaluate '(ece:load "tests/unit/test-combat.scm"))
  (ece:evaluate '(ece:load "tests/integration/test-char-creation.scm"))
  (ece:evaluate '(ece:load "tests/integration/test-navigation.scm"))

  ;; Run tests
  (format t "~%=== Running ECE Tests ===~%~%")
  (let ((failures (ece:evaluate (list (intern "RUN-TESTS" :ece)))))
    (uiop:quit (if (= failures 0) 0 1))))
