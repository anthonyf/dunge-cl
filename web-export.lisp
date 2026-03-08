;;;; web-export.lisp — Build dunge for the browser via JSCL + ECE
;;;;
;;;; Usage:  sbcl --load web-export.lisp
;;;;
;;;; Produces dist/index.html (standalone, all JS inlined)

(require :uiop)

;;; ——— Paths ———

(defvar *project-root*
  (make-pathname :name nil :type nil :defaults *load-truename*))

(defvar *dist-dir*
  (merge-pathnames "dist/" *project-root*))

(defvar *jscl-dir*
  (merge-pathnames "vendor/jscl/" *project-root*))

;;; ——— Build version ———

(defun get-build-version ()
  "Return (sha . timestamp) for the build version display."
  (let ((sha (or (uiop:getenv "COMMIT_SHA")
                 (string-trim '(#\Newline #\Space)
                              (uiop:run-program '("git" "rev-parse" "--short" "HEAD")
                                                :output '(:string :stripped t)))))
        (timestamp (or (uiop:getenv "BUILD_TIME")
                       (multiple-value-bind (_sec min hour day month year)
                           (decode-universal-time (get-universal-time) 0)
                         (declare (ignore _sec))
                         (format nil "~4,'0D-~2,'0D-~2,'0D ~2,'0D:~2,'0D UTC"
                                 year month day hour min)))))
    (cons sha timestamp)))

;;; ——— Utilities ———

(defun write-temp-file (name content)
  "Write CONTENT to a temp file NAME under *project-root*, return pathname."
  (let ((path (merge-pathnames name *project-root*)))
    (with-open-file (out path :direction :output
                         :if-exists :supersede)
      (write-string content out))
    path))

(defun cleanup-temp-files (paths)
  "Delete temp files."
  (dolist (p paths)
    (when (probe-file p)
      (delete-file p))))

;;; ——— Step 1: Load ECE for readtable access ———

(format t "~&=== Dunge Web Export (ECE) ===~%")
(format t "~&Loading ECE system...~%")

;; Load via qlot so we get the correct ECE version
(load (merge-pathnames ".qlot/setup.lisp" *project-root*))
(asdf:load-system :ece)

(format t "~&ECE loaded.~%")

;;; ——— Step 2: Pre-parse .scm files using ECE's readtable ———

(defun scm-files ()
  "Return alist of (virtual-name . path) for all .scm files to bundle."
  (list
   (cons "prelude.scm"
         (asdf:system-relative-pathname :ece "src/prelude.scm"))
   (cons "browser-boot.scm"
         (merge-pathnames "browser-boot.scm" *project-root*))
   (cons "game/engine.scm"
         (merge-pathnames "game/engine.scm" *project-root*))
   (cons "game/dice.scm"
         (merge-pathnames "game/dice.scm" *project-root*))
   (cons "game/items.scm"
         (merge-pathnames "game/items.scm" *project-root*))
   (cons "game/combat.scm"
         (merge-pathnames "game/combat.scm" *project-root*))
   (cons "game/bestiary.scm"
         (merge-pathnames "game/bestiary.scm" *project-root*))
   (cons "game/content.scm"
         (merge-pathnames "game/content.scm" *project-root*))))

(defun read-scm-forms (path)
  "Read all S-expressions from a .scm file using ECE's custom readtable."
  (with-open-file (stream path)
    (let ((*readtable* ece::*ece-readtable*)
          (*read-eval* nil)
          (*package* (find-package :ece))
          (eof (gensym)))
      (loop for form = (read stream nil eof)
            until (eq form eof)
            collect form))))

(defun generate-bundled-sources ()
  "Pre-parse all .scm files and generate CL code defining *bundled-sources*."
  (with-output-to-string (out)
    (format out ";;; Bundled pre-parsed .scm sources (generated at build time)~%")
    (format out "(in-package :ece)~%~%")
    (format out "(defvar *bundled-sources* (make-hash-table :test 'equal))~%~%")
    (dolist (entry (scm-files))
      (let* ((name (car entry))
             (path (cdr entry))
             (forms (read-scm-forms path)))
        (format t "~&  Pre-parsed ~A (~D forms)~%" name (length forms))
        (let ((*package* (find-package :ece))
              (*print-case* :downcase)
              (*print-circle* t))
          (format out ";; ~A~%" name)
          (format out "(setf (gethash ~S *bundled-sources*)~%      '~S)~%~%"
                  name forms))))))

;;; ——— Step 3: Generate browser-compatible ECE source ———
;;;
;;; We read ece.lisp as CL forms (using ECE's readtable) and filter out
;;; I/O functions that need browser-specific replacements. JSCL supports
;;; handler-case and eval-when, so those pass through unchanged.

(defun read-ece-forms ()
  "Read all forms from ece.lisp using the standard CL readtable.
ECE's custom readtable is only needed for .scm files, not .lisp files."
  (let ((path (asdf:system-relative-pathname :ece "src/ece.lisp")))
    (with-open-file (stream path)
      (let ((*package* (find-package :ece))
            (eof (gensym)))
        (loop for form = (read stream nil eof)
              until (eq form eof)
              collect form)))))

(defun skip-form-p (form skip-names)
  "Return T if FORM should be filtered out of browser build."
  (and (listp form)
       (let ((head (car form)))
         (or
          ;; (defun NAME ...) where NAME is in skip list
          (and (eq head 'cl:defun)
               (member (string (cadr form)) skip-names :test #'string-equal))
          ;; Top-level (ece-load ...) call
          (and (symbolp head)
               (string-equal (symbol-name head) "ECE-LOAD"))
          ;; (defun repl ...)
          (and (eq head 'cl:defun)
               (string-equal (symbol-name (cadr form)) "REPL"))))))

(defun generate-browser-ece ()
  "Generate JSCL-compatible ECE source by filtering I/O forms at the CL level."
  (let ((forms (read-ece-forms))
        ;; Only I/O functions that need browser replacements
        (skip-names '("ece-read" "ece-display" "ece-newline"
                       "ece-load" "ece-save-continuation!"
                       "ece-load-continuation" "ece-clear-screen" "ece-sleep"
                       "ece-try-eval")))
    (with-output-to-string (out)
      (format out "(in-package :ece)~%~%")
      (let ((*package* (find-package :ece))
            (*print-case* :downcase)
            (*print-circle* t))
        (dolist (form forms)
          (unless (skip-form-p form skip-names)
            (prin1 form out)
            (terpri out)
            (terpri out)))))))

;;; ——— Step 4: Browser I/O patches ———

(defvar *patches-source*
  "(in-package :ece)

;;; Output buffer for browser mode
(defvar *output-buffer* \"\")

;;; Patched I/O primitives — write to buffer instead of stdout
(defun ece-display (obj)
  (setf *output-buffer*
        (concatenate 'string *output-buffer* (princ-to-string obj)))
  obj)

(defun ece-newline ()
  (setf *output-buffer*
        (concatenate 'string *output-buffer* (string #\\Newline)))
  nil)

;;; Not needed in browser (we pre-parse everything)
(defun ece-read ()
  *eof-sentinel*)

;;; Safe eval wrapper (avoids finish-output and condition system issues in JSCL)
(defun ece-try-eval (expr)
  (evaluate expr))

;;; Bundled ece-load — look up pre-parsed forms from hash table
(defun ece-load (filename)
  (let ((forms (gethash filename *bundled-sources*)))
    (when (null forms)
      (error (format nil \"No bundled source for: ~A\" filename)))
    (let ((result nil))
      (dolist (expr forms result)
        (setf result (evaluate expr))))))

;;; No-ops for browser
(defun ece-save-continuation! (filename value)
  nil)

(defun ece-load-continuation (filename)
  nil)

(defun ece-clear-screen ()
  nil)

(defun ece-sleep (seconds)
  nil)

;;; finish-output shim (used by some code paths)
(unless (fboundp 'finish-output)
  (defun finish-output (&optional stream)
    nil))
")

;;; ——— Step 5: Browser boot code ———

(defvar *browser-boot-source*
  "(in-package :ece)

(let ((console-error (jscl-xc::oget #j:console \"error\")))
  (handler-case
    (progn
      ;;; Load prelude (from bundled sources)
      (ece-load \"prelude.scm\")

      ;;; Load game files (from bundled sources)
      (ece-load \"game/engine.scm\")
      (ece-load \"game/dice.scm\")
      (ece-load \"game/items.scm\")
      (ece-load \"game/combat.scm\")
      (ece-load \"game/bestiary.scm\")
      (ece-load \"game/content.scm\")

      ;;; Load browser I/O code (defines browser-step, browser-read-line)
      (ece-load \"browser-boot.scm\")

      ;;; Install browser-mode read-line and init player
      (evaluate '(begin
        (define (read-line) (browser-read-line))
        (init-player!)))

      ;;; Expose browserStep to JS
      (setf (jscl-xc::oget #j:window \"browserStep\")
            (lambda (input)
              (let ((cl-input (if input (jscl-xc::clstring input) nil)))
                (setf *output-buffer* \"\")
                (evaluate (list 'browser-step cl-input))
                (jscl-xc::jsstring *output-buffer*)))))
    (error (e)
      (funcall console-error
               (jscl-xc::jsstring (format nil \"[dunge] Boot error: ~A\" e))))))
")

;;; ——— Step 6: HTML template ———

(defvar *html-template*
  "<!DOCTYPE html>
<html lang=\"en\">
<head>
<meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
<title>Dunge</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  background: #1a1a2e;
  color: #e0e0e0;
  font-family: 'Courier New', Courier, monospace;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 2rem 1rem;
  min-height: 100vh;
}
#game {
  max-width: 640px;
  width: 100%;
}
#game-output pre {
  white-space: pre-wrap;
  word-wrap: break-word;
  margin: 0;
  padding: 0;
  line-height: 1.5;
  font-size: 1rem;
}
#game-controls {
  margin-top: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}
.choice-btn {
  background: #16213e;
  color: #e0e0e0;
  border: 1px solid #0f3460;
  padding: 0.6rem 1rem;
  font-family: inherit;
  font-size: 1rem;
  cursor: pointer;
  text-align: left;
  transition: background 0.15s;
}
.choice-btn:hover {
  background: #0f3460;
}
.choice-btn:focus {
  outline: none;
  border-color: #e94560;
  box-shadow: 0 0 6px rgba(233, 69, 96, 0.4);
}
.prompt-wrapper {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}
.prompt-label {
  font-size: 1rem;
}
.prompt-input {
  background: #16213e;
  color: #e0e0e0;
  border: 1px solid #0f3460;
  padding: 0.5rem;
  font-family: inherit;
  font-size: 1rem;
  outline: none;
}
.prompt-input:focus {
  border-color: #e94560;
}
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}
.fade-in {
  animation: fadeIn 150ms ease-in;
}
#build-version {
  margin-top: 3rem;
  font-size: 0.7rem;
  color: #555;
  text-align: center;
}
</style>
</head>
<body>
<div id=\"game\">
  <div id=\"game-output\"></div>
  <div id=\"game-controls\"></div>
  <div id=\"build-version\">~A</div>
</div>
~A
</body>
</html>
")

;;; ——— Step 7: JS rendering logic ———

(defvar *js-renderer*
  "
// Parse output buffer and render to DOM
function renderStep(output) {
  var outputEl = document.getElementById('game-output');
  var controlsEl = document.getElementById('game-controls');
  outputEl.innerHTML = '';
  controlsEl.innerHTML = '';

  if (output === null || output === undefined || output === 'WAITING') return;

  var lines = output.split('\\n');
  var textLines = [];
  var choices = [];
  var promptText = null;

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    // Detect choice lines: '  N. Label'
    var choiceMatch = line.match(/^\\s+(\\d+)\\.\\s+(.+)$/);
    // Detect prompt: '> ' at end (read-choice) or 'question > ' (handle-prompt)
    var promptMatch = line.match(/^(.+?)\\s*>\\s*$/);

    if (choiceMatch) {
      choices.push({ number: choiceMatch[1], label: choiceMatch[2] });
    } else if (promptMatch && i === lines.length - 1) {
      // Last line is a prompt
      promptText = promptMatch[1];
    } else if (line === '> ' || line === '>') {
      // Skip bare prompt markers
    } else {
      textLines.push(line);
    }
  }

  // Render text
  if (textLines.length > 0) {
    var pre = document.createElement('pre');
    // Remove trailing empty lines
    while (textLines.length > 0 && textLines[textLines.length - 1].trim() === '') {
      textLines.pop();
    }
    pre.textContent = textLines.join('\\n');
    outputEl.appendChild(pre);
  }

  // Render choices as buttons
  if (choices.length > 0) {
    choices.forEach(function(c) {
      var btn = document.createElement('button');
      btn.className = 'choice-btn';
      btn.textContent = c.label;
      btn.onclick = function() { step(c.number); };
      controlsEl.appendChild(btn);
    });
  }
  // Render text prompt
  else if (promptText) {
    var wrapper = document.createElement('div');
    wrapper.className = 'prompt-wrapper';
    var label = document.createElement('label');
    label.className = 'prompt-label';
    label.textContent = promptText;
    var input = document.createElement('input');
    input.type = 'text';
    input.className = 'prompt-input';
    var btn = document.createElement('button');
    btn.className = 'choice-btn';
    btn.textContent = 'Submit';
    var submitFn = function() {
      if (input.value.trim()) { step(input.value); }
    };
    btn.onclick = submitFn;
    input.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') submitFn();
    });
    wrapper.appendChild(label);
    wrapper.appendChild(input);
    wrapper.appendChild(btn);
    controlsEl.appendChild(wrapper);
    input.focus();
  }

  // Auto-focus first choice button
  var firstBtn = controlsEl.querySelector('.choice-btn');
  if (firstBtn && !promptText) {
    firstBtn.focus();
  }

  // Apply fade-in
  outputEl.classList.remove('fade-in');
  controlsEl.classList.remove('fade-in');
  void outputEl.offsetWidth;
  outputEl.classList.add('fade-in');
  controlsEl.classList.add('fade-in');

  // Scroll to top
  window.scrollTo(0, 0);
}

// Keyboard navigation for choice buttons
document.addEventListener('keydown', function(e) {
  // Skip when text input is focused
  if (document.activeElement && document.activeElement.tagName === 'INPUT') return;

  var controlsEl = document.getElementById('game-controls');
  var buttons = controlsEl.querySelectorAll('.choice-btn');
  if (buttons.length === 0) return;

  // Number keys 1-9: activate corresponding choice
  var num = parseInt(e.key);
  if (num >= 1 && num <= 9 && num <= buttons.length) {
    e.preventDefault();
    buttons[num - 1].click();
    return;
  }

  // Arrow key navigation
  if (['ArrowDown', 'ArrowRight', 'ArrowUp', 'ArrowLeft'].indexOf(e.key) === -1) return;
  e.preventDefault();

  var currentIndex = -1;
  for (var i = 0; i < buttons.length; i++) {
    if (buttons[i] === document.activeElement) { currentIndex = i; break; }
  }

  var nextIndex;
  if (e.key === 'ArrowDown' || e.key === 'ArrowRight') {
    nextIndex = (currentIndex + 1) % buttons.length;
  } else {
    nextIndex = currentIndex <= 0 ? buttons.length - 1 : currentIndex - 1;
  }
  buttons[nextIndex].focus();
});

function step(input) {
  var output = window.browserStep(input === undefined ? null : input);
  renderStep(output);
}

// Start the game
window.addEventListener('load', function() {
  // Small delay to ensure JSCL is fully initialized
  setTimeout(function() { step(null); }, 100);
});
")

;;; ——— Build ———

(defun main ()
  ;; 1. Bootstrap JSCL
  (format t "~&Loading JSCL...~%")
  (let ((*default-pathname-defaults* *jscl-dir*))
    (load (merge-pathnames "jscl.lisp" *jscl-dir*)))
  (format t "~&Bootstrapping JSCL...~%")
  (let ((jscl-dist (namestring (merge-pathnames "dist/" *jscl-dir*))))
    (uiop:symbol-call :jscl-xc :bootstrap jscl-dist "jscl"))
  (format t "~&JSCL ready.~%")

  ;; 2. Generate temp files
  (format t "~&Pre-parsing .scm files...~%")
  (let* ((bundled-path (write-temp-file "bundled-sources.lisp"
                                         (generate-bundled-sources)))
         (browser-ece (generate-browser-ece))
         (browser-ece-path (write-temp-file "browser-ece.lisp" browser-ece))
         (patches-path (write-temp-file "patches.lisp" *patches-source*))
         (boot-path (write-temp-file "browser-boot-cl.lisp" *browser-boot-source*))
         (temp-files (list bundled-path browser-ece-path patches-path boot-path)))

    (ensure-directories-exist *dist-dir*)

    ;; 3. Compile with JSCL
    (format t "~&Compiling with JSCL...~%")
    (funcall (find-symbol "COMPILE-APPLICATION" :jscl-xc)
             (list browser-ece-path
                   patches-path
                   bundled-path
                   boot-path)
             (merge-pathnames "dunge.js" *dist-dir*))
    (format t "~&Compilation complete.~%")

    ;; 4. Build standalone index.html
    (format t "~&Building standalone index.html...~%")
    (let* ((jscl-js (uiop:read-file-string
                     (merge-pathnames "dist/jscl.js" *jscl-dir*)))
           (dunge-js (uiop:read-file-string
                      (merge-pathnames "dunge.js" *dist-dir*)))
           (version (get-build-version))
           (version-str (format nil "v ~A &middot; ~A" (car version) (cdr version))))
      (format t "~&Build version: v ~A · ~A~%" (car version) (cdr version))
      (with-open-file (out (merge-pathnames "index.html" *dist-dir*)
                           :direction :output :if-exists :supersede)
        (format out *html-template*
                version-str
                (format nil "<script>~%~A~%</script>~%<script>~%~A~%</script>~%<script>~%~A~%</script>"
                        jscl-js dunge-js *js-renderer*))))

    ;; 5. Cleanup
    (cleanup-temp-files temp-files)
    ;; Remove intermediate dunge.js (it's inlined in index.html)
    (let ((dunge-js-path (merge-pathnames "dunge.js" *dist-dir*)))
      (when (probe-file dunge-js-path)
        (delete-file dunge-js-path))))

  (format t "~&=== Build complete! ===~%")
  (format t "~&Output: ~A~%" (namestring (merge-pathnames "index.html" *dist-dir*))))

(main)
(uiop:quit)
