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

(defparameter +adaptation-generated-dungeon-target+ "generated:dungeon:*")

(defparameter +adaptation-encounters+
  '((:watchful-shadow
     :hp 2
     :str 8
     :damage 1)))

(defun load-adaptation-example ()
  (load-dunge-file
   (asdf:system-relative-pathname "dunge/examples"
                                  "examples/adaptation.dunge")))

(defun adaptation-background-data (background)
  (or (find background +adaptation-backgrounds+ :key #'first :test #'eq)
      (error "Unknown adaptation background ~S." background)))

(defun adaptation-background-value (background key &optional default)
  (getf (rest (adaptation-background-data background)) key default))

(defun adaptation-encounter-data (enemy-id)
  (or (find enemy-id +adaptation-encounters+ :key #'first :test #'eq)
      (error "Unknown adaptation encounter ~S." enemy-id)))

(defun adaptation-encounter-value (enemy-id key &optional default)
  (getf (rest (adaptation-encounter-data enemy-id)) key default))

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

(defun adaptation-room-description (segment loot encounter depth)
  (format nil "~A A find waits here: ~A. A possible encounter stirs nearby: ~A. This chamber sits at depth ~D."
          (adaptation-segment-description segment)
          (adaptation-result-label loot)
          (adaptation-result-label encounter)
          depth))

(defun apply-adaptation-room-results (game results)
  (declare (ignore game))
  results)

(defun ensure-adaptation-room-encounter (game room)
  (let ((encounter-result (first (table-result-encounters
                                  (generated-room-results room)))))
    (when encounter-result
      (let ((enemy-id (second encounter-result)))
        (ensure-room-encounter-state
         game
         room
         encounter-result
         :hp (adaptation-encounter-value enemy-id :hp 3)
         :str (adaptation-encounter-value enemy-id :str 10)
         :damage (adaptation-encounter-value enemy-id :damage 1))))))

(defun find-adaptation-first-room (game)
  (find-if (lambda (room)
             (and (eq (generated-room-zone room) :dungeon)
                  (= (generated-room-depth room) 1)))
           (game-generated-rooms game)))

(defun adaptation-dungeon-rooms (game)
  (remove-if-not (lambda (room)
                   (eq (generated-room-zone room) :dungeon))
                 (game-generated-rooms game)))

(defun note-adaptation-dungeon-state (game)
  (let ((rooms (adaptation-dungeon-rooms game)))
    (setf (gethash :rooms-generated (game-global-state game)) (length rooms)
          (gethash :dungeon-depth (game-global-state game))
          (if rooms
              (loop for room in rooms
                    maximize (generated-room-depth room))
              0)
          (gethash :first-room-generated (game-global-state game))
          (not (null (find-adaptation-first-room game)))))
  game)

(defun adaptation-room-content (game depth)
  (let* ((segment-result (roll-table game :room-segment))
         (loot-result (roll-table game :starter-loot))
         (encounter-result (roll-table game :starter-encounter))
         (resolved-results
           (resolve-table-result-data game
                                      (list segment-result
                                            loot-result
                                            encounter-result))))
    (values segment-result
            resolved-results
            (adaptation-room-description
             (adaptation-result-id segment-result)
             (second resolved-results)
             (third resolved-results)
             depth))))

(defun create-adaptation-dungeon-room (game depth &key title description results
                                                    exits)
  (multiple-value-bind (segment-result resolved-results room-description)
      (if (and title description results)
          (values nil results description)
          (adaptation-room-content game depth))
    (let ((room (create-generated-room
                 game
                 :zone :dungeon
                 :depth depth
                 :title (or title
                            (and segment-result
                                 (adaptation-result-label segment-result))
                            (format nil "Dungeon Depth ~D" depth))
                 :description room-description
                 :results resolved-results
                 :exits exits)))
      (ensure-adaptation-room-encounter game room)
      (note-adaptation-dungeon-state game)
      room)))

(defun adaptation-graph-link (game)
  (let* ((result (resolve-table-result-data game (roll-table game :dungeon-link)))
         (exits (table-result-exits result)))
    (unless (= 1 (length exits))
      (error "Adaptation graph link table must resolve one exit; got ~S."
             result))
    (unless (equal +adaptation-generated-dungeon-target+ (cdr (first exits)))
      (error "Adaptation graph link must target ~S; got ~S."
             +adaptation-generated-dungeon-target+
             result))
    (first exits)))

(defun ensure-adaptation-room-exit (game room direction)
  (let ((target (generated-room-exit-target room direction)))
    (if target
        (find-generated-room game target :errorp t)
        (let* ((link (adaptation-graph-link game))
               (link-direction (car link)))
          (unless (eq link-direction direction)
            (error "Adaptation graph link expected ~S, got ~S."
                   direction
                   link-direction))
          (let ((next-room
                  (create-adaptation-dungeon-room
                   game
                   (1+ (generated-room-depth room)))))
            (link-generated-rooms room direction next-room
                                  :reverse-direction :back)
            (note-adaptation-dungeon-state game)
            next-room)))))

(defun ensure-adaptation-first-room (game)
  (let ((room
          (or (find-adaptation-first-room game)
              (let* ((segment-result (roll-table game :room-segment))
                     (loot-result (roll-table game :starter-loot))
                     (encounter-result (roll-table game :starter-encounter))
                     (exit-result (roll-table game :starter-exit))
                     (resolved-results
                       (resolve-table-result-data game
                                                  (list segment-result
                                                        loot-result
                                                        encounter-result
                                                        exit-result)))
                     (segment (adaptation-result-id segment-result))
                     (room (create-adaptation-dungeon-room
                            game
                            1
                            :title (adaptation-result-label segment-result)
                            :description (adaptation-first-room-description
                                          segment
                                          (second resolved-results)
                                          (third resolved-results))
                            :results resolved-results
                            :exits (table-result-exits resolved-results))))
                (apply-adaptation-room-results game resolved-results)
                room))))
    (ensure-adaptation-room-exit game room :deeper)
    (ensure-adaptation-room-encounter game room)
    (note-adaptation-dungeon-state game)
    room))

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
