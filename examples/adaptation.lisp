(in-package #:dunge-examples)

(defun load-adaptation-example ()
  (load-dunge-file
   (asdf:system-relative-pathname "dunge/examples"
                                  "examples/adaptation.dunge")))

(defun adaptation-example ()
  (evaluate (load-adaptation-example)))
