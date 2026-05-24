;;; dunge-mode.el --- Major mode for Dunge source files -*- lexical-binding: t; -*-

;; Author: Dunge contributors
;; Keywords: languages, lisp, games

;;; Commentary:

;; Lisp-style editing support for .dunge source files.
;;
;; The compile/load commands send Dunge loader forms to a connected SLY or
;; SLIME session.  They intentionally pass .dunge text through
;; `dunge:load-dunge-string' and files through `dunge:load-dunge-file' instead
;; of evaluating the authored data as Common Lisp code.

;;; Code:

(require 'lisp-mode)

(declare-function sly-connected-p "sly")
(declare-function sly-interactive-eval "sly")
(declare-function slime-connected-p "slime")
(declare-function slime-interactive-eval "slime")

(defgroup dunge nil
  "Editing support for Dunge source files."
  :group 'languages
  :prefix "dunge-")

(defcustom dunge-lisp-backend 'auto
  "Common Lisp interaction backend used by Dunge compile/load commands."
  :type '(choice (const :tag "Auto-detect SLY or SLIME" auto)
                 (const :tag "SLY" sly)
                 (const :tag "SLIME" slime))
  :group 'dunge)

(defcustom dunge-load-system-before-compile t
  "Whether Dunge compile/load commands load the ASDF system first."
  :type 'boolean
  :group 'dunge)

(defconst dunge--source-tags
  '(":game" ":room" ":goto" ":gosub" ":back" ":state" ":eq" ":not" ":and"
    ":or" ":sequence" ":set" ":clear" ":inc" ":dec" ":toggle" ":say" ":if"
    ":option" ":choice" ":entity" ":branch" ":action" ":placed" ":item"
    ":container" ":p" ":quit")
  "Dunge source form tags.")

(defconst dunge--source-fields
  '(":amount" ":body" ":close" ":condition" ":contents" ":description" ":do"
    ":effects" ":else" ":id" ":key" ":label" ":left" ":name" ":once"
    ":open" ":options" ":refs" ":right" ":role" ":room" ":rooms" ":scope"
    ":start" ":state" ":target" ":text" ":then" ":thing" ":title" ":value"
    ":when")
  "Dunge source field names.")

(defconst dunge-font-lock-keywords
  `((,(regexp-opt dunge--source-tags 'symbols) . font-lock-keyword-face)
    (,(regexp-opt dunge--source-fields 'symbols) . font-lock-builtin-face))
  "Font-lock keywords for `dunge-mode'.")

(defvar dunge-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map lisp-mode-shared-map)
    (define-key map (kbd "C-c C-c") #'dunge-compile-load-sexp)
    (define-key map (kbd "C-c C-k") #'dunge-compile-load-file)
    map)
  "Keymap for `dunge-mode'.")

(defvar dunge--command-override-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") #'dunge-compile-load-sexp)
    (define-key map (kbd "C-c C-k") #'dunge-compile-load-file)
    map)
  "High-priority command bindings for `dunge-mode'.")

(defvar-local dunge--command-overrides-active nil
  "Non-nil when Dunge command overrides are active in the current buffer.")

(defvar dunge--emulation-mode-map-alist
  `((dunge--command-overrides-active . ,dunge--command-override-map))
  "Emulation-mode map alist that lets Dunge commands beat Lisp minor modes.")

(add-to-list 'emulation-mode-map-alists 'dunge--emulation-mode-map-alist)

(defun dunge--cl-string (string)
  "Return STRING as a Common Lisp string literal."
  (prin1-to-string string))

(defun dunge--wrap-loader-expression (expression)
  "Return Common Lisp EXPRESSION with optional Dunge system loading."
  (if dunge-load-system-before-compile
      (format "(progn
  (require :asdf)
  (funcall (find-symbol \"LOAD-SYSTEM\" \"ASDF\") :dunge)
  %s)"
              expression)
    expression))

(defun dunge--load-string-expression (source source-name)
  "Build a Common Lisp expression that loads SOURCE named SOURCE-NAME."
  (dunge--wrap-loader-expression
   (format "(funcall (find-symbol \"LOAD-DUNGE-STRING\" \"DUNGE\") %s :source-name %s)"
           (dunge--cl-string source)
           (dunge--cl-string source-name))))

(defun dunge--load-file-expression (file)
  "Build a Common Lisp expression that loads FILE."
  (dunge--wrap-loader-expression
   (format "(funcall (find-symbol \"LOAD-DUNGE-FILE\" \"DUNGE\") %s)"
           (dunge--cl-string (file-truename file)))))

(defun dunge--maybe-require-backend (backend)
  "Try to load BACKEND and return non-nil when it is available."
  (pcase backend
    ('sly (or (featurep 'sly) (require 'sly nil t)))
    ('slime (or (featurep 'slime) (require 'slime nil t)))))

(defun dunge--backend-display-name (backend)
  "Return a display name for BACKEND."
  (upcase (symbol-name backend)))

(defun dunge--backend-connected-p (backend)
  "Return non-nil when BACKEND has an active connection."
  (when (dunge--maybe-require-backend backend)
    (let ((predicate (pcase backend
                       ('sly #'sly-connected-p)
                       ('slime #'slime-connected-p))))
      (and predicate
           (condition-case nil
               (funcall predicate)
             (error nil))))))

(defun dunge--select-backend ()
  "Return the selected connected Lisp backend, or signal a user error."
  (pcase dunge-lisp-backend
    ('auto
     (or (and (dunge--backend-connected-p 'sly) 'sly)
         (and (dunge--backend-connected-p 'slime) 'slime)
         (if (or (dunge--maybe-require-backend 'sly)
                 (dunge--maybe-require-backend 'slime))
             (user-error "SLY or SLIME is available, but no session is connected")
           (user-error "Neither SLY nor SLIME is available; install one or add it to `load-path'"))))
    ((or 'sly 'slime)
     (cond
      ((not (dunge--maybe-require-backend dunge-lisp-backend))
       (user-error "%s is not available; install it or add it to `load-path'"
                   (dunge--backend-display-name dunge-lisp-backend)))
      ((dunge--backend-connected-p dunge-lisp-backend)
       dunge-lisp-backend)
      (t
       (user-error "%s is available, but no session is connected"
                   (dunge--backend-display-name dunge-lisp-backend)))))
    (_
     (user-error "Unknown Dunge Lisp backend: %S" dunge-lisp-backend))))

(defun dunge--send-expression (expression label)
  "Send Common Lisp EXPRESSION to the selected backend with status LABEL."
  (let* ((backend (dunge--select-backend))
         (evaluator (pcase backend
                      ('sly #'sly-interactive-eval)
                      ('slime #'slime-interactive-eval))))
    (unless evaluator
      (user-error "%s interactive evaluation is unavailable"
                  (dunge--backend-display-name backend)))
    (funcall evaluator expression)
    (message "Dunge sent %s to %s" label (dunge--backend-display-name backend))))

(defun dunge--initial-list-start-at-point ()
  "Return the start of the nearest list at point, or nil."
  (condition-case nil
      (cond
       ((looking-at-p "\\s(")
        (point))
       ((nth 1 (syntax-ppss))
        (nth 1 (syntax-ppss)))
       (t
        (backward-sexp)
        (and (looking-at-p "\\s(") (point))))
    (error nil)))

(defun dunge--parent-list-start (start)
  "Return the parent list start for list START, or nil."
  (save-excursion
    (condition-case nil
        (progn
          (goto-char start)
          (backward-up-list)
          (point))
      (error nil))))

(defun dunge--source-form-start-p (start)
  "Return non-nil when START begins a known Dunge source form."
  (save-excursion
    (goto-char start)
    (forward-char 1)
    (skip-syntax-forward " ")
    (and (looking-at ":[^][()\";[:space:]]+")
         (member (downcase (match-string-no-properties 0))
                 dunge--source-tags))))

(defun dunge--bounds-of-sexp-at-point ()
  "Return bounds of the nearest Dunge source form around point."
  (save-excursion
    (let ((start (dunge--initial-list-start-at-point)))
      (catch 'bounds
        (while start
          (when (dunge--source-form-start-p start)
            (goto-char start)
            (forward-sexp)
            (throw 'bounds (cons start (point))))
          (setq start (dunge--parent-list-start start)))
        nil))))

;;;###autoload
(defun dunge-compile-load-sexp ()
  "Compile and load the Dunge source form at point."
  (interactive)
  (let ((bounds (dunge--bounds-of-sexp-at-point)))
    (unless bounds
      (user-error "No Dunge source form at point"))
    (let* ((source (buffer-substring-no-properties (car bounds) (cdr bounds)))
           (source-name (format "%s:%d"
                                (or buffer-file-name (buffer-name))
                                (line-number-at-pos (car bounds)))))
      (dunge--send-expression
       (dunge--load-string-expression source source-name)
       "form"))))

;;;###autoload
(defun dunge-compile-load-file ()
  "Compile and load the current Dunge source file."
  (interactive)
  (unless buffer-file-name
    (user-error "Current buffer is not visiting a file"))
  (when (buffer-modified-p)
    (save-buffer))
  (dunge--send-expression
   (dunge--load-file-expression buffer-file-name)
   (file-name-nondirectory buffer-file-name)))

;;;###autoload
(define-derived-mode dunge-mode lisp-mode "Dunge"
  "Major mode for editing Dunge source files."
  :group 'dunge
  (setq-local comment-start ";")
  (setq-local comment-end "")
  (setq-local lisp-indent-function 'common-lisp-indent-function)
  (setq-local font-lock-defaults '(dunge-font-lock-keywords nil t))
  (setq-local dunge--command-overrides-active t))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.dunge\\'" . dunge-mode))

(provide 'dunge-mode)

;;; dunge-mode.el ends here
