(in-package #:dunge)


(defun make-container (title description open-label contents)
  "A container, like a chest, which contains items"
  (let ((container-room (apply #'make-room (gensym "container")
                               title (append contents
                                             (list (return-choice "Back"))))))
    (group
     (p description)
     (gosub-choice open-label container-room))))
