(in-package #:dunge-examples)

(defun load-control-panel-example ()
  (load-dunge-file
   (asdf:system-relative-pathname "dunge/examples"
                                  "examples/control-panel.dunge")))

(defun control-panel-example ()
  (evaluate (load-control-panel-example)))
