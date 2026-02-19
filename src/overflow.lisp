(in-package #:dunge)

(defvar *overflow-choices* nil)

(make-room 'overflow-menu "..."
  (lambda (ctx)
    (declare (ignore ctx))
    (append *overflow-choices*
            (list (return-choice "Back")))))

(defun in-overflow-p ()
  "Return t if overflow-menu is anywhere on the vignette stack."
  (member (room 'overflow-menu) *vignette-stack*))

(defun append-overflow-choice (choices)
  (if (and *overflow-choices* (not (in-overflow-p)))
      (append choices (list (gosub-choice "..." (room 'overflow-menu))))
      choices))
