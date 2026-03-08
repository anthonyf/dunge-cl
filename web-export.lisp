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
;;; ECE uses handler-case, eval-when, with-open-file, and finish-output
;;; which JSCL doesn't support. We read ece.lisp as text and skip those
;;; forms, then provide replacement functions in a patches file.

(defun read-ece-source-lines ()
  "Read ece.lisp as a list of lines."
  (let ((path (asdf:system-relative-pathname :ece "src/ece.lisp")))
    (uiop:read-file-lines path)))

(defun defun-name-match-p (line name)
  "Check if LINE starts a (defun NAME ..."
  (let ((pattern (format nil "(defun ~A " name)))
    (search pattern line :test #'char-equal)))

(defun generate-browser-ece ()
  "Generate JSCL-compatible ECE source by removing incompatible forms."
  (let ((lines (read-ece-source-lines))
        (output (make-array 0 :element-type 'character :adjustable t :fill-pointer 0))
        (skip-depth 0)
        (skipping nil)
        ;; Functions to remove (redefined in patches)
        (skip-defuns '("ece-read" "ece-display" "ece-newline" "ece-try-eval"
                        "ece-string->number" "ece-load" "ece-save-continuation!"
                        "ece-load-continuation" "ece-clear-screen" "ece-sleep")))
    (labels ((write-line-out (line)
               (loop for c across line do (vector-push-extend c output))
               (vector-push-extend #\Newline output))
             (starts-eval-when-p (line)
               (search "(eval-when" line :test #'char-equal))
             (starts-ece-load-call-p (line)
               (search "(ece-load " line :test #'char-equal))
             (starts-repl-defun-p (line)
               (defun-name-match-p line "repl"))
             (should-skip-defun-p (line)
               (some (lambda (name) (defun-name-match-p line name))
                     skip-defuns))
             (count-parens (line)
               "Count net open parens in line (ignoring strings and comments)."
               (let ((net 0) (in-string nil) (prev-char nil))
                 (loop for c across line
                       do (cond
                            (in-string
                             (when (and (char= c #\") (not (char= prev-char #\\)))
                               (setf in-string nil)))
                            ((char= c #\;) (return net))
                            ((char= c #\") (setf in-string t))
                            ((char= c #\() (incf net))
                            ((char= c #\)) (decf net)))
                          (setf prev-char c))
                 net)))
      (dolist (line lines)
        (cond
          ;; Currently skipping a multi-line form
          (skipping
           (incf skip-depth (count-parens line))
           (when (<= skip-depth 0)
             (setf skipping nil)
             (setf skip-depth 0)))
          ;; Start skipping: eval-when block
          ((starts-eval-when-p line)
           (setf skipping t)
           (setf skip-depth (count-parens line))
           (when (<= skip-depth 0) (setf skipping nil)))
          ;; Start skipping: specific defuns
          ((should-skip-defun-p line)
           (setf skipping t)
           (setf skip-depth (count-parens line))
           (when (<= skip-depth 0) (setf skipping nil)))
          ;; Start skipping: ece-load call at end of file
          ((starts-ece-load-call-p line)
           (setf skipping t)
           (setf skip-depth (count-parens line))
           (when (<= skip-depth 0) (setf skipping nil)))
          ;; Start skipping: repl function
          ((starts-repl-defun-p line)
           (setf skipping t)
           (setf skip-depth (count-parens line))
           (when (<= skip-depth 0) (setf skipping nil)))
          ;; Normal line — keep it
          (t (write-line-out line)))))
    output))

;;; ——— Step 4: JSCL compatibility patches ———

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

;;; Simple eval wrapper (no condition system in JSCL)
(defun ece-try-eval (expr)
  (evaluate expr))

;;; Safe number parsing without handler-case
(defun ece-string->number (s)
  (let ((result (parse-integer s :junk-allowed t)))
    result))

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

(let ((console-error (jscl::oget #j:console \"error\")))
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
      (setf (jscl::oget #j:window \"browserStep\")
            (lambda (input)
              (let ((cl-input (if input (jscl::clstring input) nil)))
                (setf *output-buffer* \"\")
                (evaluate (list 'browser-step cl-input))
                (jscl::jsstring *output-buffer*)))))
    (error (e)
      (funcall console-error
               (jscl::jsstring (format nil \"[dunge] Boot error: ~A\" e))))))
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

  // Scroll to top
  window.scrollTo(0, 0);
}

function step(input) {
  var output = window.browserStep(input === undefined ? null : input);
  console.log('[dunge] browserStep returned:', typeof output, JSON.stringify(output));
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
  (uiop:symbol-call :jscl :bootstrap)
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
    (uiop:symbol-call :jscl :compile-application
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
