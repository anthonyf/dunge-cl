(in-package #:dunge-examples)

(defun basic-example ()
  (evaluate
   (game (room "entrance"
	       (p "You stand at the entrance of a dark dungeon.")
	       (container "chest"
		 :description "You see a chest in the corner of the room."
		 :open-choice "Open the chest"
		 :contents ((item "A brass key")
			    (item "A sword"))
		 :close-choice "Close the chest")
	       (choice
		 ("Enter the dungeon" (goto "hallway"))
		 ("Leave" (quit))))
	 (room "hallway"
	       (p "You are on a long dark hallway.")))))
