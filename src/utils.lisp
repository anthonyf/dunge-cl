(uiop:define-package #:dunge/utils
  (:use #:cl)
  (:export #:trim-whitespace
	   #:validate-non-empty-string))

(in-package #:dunge/utils)

(defun trim-whitespace (text)
  (string-trim '(#\Space #\Tab #\Newline #\Return) text))

(defun validate-non-empty-string (text)
  (> (length (trim-whitespace text))
     0))
