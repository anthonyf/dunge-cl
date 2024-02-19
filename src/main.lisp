(in-package :dunge)



(defpsmacro p (text)
  `(who-ps-html (:p ,text)))

(defpsmacro title (str)
  "sets the title of the current passage"
  `(who-ps-html (:h1 ,str)))


(defpsmacro link (passage-name link-text)
  `(who-ps-html
      (:a :href "javascript:void(0);"
	  :onclick (ps-inline (call-passage ,passage-name) #\')
	  ,link-text)))

(defpsmacro defpassage (name &body body)
  `((@ passages set)
    ,name (lambda ()
	    (setf (@ ((@ document query-selector) "#dunge-root") inner-h-t-m-l)
		  (ps:who-ps-html ,@body)))))


(defpsmacro start (starting-passage)
  "defines the starting passage in a game"
  `(setf starting-passage ,starting-passage))

(defmacro dunge (&body body)
  `(let ()
     (with-html-output-to-string (s nil :indent t)
       (:html
	(:head
	 :title "Some title to be replaced")
	(:body
	 (:div :id "dunge-root")
	 (:script
	  (str (ps
		 (var passages (new (-Map)))
		 (var starting-passage nil)

		 (defun call-passage (passage-name)
		   (((@ passages get) passage-name)))

		 ,@body
		 (if starting-passage
		     (call-passage starting-passage)
		     (setf (@ document query-selector inner-html)
			   (ps:who-ps-html (:h1 "No starting passage.  Use (start <some-passage>)."))))
		 )))
	 )))))


(defun dunge-compile-ps-file (&key input output)
  (let ((outpath (or output (uiop:make-pathname* :defaults input :type "html")))
	(*ps-print-pretty* t))
    (uiop:with-enough-pathname (enough-outpath :pathname outpath)
      (with-open-file (os enough-outpath :direction :output :if-exists :supersede)
	(write-string (eval `(dunge ,@(uiop:read-file-forms input))) os)))))


(dunge-compile-ps-file :input "games/example.dunge")

(defun main ()
  
  )
