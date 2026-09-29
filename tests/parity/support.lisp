(uiop:define-package #:dunge-parity
  (:use #:cl)
  (:export
   #:browser-frames
   #:check-parity
   #:console-frames
   #:def-parity-test
   #:node-program
   #:parse-console-transcript))

(in-package #:dunge-parity)

;;; Console/browser runtime parity.
;;;
;;; A parity test plays the same numbered choices through the console runtime
;;; and through the compiled browser runtime (run under Node with the DOM stub
;;; in harness.js), reduces both to frames, and compares them.
;;;
;;; Frames:
;;;   (:title TITLE :text (LINE ...) :choices (LABEL ...))  one rendered location
;;;   (:end t)                  the game ended, or a location had no choices
;;;   (:end t :text (LINE ...)) the console printed text the game never showed
;;;                             again before ending
;;;   (:missing-choice N)       the browser did not render choice N
;;;   (:error MESSAGE)          the runtime signalled an error
;;;
;;; Text printed by effects (:say, loot, combat) belongs to the frame rendered
;;; next, which is where the browser shows its messages.
;;;
;;; Node is found through DUNGE_NODE or `node` on PATH. Without it the tests
;;; are skipped, unless DUNGE_REQUIRE_NODE is set (as CI does).

(defparameter *harness-path*
  (asdf:system-relative-pathname "dunge/parity" "tests/parity/harness.js"))

(defun env-flag-p (name)
  (let ((value (uiop:getenv name)))
    (and value
         (string/= value "")
         (string/= value "0"))))

(defun node-program ()
  "Return the Node executable to use for parity tests, or NIL if none runs."
  (let ((candidate (or (uiop:getenv "DUNGE_NODE") "node")))
    (when (ignore-errors
           (zerop (nth-value 2 (uiop:run-program (list candidate "--version")
                                                 :output nil
                                                 :error-output nil
                                                 :ignore-error-status t))))
      candidate)))

;;; Console side

(defun console-transcript (game inputs)
  "Play INPUTS through the console runtime.
Return the transcript and the message of any error signalled during play."
  (let ((error-message nil))
    (values
     (with-output-to-string (output)
       (let ((dunge:*input* (make-string-input-stream
                             (format nil "~{~A~%~}" inputs)))
             (dunge:*output* output)
             (dunge:*debug* nil)
             (dunge:*pause-after-say* nil))
         (handler-case (dunge:evaluate game)
           (error (condition)
             (setf error-message (princ-to-string condition))))))
     error-message)))

(defun split-lines (string)
  (with-input-from-string (stream string)
    (loop for line = (read-line stream nil)
          while line
          collect line)))

(defun strip-prompts (line)
  "Remove leading \"> \" choice prompts from LINE.
Return the remaining text and how many prompts were removed."
  (let ((count 0))
    (loop while (and (>= (length line) 2)
                     (string= "> " line :end2 2))
          do (incf count)
             (setf line (subseq line 2)))
    (values line count)))

(defun title-underline-p (line title)
  (and (plusp (length title))
       (= (length line) (length title))
       (every (lambda (char) (char= char #\=)) line)))

(defun choice-line-label (line)
  "Return the label of a numbered console choice line such as \"2. Leave\"."
  (let ((dot (position-if-not #'digit-char-p line)))
    (when (and dot
               (plusp dot)
               (< (1+ dot) (length line))
               (char= (char line dot) #\.)
               (char= (char line (1+ dot)) #\Space))
      (subseq line (+ dot 2)))))

(defun parse-console-transcript (transcript input-count &optional error-message)
  "Reduce a console TRANSCRIPT produced from INPUT-COUNT choices to frames.

Each non-blank line of room text is one text entry, matching one browser
paragraph. A choice-shaped line (\"N. label\") is always read as a choice."
  (let ((lines (coerce (split-lines transcript) 'vector))
        (frames '())
        (title nil)
        (text '())
        (choices '())
        (pending '())
        (prompts 0))
    (flet ((close-frame ()
             (when title
               (push (list :title title
                           :text (reverse text)
                           :choices (reverse choices))
                     frames)
               (setf title nil
                     text '()
                     choices '()))))
      (loop with index = 0
            while (< index (length lines))
            do (multiple-value-bind (line prompt-count)
                   (strip-prompts (aref lines index))
                 (incf prompts prompt-count)
                 (let ((label (choice-line-label line)))
                   (cond
                     ((string= line ""))
                     ((and (< (1+ index) (length lines))
                           (title-underline-p (aref lines (1+ index)) line))
                      (close-frame)
                      (setf title line
                            text pending
                            pending '())
                      (incf index))
                     ((and title label)
                      (push label choices))
                     ((and title (null choices))
                      (push line text))
                     (t
                      (push line pending)))))
               (incf index))
      (close-frame))
    (let ((frames (nreverse frames)))
      (cond
        (error-message
         (append frames (list (list :error error-message))))
        ;; A game that is still asking for input when INPUTS run out has
        ;; printed one more prompt than there were inputs.
        ((> prompts input-count)
         frames)
        (pending
         (append frames (list (list :end t :text (reverse pending)))))
        (t
         (append frames (list (list :end t))))))))

(defun console-frames (game inputs)
  (multiple-value-bind (transcript error-message) (console-transcript game inputs)
    (parse-console-transcript transcript (length inputs) error-message)))

;;; Browser side

(defun temporary-script-pathname ()
  (merge-pathnames (format nil "dunge-parity-~36R.js"
                           (random (expt 36 10) (make-random-state t)))
                   (uiop:temporary-directory)))

(defun read-harness-frames (output)
  (let ((*read-eval* nil)
        (*package* (find-package '#:dunge-parity)))
    (read-from-string output)))

(defun browser-frames (game inputs node)
  "Compile GAME for the browser, play INPUTS in NODE, and return the frames."
  (let ((script (dunge-html:compile-game-script game))
        (pathname (temporary-script-pathname)))
    (unwind-protect
         (progn
           (with-open-file (stream pathname
                                   :direction :output
                                   :if-exists :supersede
                                   :external-format :utf-8)
             (write-string script stream))
           (multiple-value-bind (output error-output status)
               (uiop:run-program (list* node
                                        (namestring *harness-path*)
                                        (namestring pathname)
                                        (mapcar #'princ-to-string inputs))
                                 :output :string
                                 :error-output :string
                                 :ignore-error-status t
                                 :external-format :utf-8)
             (unless (zerop status)
               (error "Parity harness exited with status ~D:~%~A"
                      status
                      error-output))
             (read-harness-frames output)))
      (when (probe-file pathname)
        (delete-file pathname)))))

;;; Comparison

(defun describe-frame-mismatch (console browser)
  (let ((index (mismatch console browser :test #'equal)))
    (format nil "Runtimes diverge at frame ~D.~%  console: ~S~%  browser: ~S"
            index
            (nth index console)
            (nth index browser))))

(defun check-parity (make-game inputs &key known-divergence)
  "Assert that both runtimes render the same frames for INPUTS.

MAKE-GAME is called once per runtime so each gets a fresh game. When
KNOWN-DIVERGENCE is a string, assert instead that the runtimes still differ, so
a fix makes the test fail until the marker is removed."
  (let ((node (node-program)))
    (cond
      ((null node)
       (if (env-flag-p "DUNGE_REQUIRE_NODE")
           (fiveam:fail "Node.js is required for parity tests but was not found; ~
                         set DUNGE_NODE or put node on PATH.")
           (fiveam:skip "Node.js not found; set DUNGE_NODE to run parity tests.")))
      (t
       (let ((console (console-frames (funcall make-game) inputs))
             (browser (browser-frames (funcall make-game) inputs node)))
         (cond
           (known-divergence
            (if (equal console browser)
                (fiveam:fail "Known divergence no longer reproduces; remove ~
                              :KNOWN-DIVERGENCE (~A)."
                             known-divergence)
                (fiveam:pass)))
           ((equal console browser)
            (fiveam:pass))
           (t
            (fiveam:fail "~A" (describe-frame-mismatch console browser)))))))))

(defmacro def-parity-test (name (&key known-divergence) game-form inputs-form)
  "Define a FiveAM test that plays the choice numbers from INPUTS-FORM through
the console and browser runtimes and compares the rendered frames.
GAME-FORM is evaluated once per runtime."
  `(fiveam:test ,name
     (check-parity (lambda () ,game-form)
                   ,inputs-form
                   :known-divergence ,known-divergence)))
