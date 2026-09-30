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

(defparameter +adaptation-browser-demo-title+ "Dunge Adaptation Testbed")

(defun adaptation-source-path ()
  (asdf:system-relative-pathname "dunge/examples" "examples/adaptation.dunge"))

(defun load-adaptation-example (&key seed)
  "Load the authored adaptation game, before any generation."
  (build-game (read-dunge-file (adaptation-source-path))
              :base-path (adaptation-source-path)
              :seed seed))

(defun adaptation-browser-demo-path ()
  (asdf:system-relative-pathname "dunge/examples"
                                 "examples/adaptation/index.html"))

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

(defun adaptation-roll-total (build expression label)
  (build-roll-dice build expression :label label))

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
    ((and (consp result) (eq (first result) :gold))
     (format nil "~D gold" (second result)))
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

(defun adaptation-room-encounter (results)
  "The encounter spec for the first encounter among RESULTS, or NIL."
  (let ((encounter-result (first (table-result-encounters results))))
    (when encounter-result
      (let ((enemy-id (second encounter-result)))
        (encounter-spec
         encounter-result
         :hp (adaptation-encounter-value enemy-id :hp 3)
         :damage (adaptation-encounter-value enemy-id :damage 1))))))

(defun adaptation-room-content (build depth)
  (let* ((segment-result (build-roll-table build :room-segment))
         (loot-result (build-roll-table build :starter-loot))
         (encounter-result (build-roll-table build :starter-encounter))
         (resolved-results
           (build-resolve build (list segment-result
                                      loot-result
                                      encounter-result))))
    (values segment-result
            resolved-results
            (adaptation-room-description
             (adaptation-result-id segment-result)
             (second resolved-results)
             (third resolved-results)
             depth))))

(defun adaptation-item-catalog (game background)
  "Every item the player can hold: BACKGROUND's starting kit and anything
GAME's tables can award."
  (item-catalog
   (append (adaptation-background-value background :inventory)
           (table-loot-entries game))))

(defun adaptation-ration-choice (game background)
  (ration-choice-form
   :used-slots (used-slots-expression
                (adaptation-item-catalog game background))))

(defun plan-adaptation-room (build depth background
                             &key id title description results)
  "Plan a dungeon room at DEPTH. Rolls its content unless RESULTS are given."
  (let ((game (build-game-object build)))
    (multiple-value-bind (segment-result resolved-results room-description)
        (if results
            (values nil results description)
            (adaptation-room-content build depth))
      (create-generated-room
       build
       :id id
       :zone :dungeon
       :title (or title
                  (and segment-result
                       (adaptation-result-label segment-result))
                  (format nil "Dungeon Depth ~D" depth))
       :description room-description
       :results resolved-results
       :exits (table-result-exits resolved-results)
       :options (list (adaptation-ration-choice game background))
       :encounter (adaptation-room-encounter resolved-results)
       :encounter-options (list (adaptation-ration-choice game background))))))

(defun adaptation-graph-link (build)
  (let* ((result (build-resolve build (build-roll-table build :dungeon-link)))
         (exits (table-result-exits result)))
    (unless (= 1 (length exits))
      (error "Adaptation graph link table must resolve one exit; got ~S."
             result))
    (unless (equal +adaptation-generated-dungeon-target+ (cdr (first exits)))
      (error "Adaptation graph link must target ~S; got ~S."
             +adaptation-generated-dungeon-target+
             result))
    (first exits)))

(defun make-adaptation-player (build &key
                                       (name "Generated Delver")
                                       (background :wanderer))
  "Roll a player for BACKGROUND and return their :PLAYER state declarations."
  (unless (stringp name)
    (error "Adaptation player name must be a string; got ~S." name))
  (let* ((str (adaptation-roll-total build "2d6+3" :adaptation-str))
         (dex (adaptation-roll-total build "2d6+3" :adaptation-dex))
         (wil (adaptation-roll-total build "2d6+3" :adaptation-wil))
         (hp (adaptation-roll-total build "1d6" :adaptation-hp))
         (gold (adaptation-roll-total build "1d6" :adaptation-gold))
         (inventory (adaptation-background-value background :inventory)))
    (player-declarations
     :name name
     :background background
     :str str
     :dex dex
     :wil wil
     :hp hp
     :armor (adaptation-background-value background :armor 0)
     :gold gold
     :fate (adaptation-background-value background :fate 0)
     :inventory inventory
     :catalog (adaptation-item-catalog (build-game-object build) background))))

(defun build-adaptation (build &key (name "Generated Delver")
                                    (background :wanderer))
  "Roll a player and a two-room dungeon. The first room takes the authored
placeholder room's id, so the threshold's authored choice enters it."
  (set-player build (make-adaptation-player build
                                            :name name
                                            :background background))
  (let* ((segment-result (build-roll-table build :room-segment))
         (loot-result (build-roll-table build :starter-loot))
         (encounter-result (build-roll-table build :starter-encounter))
         (exit-result (build-roll-table build :starter-exit))
         (resolved-results
           (build-resolve build (list segment-result
                                      loot-result
                                      encounter-result
                                      exit-result)))
         (first-room (plan-adaptation-room
                      build 1 background
                      :id "placeholder-room"
                      :title (adaptation-result-label segment-result)
                      :description (adaptation-first-room-description
                                    (adaptation-result-id segment-result)
                                    (second resolved-results)
                                    (third resolved-results))
                      :results resolved-results))
         (link (adaptation-graph-link build))
         (deeper-room (plan-adaptation-room build 2 background)))
    (link-rooms first-room (car link) deeper-room :reverse-direction :back)
    (set-initial-global build :rooms-generated 2)
    (set-initial-global build :dungeon-depth 2)
    (set-initial-global build :first-room-generated t)))

(defun load-instanced-adaptation-example (&key
                                            (name "Generated Delver")
                                            (background :wanderer)
                                            seed)
  "Build the adaptation game: a rolled player and a two-room dungeon."
  (build-game (read-dunge-file (adaptation-source-path))
              :base-path (adaptation-source-path)
              :seed seed
              :builder (lambda (build)
                         (build-adaptation build
                                           :name name
                                           :background background))))

(defun write-adaptation-browser-demo (&key
                                        (pathname (adaptation-browser-demo-path))
                                        (title +adaptation-browser-demo-title+)
                                        debug
                                        (if-exists :supersede))
  (write-index-html (load-instanced-adaptation-example)
                    pathname
                    :title title
                    :debug debug
                    :if-exists if-exists))

(defun adaptation-example ()
  (evaluate-session (make-runtime-session (load-instanced-adaptation-example))))
