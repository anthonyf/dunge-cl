(cl:in-package #:dunge-example)

(starting-passage welcome)

(defpassage welcome ()
  (title "Welcome to Dunge!")
  (p "This is a sample game.")

  (link next-passage
	"Continue" (dict :title "This is the overriden title for next passage"))
  )

(defpassage next-passage (title)
  (title title)
  (link welcome
	"Go Back")
  )


