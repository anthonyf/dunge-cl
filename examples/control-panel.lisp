(in-package #:dunge)

(defun control-panel-example ()
  (evaluate
   (game
    (room "hallway"
	  (p "You are in a long hallway.")

	  (entity "secret door"
	    :id "secret-door"
	    :state ((open nil))
	    (shown-when (= self.open t)
	      (p "A secret door stands open in the east wall.")
	      (choice
		("Enter the secret passage" (goto "hidden room")))))

	  (entity "control panel"
	    :id "panel"
	    :state ((switch :off))
	    :refs ((door "secret-door"))
	    (p "A metal control panel is mounted beside the wall.")
	    (shown-when (= self.switch :off)
	      (p "The switch is down."))
	    (shown-when (= self.switch :on)
	      (p "The switch is up."))
	    (action "Flip the switch"
	      (toggle self.switch)
	      (say "You flip the switch."))
	    (action "Press the button"
	      (if (= self.switch :on)
		  ((set ref.door.open t)
		   (say "Something heavy slides open nearby."))
		  ((say "The button clicks, but nothing happens.")))))

	  (choice
	    ("Leave" (quit))))
    (room "hidden room"
	  (p "Dust hangs in the still air beyond the secret door.")
	  (choice
	    ("Return to the hallway" (goto "hallway"))
	    ("Quit" (quit)))))))
