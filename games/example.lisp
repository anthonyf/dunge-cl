(cl:in-package #:dunge-example)

(starting-passage welcome)

(defpassage welcome ()
  (title "Welcome to Dunge!")
  (p "This is a sample game.")

  (p "You can" (choice "Continue" :action (goto next-passage)) "to the next screen")
  
  (link next-passage
	      "Continue" (dict :title "This is the overriden title for next passage"))
  )

(defpassage next-passage (title)
  (title title)
  (link welcome
	"Go Back")
  )


