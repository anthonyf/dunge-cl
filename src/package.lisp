(uiop:define-package dunge
  (:use #:cl)
  (:local-nicknames (#:t #:trivia))
  (:shadow #:name)
  (:export #:defpassage
	   #:set-passage
	   #:starting-passage))


(uiop:define-package dunge-example
  (:use #:dunge))
