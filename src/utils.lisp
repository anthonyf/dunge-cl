(in-package #:dunge)

(defun trim-whitespace (text)
  (string-trim '(#\Space #\Tab #\Newline #\Return) text))

(defun validate-non-empty-string (text)
  (> (length (trim-whitespace text))
     0))
