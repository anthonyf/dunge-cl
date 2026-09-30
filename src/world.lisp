(in-package #:dunge)

;;; Play state
;;;
;;; A GAME is an immutable definition. Everything that changes during play
;;; lives in a WORLD: the generator and roll log, global, player and entity
;;; state, taken choices, table positions, and where the player is. A world is
;;; made fresh from a game's declarations, copied for undo, and turned into a
;;; property list for saves.

(defstruct (table-state (:copier nil))
  (sequence-index 0)
  (deck-drawn (make-hash-table :test 'eql)))

(defstruct (world (:constructor %make-world) (:copier nil))
  (rng-state 1)
  ;; Newest roll first; see WORLD-ROLLS.
  (roll-log '())
  (globals (make-hash-table :test 'eql))
  (player (make-hash-table :test 'eql))
  ;; (ROOM-NAME . ENTITY-ID) -> that entity's state table.
  (locals (make-hash-table :test 'equal))
  (taken (make-hash-table :test 'eql))
  ;; Table id -> TABLE-STATE, created on first use.
  (tables (make-hash-table :test 'eql))
  location
  (return-stack '()))

(defun declared-state-table (declarations)
  (let ((table (make-hash-table :test 'eql)))
    (dolist (declaration declarations table)
      (destructuring-bind (name value) declaration
        (setf (gethash (state-key name) table) value)))))

(defun entity-state-key (entity)
  (cons (name (entity-scene entity)) (entity-id entity)))

(defun make-world (game)
  "A fresh world for GAME: every declared value at its start, the generator at
the seed, and the player in the start room."
  (let ((world (%make-world
                :rng-state (game-random-seed game)
                :globals (declared-state-table
                          (game-global-state-declarations game))
                :player (declared-state-table
                         (game-player-state-declarations game))
                :location (and (game-start game)
                               (gethash (game-start game) (room-index game))))))
    (dolist (room (game-rooms game) world)
      (walk-node-tree
       room
       (lambda (node)
         (when (and (typep node 'entity) (state-declarations node))
           (setf (gethash (entity-state-key node) (world-locals world))
                 (declared-state-table (state-declarations node)))))))))

(defun copy-hash-table (table &key (value #'identity))
  (let ((copy (make-hash-table :test (hash-table-test table))))
    (maphash (lambda (key entry)
               (setf (gethash key copy) (funcall value entry)))
             table)
    copy))

(defun copy-world (world)
  "A copy of WORLD that shares nothing mutable with it."
  (%make-world
   :rng-state (world-rng-state world)
   :roll-log (copy-list (world-roll-log world))
   :globals (copy-hash-table (world-globals world))
   :player (copy-hash-table (world-player world))
   :locals (copy-hash-table (world-locals world) :value #'copy-hash-table)
   :taken (copy-hash-table (world-taken world))
   :tables (copy-hash-table
            (world-tables world)
            :value (lambda (state)
                     (make-table-state
                      :sequence-index (table-state-sequence-index state)
                      :deck-drawn (copy-hash-table
                                   (table-state-deck-drawn state)))))
   :location (world-location world)
   :return-stack (copy-list (world-return-stack world))))

(defun restore-world-contents (world snapshot)
  "Make WORLD hold what SNAPSHOT, a copy made by COPY-WORLD, holds. Contexts
keep referring to WORLD itself, so undo restores into it."
  (let ((copy (copy-world snapshot)))
    (setf (world-rng-state world) (world-rng-state copy)
          (world-roll-log world) (world-roll-log copy)
          (world-globals world) (world-globals copy)
          (world-player world) (world-player copy)
          (world-locals world) (world-locals copy)
          (world-taken world) (world-taken copy)
          (world-tables world) (world-tables copy)
          (world-location world) (world-location copy)
          (world-return-stack world) (world-return-stack copy))
    world))

(defun world-rolls (world)
  "WORLD's roll log, oldest roll first."
  (reverse (world-roll-log world)))

(defun entity-state (world entity)
  "The state table for stateful ENTITY in WORLD."
  (or (gethash (entity-state-key entity) (world-locals world))
      (error "Entity ~S has no state." (or (entity-id entity) (name entity)))))

(defun world-table-state (world table)
  (let ((id (table-id table)))
    (or (gethash id (world-tables world))
        (setf (gethash id (world-tables world)) (make-table-state)))))

(defun choice-taken-in-world-p (world id)
  (values (gethash id (world-taken world))))
