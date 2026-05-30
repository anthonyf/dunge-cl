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

(defun adaptation-titleize-keyword (keyword)
  (string-capitalize
   (substitute #\Space #\-
               (string-downcase (symbol-name keyword)))))

(defun adaptation-result-id (result)
  (when (and (consp result)
             (keywordp (second result)))
    (second result)))

(defun adaptation-result-label (result)
  (cond
    ((adaptation-result-id result)
     (adaptation-titleize-keyword (adaptation-result-id result)))
    ((keywordp result)
     (adaptation-titleize-keyword result))
    (t
     (princ-to-string result))))

(defun adaptation-segment-description (segment)
  (ecase segment
    (:white-arch
     "The white arch repeats itself in the dark, its stone too smooth to be old.")
    (:cold-gallery
     "A cold gallery stretches ahead, with every footstep returning a little late.")
    (:root-crossing
     "Black roots split the floor and knot around something buried below.")))

(defun adaptation-first-room-description (segment loot encounter)
  (format nil "~A A first find waits here: ~A. A possible encounter stirs nearby: ~A."
          (adaptation-segment-description segment)
          (adaptation-result-label loot)
          (adaptation-result-label encounter)))

(defun find-adaptation-first-room (game)
  (find-if (lambda (room)
             (and (eq (generated-room-zone room) :dungeon)
                  (= (generated-room-depth room) 1)))
           (game-generated-rooms game)))

(defun ensure-adaptation-first-room (game)
  (or (find-adaptation-first-room game)
      (let* ((segment-result (roll-table game :room-segment))
             (loot-result (roll-table game :starter-loot))
             (encounter-result (roll-table game :starter-encounter))
             (segment (adaptation-result-id segment-result))
             (room (create-generated-room
                    game
                    :zone :dungeon
                    :depth 1
                    :title (adaptation-result-label segment-result)
                    :description (adaptation-first-room-description
                                  segment
                                  loot-result
                                  encounter-result)
                    :results (list segment-result
                                   loot-result
                                   encounter-result)
                    :exits '((:back . "threshold")))))
        (setf (gethash :rooms-generated (game-global-state game)) 1
              (gethash :dungeon-depth (game-global-state game)) 1
              (gethash :first-room-generated (game-global-state game)) t)
        room)))

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

(defun load-instanced-adaptation-example (&key
                                            (name "Generated Delver")
                                            (background :wanderer))
  (let ((game (load-generated-adaptation-example
               :name name
               :background background)))
    (ensure-adaptation-first-room game)
    game))

(defun adaptation-example ()
  (evaluate (load-adaptation-example)))

(defun generated-adaptation-example ()
  (evaluate-session (make-runtime-session (load-generated-adaptation-example))))

(defun instanced-adaptation-example ()
  (let* ((game (load-instanced-adaptation-example))
         (room (ensure-adaptation-first-room game)))
    (evaluate-session (make-runtime-session game :current-room (name room)))))
