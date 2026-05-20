(in-package #:dunge)

(defun basic-example ()
  (evaluate
   (game (room "entrance"
	       (p "You stand at the entrance of a dark dungeon.")
	       (choice
		 ("Look in the chest" (gosub "chest"))
		 ("Enter the dungeon" (goto "hallway"))
		 ("Leave" (quit))))
	 (room "chest"
	       (p "Inside the chest is a brass key."))
	 (room "hallway"
	       (p "You are on a long dark hallway.")))))
