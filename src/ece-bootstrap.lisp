(uiop:define-package #:dunge/ece-bootstrap
  (:use #:cl)
  (:export #:start))

(in-package #:dunge/ece-bootstrap)

(defun start ()
  "Start the dunge game using the ECE engine."
  (let ((*default-pathname-defaults*
          (asdf:system-source-directory "dunge")))
    (ece:evaluate (list (intern "LOAD" :ece) "game/main.scm"))))
