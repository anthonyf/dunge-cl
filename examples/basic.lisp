(in-package #:dunge-examples)

(defun basic-example ()
  (evaluate
   (load-dunge-file
    (asdf:system-relative-pathname "dunge/examples"
                                   "examples/basic.dunge"))))
