(in-package #:dunge)

;;; Saves
;;;
;;; A session's world as a property list, and back.

(defun sorted-state-alist (table)
  (sort (loop for key being the hash-keys of table
                using (hash-value value)
              collect (cons key value))
        #'string<
        :key (lambda (entry)
               (prin1-to-string (car entry)))))

(defun sorted-hash-keys (table)
  (sort (loop for key being the hash-keys of table
              collect key)
        #'string<
        :key #'prin1-to-string))

(defun collect-runtime-table-state (game world)
  (loop for table in (game-tables game)
        for state = (gethash (table-id table) (world-tables world))
        when state
          collect (list :table (table-id table)
                        :sequence-index (table-state-sequence-index state)
                        :deck-drawn (sorted-hash-keys
                                     (table-state-deck-drawn state)))))

(defun collect-runtime-local-state (game world)
  (let (entries)
    (dolist (room (game-rooms game))
      (walk-node-tree
       room
       (lambda (node)
         (when (and (typep node 'entity)
                    (entity-id node)
                    (state-declarations node))
           (push (list :room (name room)
                       :entity (entity-id node)
                       :state (sorted-state-alist (entity-state world node)))
                 entries)))))
    (nreverse entries)))

(defun capture-runtime-state (session)
  "The saveable state of SESSION's world, as a property list."
  (let ((game (runtime-session-game session))
        (world (runtime-session-world session)))
    (list :current-room (runtime-session-current-room-name session)
          :return-stack (runtime-session-return-stack-room-names session)
          :player (sorted-state-alist (world-player world))
          :rng-state (world-rng-state world)
          :roll-log (world-rolls world)
          :globals (sorted-state-alist (world-globals world))
          :locals (collect-runtime-local-state game world)
          :tables (collect-runtime-table-state game world)
          :taken-choices (sorted-hash-keys (world-taken world)))))

(defun runtime-state-field (state field &optional default)
  (check-value state 'property-list "Runtime state")
  (loop for (key value) on state by #'cddr
        when (eq key field)
          do (return value)
        finally (return default)))

(defun runtime-state-has-field-p (state field)
  (check-value state 'property-list "Runtime state")
  (loop for tail on state by #'cddr
        for key = (car tail)
        when (eq key field)
          do (return t)
        finally (return nil)))

(defun runtime-state-required-field (state field)
  (let ((missing '#:missing))
    (let ((value (runtime-state-field state field missing)))
      (when (eq value missing)
        (error "Runtime state is missing required field ~S." field))
      value)))

(defun runtime-state-pair-p (entry)
  (consp entry))

(defun restore-runtime-global-state (game world globals)
  (check-value globals 'proper-list "Runtime :GLOBALS")
  (dolist (entry globals)
    (unless (runtime-state-pair-p entry)
      (error "Runtime global state entry must be (KEY . VALUE)."))
    (setf (gethash (ensure-declared-global-state-key game (car entry))
                   (world-globals world))
          (cdr entry))))

(defun restore-runtime-taken-choices (world taken-choices)
  (check-value taken-choices 'proper-list "Runtime :TAKEN-CHOICES")
  (clrhash (world-taken world))
  (dolist (choice-id taken-choices)
    (setf (gethash (choice-id-key choice-id) (world-taken world)) t)))

(defun restore-runtime-local-state-entry (game world entry)
  (check-value entry 'property-list "Runtime local state entry")
  (let* ((room-name (runtime-state-required-field entry :room))
         (entity-id (runtime-state-required-field entry :entity))
         (state (runtime-state-field entry :state nil))
         (room (find-room game room-name))
         (entity (gethash (scene-id-key entity-id) (scene-index room))))
    (unless (and (typep entity 'entity) (state-declarations entity))
      (error "No saveable entity ~S in room ~S." entity-id room-name))
    (check-value state 'proper-list "Runtime local :STATE")
    (dolist (state-entry state)
      (unless (runtime-state-pair-p state-entry)
        (error "Runtime local state entry must be (KEY . VALUE)."))
      (setf (gethash (ensure-declared-state-key entity (car state-entry))
                     (entity-state world entity))
            (cdr state-entry)))))

(defun restore-runtime-table-state-entry (game world entry)
  (check-value entry 'property-list "Runtime table state entry")
  (let* ((table-id (runtime-state-required-field entry :table))
         (sequence-index (runtime-state-field entry :sequence-index 0))
         (deck-drawn (runtime-state-field entry :deck-drawn nil))
         (state (world-table-state world (find-table game table-id))))
    (setf (table-state-sequence-index state)
          (check-value sequence-index 'non-negative-integer "Table sequence index"))
    (check-value deck-drawn 'proper-list "Runtime table :DECK-DRAWN")
    (clrhash (table-state-deck-drawn state))
    (dolist (ordinal deck-drawn)
      (setf (gethash (check-value ordinal 'non-negative-integer "Deck drawn ordinal")
                     (table-state-deck-drawn state))
            t))))

(defun restore-runtime-player-state (game world player-state)
  (check-value player-state 'proper-list "Runtime :PLAYER")
  (dolist (entry player-state)
    (unless (runtime-state-pair-p entry)
      (error "Runtime player state entry must be (KEY . VALUE)."))
    (setf (gethash (ensure-declared-player-state-key game (car entry))
                   (world-player world))
          (cdr entry))))

(defun plist->world (game state)
  "A world for GAME holding the saved STATE over its declared starting values.
Keys GAME does not declare are errors."
  (let ((world (make-world game))
        (roll-log (runtime-state-field state :roll-log nil)))
    (setf (world-rng-state world)
          (check-value
           (runtime-state-field state :rng-state (game-random-seed game)) 'non-negative-integer
           "Runtime RNG state"))
    (check-value roll-log 'proper-list "Runtime :ROLL-LOG")
    (setf (world-roll-log world) (reverse roll-log))
    (restore-runtime-player-state game world (runtime-state-field state :player nil))
    (restore-runtime-global-state game world (runtime-state-field state :globals nil))
    (let ((locals (runtime-state-field state :locals nil)))
      (check-value locals 'proper-list "Runtime :LOCALS")
      (dolist (entry locals)
        (restore-runtime-local-state-entry game world entry)))
    (let ((tables (runtime-state-field state :tables nil)))
      (check-value tables 'proper-list "Runtime :TABLES")
      (dolist (entry tables)
        (restore-runtime-table-state-entry game world entry)))
    (restore-runtime-taken-choices world
                                   (runtime-state-field state :taken-choices nil))
    (setf (world-location world)
          (find-room game (ensure-runtime-room-name
                           (runtime-state-required-field state :current-room)
                           "current room"))
          (world-return-stack world)
          (mapcar (lambda (room-name) (find-room game room-name))
                  (ensure-runtime-return-stack
                   (runtime-state-field state :return-stack nil))))
    world))

(defun restore-runtime-state (game state)
  "A session for GAME resuming the saved STATE."
  (make-runtime-session game :world (plist->world game state)))

(defun read-runtime-state-form (stream source-name)
  (let ((*read-eval* nil)
        (*readtable* (runtime-state-readtable))
        (eof '#:eof))
    (let ((form (read stream nil eof)))
      (when (eq form eof)
        (error "~A is empty." source-name))
      (let ((extra (read stream nil eof)))
        (unless (eq extra eof)
          (error "~A must contain exactly one top-level form." source-name)))
      form)))

(defun runtime-state-readtable ()
  (let ((readtable (copy-readtable nil)))
    (set-macro-character
     #\#
     (lambda (stream char)
       (declare (ignore stream char))
       (error "Runtime state reader does not allow # reader syntax."))
     nil
     readtable)
    readtable))

(defun read-runtime-state-file (path)
  (with-open-file (stream path :direction :input)
    (read-runtime-state-form stream (namestring (truename path)))))

(defun write-runtime-state-file (session path)
  (with-open-file (stream path
                          :direction :output
                          :if-exists :supersede
                          :if-does-not-exist :create)
    (let ((*print-readably* t)
          (*print-pretty* t))
      (prin1 (capture-runtime-state session) stream)
      (terpri stream)))
  path)

(defun load-runtime-state-file (game path)
  (restore-runtime-state game (read-runtime-state-file path)))
