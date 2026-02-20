;;;; web-export.lisp — Build dunge for the browser via JSCL
;;;;
;;;; Usage:  sbcl --load web-export.lisp
;;;;
;;;; Produces dist/jscl.js, dist/dunge.js, dist/index.html

(require :uiop)

;;; ——— Paths ———

(defvar *project-root*
  (make-pathname :name nil :type nil :defaults *load-truename*))

(defvar *dist-dir*
  (merge-pathnames "dist/" *project-root*))

(defvar *jscl-dir*
  (merge-pathnames "vendor/jscl/" *project-root*))

(defvar *src-dir*
  (merge-pathnames "src/" *project-root*))

;;; ——— Temp file content strings ———

(defvar *patches-source*
  ";;; JSCL compatibility patches — loaded after source files

(in-package #:dunge)

;;; Override perform for p class:
;;; JSCL does not support ~{~A~} format directive.
(defmethod perform (ctx (p p))
  (let ((text (with-output-to-string (s)
                (dolist (item (p-content p))
                  (princ (resolve item) s))
                (terpri s))))
    (out ctx text))
  nil)

;;; Override (setf lookup) — JSCL may not support (defun (setf X) ...) with &rest.
;;; We define set-lookup as a regular function and wire up setf.

(defun set-lookup (value &rest keys)
  (when (null *data-store*)
    (setf *data-store* (make-hash-table :test 'equal)))
  (let ((current *data-store*))
    (loop for key in (butlast keys)
          do (let ((next (gethash key current)))
               (unless (hash-table-p next)
                 (setf next (make-hash-table :test 'equal))
                 (setf (gethash key current) next))
               (setf current next)))
    (let ((final-key (car (last keys))))
      (if (null value)
          (remhash final-key current)
          (setf (gethash final-key current) value))))
  value)

(defun (setf lookup) (value &rest keys)
  (apply #'set-lookup value keys))

;;; CLOS accessor setf workaround.
;;; JSCL's defclass registers writer methods on a mangled symbol via FSET,
;;; but cross-compiled (setf (accessor obj) val) reads symbol.setfvalue.
;;; Bridge the gap with explicit (defun (setf ...) ...) using slot-value.

(defmacro def-setf-patch (accessor slot)
  `(defun (setf ,accessor) (value obj)
     (setf (slot-value obj ',slot) value)))

(def-setf-patch combatant-hp hp)
(def-setf-patch combatant-hp-max hp-max)
(def-setf-patch combatant-armor armor)
(def-setf-patch combatant-str str)
(def-setf-patch combatant-dex dex)
(def-setf-patch combatant-wil wil)
(def-setf-patch char-name name)
(def-setf-patch char-background background)
(def-setf-patch char-gold gold)
(def-setf-patch char-fate fate)
(def-setf-patch char-inventory inventory)
(def-setf-patch item-damage-die damage-die)
(def-setf-patch item-quantity quantity)
(def-setf-patch encounter-first-round-p first-round-p)
(def-setf-patch encounter-log log)
(def-setf-patch encounter-state state)
")


(defvar *persistence-source*
  ";;; Persistence — save/restore game state via localStorage

(in-package #:dunge)

;;; localStorage helpers

(defun ls-get (key)
  (let ((val ((jscl::oget #j:window \"localStorage\" \"getItem\") (jscl::jsstring key))))
    (if (eq val #j:null)
        nil
        (jscl::clstring val))))

(defun ls-set (key value)
  ((jscl::oget #j:window \"localStorage\" \"setItem\")
   (jscl::jsstring key)
   (jscl::jsstring value)))

(defun ls-remove (key)
  ((jscl::oget #j:window \"localStorage\" \"removeItem\")
   (jscl::jsstring key)))

;;; Save / load / clear

(defun save-game ()
  (when (and *player*
             (lookup \"game\" \"save-enabled\")
             (typep (current-vignette) 'room))
    (let* ((state (serialize *player*))
           (room-name (symbol-name (room-id (current-vignette)))))
      (ls-set \"dunge-save\" (write-to-string (list* :room room-name state))))))

(defun load-saved-game ()
  (let ((raw (ls-get \"dunge-save\")))
    (when raw
      (let* ((plist (read-from-string raw))
             (room-name (getf plist :room)))
        (deserialize :player plist)
        (intern room-name \"DUNGE\")))))

(defun clear-save ()
  (ls-remove \"dunge-save\"))

;;; New game function — exposed to JS

(setf (jscl::oget #j:window \"dungeNewGame\")
      (lambda ()
        (clear-save)
        ((jscl::oget #j:window \"location\" \"reload\"))))
")

(defvar *browser-context-source*
  ";;; Browser context — event-driven UI for the browser

(in-package #:dunge)

;;; FFI helpers — must use jscl:: qualified oget/oset since we are
;;; in the dunge/engine package, not the jscl package.

(defun dom-element (tag)
  ((jscl::oget #j:document \"createElement\") (jscl::jsstring tag)))

(defun dom-by-id (id)
  ((jscl::oget #j:document \"getElementById\") (jscl::jsstring id)))

(defun dom-append (parent child)
  ((jscl::oget parent \"appendChild\") child))

(defun dom-set-text (el text)
  (setf (jscl::oget el \"textContent\") (jscl::jsstring text)))

(defun dom-set-html (el html)
  (setf (jscl::oget el \"innerHTML\") (jscl::jsstring html)))

(defun dom-set-attr (el attr val)
  ((jscl::oget el \"setAttribute\") (jscl::jsstring attr) (jscl::jsstring val)))

(defun dom-add-class (el cls)
  ((jscl::oget el \"classList\" \"add\") (jscl::jsstring cls)))

(defun dom-on (el event fn)
  ((jscl::oget el \"addEventListener\") (jscl::jsstring event) fn))

;;; Browser context class
(defclass browser-context ()
  ((output-el :initarg :output-el :accessor ctx-output-el)
   (controls-el :initarg :controls-el :accessor ctx-controls-el)))

(defmethod out ((ctx browser-context) str)
  (let ((pre (dom-element \"pre\")))
    (dom-set-text pre str)
    (dom-append (ctx-output-el ctx) pre)))

(defmethod menu ((ctx browser-context) (choices list))
  (let ((controls (ctx-controls-el ctx)))
    (dolist (c choices)
      (let ((btn (dom-element \"button\"))
            (choice c))
        (dom-set-text btn (choice-label choice))
        (dom-add-class btn \"choice-btn\")
        (dom-on btn \"click\"
                (lambda (ev)
                  (execute-action (choice-action choice))
                  (render-scene ctx)))
        (dom-append controls btn)))))

(defmethod menu ((ctx browser-context) (prompt prompt))
  (let* ((controls (ctx-controls-el ctx))
         (wrapper (dom-element \"div\"))
         (label (dom-element \"label\"))
         (input (dom-element \"input\"))
         (btn (dom-element \"button\"))
         (error-el (dom-element \"div\")))
    (dom-add-class wrapper \"prompt-wrapper\")
    (dom-set-text label (prompt-question prompt))
    (dom-add-class label \"prompt-label\")
    (dom-set-attr input \"type\" \"text\")
    (dom-add-class input \"prompt-input\")
    (dom-set-text btn \"Submit\")
    (dom-add-class btn \"choice-btn\")
    (dom-add-class error-el \"error-msg\")
    (let ((submit-fn
            (lambda (&rest args)
              (let ((val (jscl::clstring (jscl::oget input \"value\"))))
                (if (funcall (prompt-validate-fn prompt) val)
                    (progn
                      (funcall (prompt-action prompt) val)
                      (render-scene ctx))
                    (dom-set-text error-el \"Invalid input, please try again.\"))))))
      (dom-on btn \"click\" submit-fn)
      (dom-on input \"keydown\"
              (lambda (ev)
                (when (string= (jscl::clstring (jscl::oget ev \"key\")) \"Enter\")
                  (funcall submit-fn)))))
    (dom-append wrapper label)
    (dom-append wrapper input)
    (dom-append wrapper btn)
    (dom-append wrapper error-el)
    (dom-append controls wrapper)
    ;; Focus the input
    ((jscl::oget input \"focus\"))))

(defun render-scene (ctx)
  \"Clear output and controls, then perform the current vignette.\"
  (dom-set-html (ctx-output-el ctx) \"\")
  (dom-set-html (ctx-controls-el ctx) \"\")
  (let ((vignette (current-vignette)))
    (when vignette
      (let ((choices (perform ctx vignette)))
        (when choices
          (menu ctx (if (listp choices)
                        (append-overflow-choice choices)
                        choices))))))
  (save-game))

(defun start-game (starting-vignette)
  (setq *vignette-stack* (list starting-vignette))
  (let* ((out-el (dom-by-id \"game-output\"))
         (ctl-el (dom-by-id \"game-controls\"))
         (ctx (make-instance 'browser-context
                             :output-el out-el
                             :controls-el ctl-el)))
    (render-scene ctx)))
")


(defvar *boot-source*
  ";;; Boot — start the game

(in-package #:dunge)

(let ((saved-room (load-saved-game)))
  (if saved-room
      (progn
        (set-lookup t \"game\" \"save-enabled\")
        (start-game (room saved-room)))
      (start-game (room 'start))))
")


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
#game-header {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 1rem;
}
#new-game-btn {
  background: transparent;
  color: #666;
  border: 1px solid #333;
  padding: 0.3rem 0.8rem;
  font-family: inherit;
  font-size: 0.8rem;
  cursor: pointer;
  transition: color 0.15s, border-color 0.15s;
}
#new-game-btn:hover {
  color: #e94560;
  border-color: #e94560;
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
.error-msg {
  color: #e94560;
  font-size: 0.9rem;
  min-height: 1.2em;
}
</style>
</head>
<body>
<div id=\"game\">
  <div id=\"game-header\">
    <button onclick=\"dungeNewGame()\" id=\"new-game-btn\">New Game</button>
  </div>
  <div id=\"game-output\"></div>
  <div id=\"game-controls\"></div>
</div>
<script src=\"jscl.js\"></script>
<script src=\"dunge.js\"></script>
</body>
</html>
")

;;; ——— Test build support ———

(defvar *test-dir*
  (merge-pathnames "tests/web/" *project-root*))

(defvar *test-boot-source*
  ";;; Test boot — run web tests
(in-package #:dunge/web-tests)
(dunge/web-tests::run-web-tests)
")

(defvar *test-html-template*
  "<!DOCTYPE html>
<html lang=\"en\">
<head>
<meta charset=\"utf-8\">
<title>Dunge Web Tests</title>
</head>
<body>
<div id=\"test-results\"></div>
<script src=\"jscl.js\"></script>
<script src=\"tests.js\"></script>
</body>
</html>
")

;;; ——— Build steps ———

(defun write-temp-file (name content)
  "Write CONTENT to a temp file NAME under *project-root*, return pathname."
  (let ((path (merge-pathnames name *project-root*)))
    (with-open-file (out path :direction :output
                              :if-exists :supersede)
      (write-string content out))
    path))

(defun src-file (name)
  (merge-pathnames name *src-dir*))

(defun test-file (name)
  (merge-pathnames name *test-dir*))

(defun source-files ()
  "List of game source files compiled in both normal and test builds."
  (list (src-file "packages.lisp")
        (src-file "utils.lisp")
        (src-file "data-store.lisp")
        (src-file "dice.lisp")
        (src-file "serialize.lisp")
        (src-file "text-layout.lisp")
        (src-file "engine.lisp")
        (src-file "room.lisp")
        (src-file "item.lisp")
        (src-file "character.lisp")
        (src-file "character-creation.lisp")
        (src-file "combat.lisp")
        (src-file "bestiary.lisp")
        (src-file "container.lisp")
        (src-file "overflow.lisp")
        (src-file "character-sheet.lisp")
        (src-file "inventory.lisp")
        (src-file "main.lisp")))

(defun main ()
  (let ((test-mode (member :web-test *features*)))
    (format t "~&=== Dunge Web Export~A ===~%"
            (if test-mode " (Tests)" ""))

    ;; 1. Bootstrap JSCL
    ;; NOTE: We use uiop:symbol-call because the JSCL package does not exist
    ;; at read time — it is created when jscl.lisp is loaded.
    (format t "~&Loading JSCL...~%")
    (let ((*default-pathname-defaults* *jscl-dir*))
      (load (merge-pathnames "jscl.lisp" *jscl-dir*)))
    (format t "~&Bootstrapping JSCL...~%")
    (uiop:symbol-call :jscl :bootstrap)
    (format t "~&JSCL bootstrap complete.~%")

    ;; 2. Write common temp files
    (let ((patches-path (write-temp-file "patches.lisp" *patches-source*)))
      (ensure-directories-exist *dist-dir*)

      (if test-mode
          ;; ——— Test build ———
          (let ((test-boot-path (write-temp-file "test-boot.lisp" *test-boot-source*)))
            (format t "~&Compiling tests...~%")
            (uiop:symbol-call :jscl :compile-application
             (append (source-files)
                     (list patches-path
                           (test-file "test-framework.lisp")
                           (test-file "test-clos.lisp")
                           (test-file "test-data-store.lisp")
                           test-boot-path))
             (merge-pathnames "tests.js" *dist-dir*))
            (format t "~&Compilation complete.~%")

            (format t "~&Copying JSCL runtime...~%")
            (uiop:copy-file
             (merge-pathnames "dist/jscl.js" *jscl-dir*)
             (merge-pathnames "jscl.js" *dist-dir*))

            (format t "~&Writing test.html...~%")
            (with-open-file (out (merge-pathnames "test.html" *dist-dir*)
                                 :direction :output :if-exists :supersede)
              (write-string *test-html-template* out))

            (dolist (p (list patches-path test-boot-path))
              (when (probe-file p)
                (delete-file p))))

          ;; ——— Normal build ———
          (let ((persistence-path (write-temp-file "persistence.lisp" *persistence-source*))
                (browser-path (write-temp-file "browser-context.lisp" *browser-context-source*))
                (boot-path    (write-temp-file "boot.lisp" *boot-source*)))
            (format t "~&Compiling game...~%")
            (uiop:symbol-call :jscl :compile-application
             (append (source-files)
                     (list patches-path
                           persistence-path
                           browser-path
                           boot-path))
             (merge-pathnames "dunge.js" *dist-dir*))
            (format t "~&Compilation complete.~%")

            (format t "~&Copying JSCL runtime...~%")
            (uiop:copy-file
             (merge-pathnames "dist/jscl.js" *jscl-dir*)
             (merge-pathnames "jscl.js" *dist-dir*))

            (format t "~&Writing index.html...~%")
            (with-open-file (out (merge-pathnames "index.html" *dist-dir*)
                                 :direction :output :if-exists :supersede)
              (write-string *html-template* out))

            (dolist (p (list patches-path persistence-path browser-path boot-path))
              (when (probe-file p)
                (delete-file p))))))

    (format t "~&=== Build complete! ===~%")
    (format t "~&Output: ~a~%" (namestring *dist-dir*))))

(main)

(uiop:quit)
