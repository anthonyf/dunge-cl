(defpackage dunge
  (:use #:cl)
  (:import-from #:trivia
		#:match)
  (:local-nicknames (#:ps #:parenscript))
  (:shadow #:do
	   #:set)
  (:export #:defpassage
	   #:set
	   #:p
	   #:link
	   #:quit))

(uiop:define-package dunge-user
  (:use #:dunge))


(uiop:define-package dunge-game
  (:use #:dunge))
