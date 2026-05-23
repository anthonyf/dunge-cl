(in-package #:dunge-examples)

(defun control-panel-example ()
  (evaluate
   (load-dunge-file
    (asdf:system-relative-pathname "dunge/examples"
                                   "examples/control-panel.dunge"))))
