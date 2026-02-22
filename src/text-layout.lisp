(in-package #:dunge)

(defun nl ()
  (with-output-to-string (out)
    (terpri out)))

(defmacro text (&rest items)
  `(with-output-to-string (out)
     ,@(loop for item in items
             collect `(princ ,item out))))
