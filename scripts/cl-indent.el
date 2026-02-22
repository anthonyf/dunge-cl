;; Format a Common Lisp file using standard CL indentation.
;; Usage: emacs --batch file.lisp --load scripts/cl-indent.el

(require 'cl-indent)
(lisp-mode)
(setq indent-tabs-mode nil)
(setq make-backup-files nil)
(setq lisp-indent-function #'common-lisp-indent-function)
(indent-region (point-min) (point-max))
(untabify (point-min) (point-max))
(save-buffer)
