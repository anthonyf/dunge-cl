(in-package #:dunge-examples)

(defparameter +adaptation-backgrounds+
  '((:wanderer
     :armor 0
     :fate 0
     :inventory ((:item :lantern)
                 (:supply :ration :count 2)))
    (:delver
     :armor 1
     :fate 0
     :inventory ((:item :rusted-dagger)
                 (:item :lantern)
                 (:supply :ration :count 1)))))

(defun load-adaptation-example ()
  (load-dunge-file
   (asdf:system-relative-pathname "dunge/examples"
                                  "examples/adaptation.dunge")))

(defun adaptation-background-data (background)
  (or (find background +adaptation-backgrounds+ :key #'first :test #'eq)
      (error "Unknown adaptation background ~S." background)))

(defun adaptation-background-value (background key &optional default)
  (getf (rest (adaptation-background-data background)) key default))

(defun adaptation-roll-total (game expression label)
  (roll-dice-value game expression :label label))

(defun make-adaptation-player (game &key
                                      (name "Generated Delver")
                                      (background :wanderer))
  (unless (stringp name)
    (error "Adaptation player name must be a string; got ~S." name))
  (let* ((str (adaptation-roll-total game "2d6+3" :adaptation-str))
         (dex (adaptation-roll-total game "2d6+3" :adaptation-dex))
         (wil (adaptation-roll-total game "2d6+3" :adaptation-wil))
         (hp (adaptation-roll-total game "1d6" :adaptation-hp))
         (gold (adaptation-roll-total game "1d6" :adaptation-gold))
         (inventory (copy-tree
                     (adaptation-background-value background :inventory)))
         (armor (adaptation-background-value background :armor 0))
         (fate (adaptation-background-value background :fate 0)))
    (make-instance 'player
                   :name name
                   :background background
                   :str str
                   :dex dex
                   :wil wil
                   :hp hp
                   :armor armor
                   :gold gold
                   :fate fate
                   :inventory inventory)))

(defun install-adaptation-player (game &key
                                         (name "Generated Delver")
                                         (background :wanderer))
  (setf (game-player game)
        (make-adaptation-player game
                                :name name
                                :background background))
  (values game (game-player game)))

(defun load-generated-adaptation-example (&key
                                            (name "Generated Delver")
                                            (background :wanderer))
  (let ((game (load-adaptation-example)))
    (install-adaptation-player game
                               :name name
                               :background background)
    game))

(defun adaptation-example ()
  (evaluate (load-adaptation-example)))

(defun generated-adaptation-example ()
  (evaluate-session (make-runtime-session (load-generated-adaptation-example))))
