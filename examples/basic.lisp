(in-package #:dunge-examples)

(defun load-basic-example ()
  (load-dunge-file
   (asdf:system-relative-pathname "dunge/examples"
                                  "examples/basic.dunge")))

(defun basic-example ()
  (evaluate (load-basic-example)))
