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

(defun init-overflow-menu ()
  "Populate *overflow-choices* with Character and Inventory entries.
Call after character creation is complete."
  (setf *overflow-choices*
        (list (gosub-choice "Character" (room 'character-sheet))
              (gosub-choice "Inventory" (room 'inventory-view)))))

(defun append-overflow-choice (choices)
  (if (and *overflow-choices* (not (in-overflow-p)))
      (append choices (list (gosub-choice "..." (room 'overflow-menu))))
      choices))
