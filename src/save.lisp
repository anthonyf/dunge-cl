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
  (ensure-runtime-property-list state "state")
  (loop for (key value) on state by #'cddr
        when (eq key field)
          do (return value)
        finally (return default)))

(defun runtime-state-has-field-p (state field)
  (ensure-runtime-property-list state "state")
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

(defun runtime-maybe-string-value (value label)
  (unless (or (null value) (stringp value))
    (error "Runtime ~A must be a string or NIL; got ~S." label value))
  value)

(defun runtime-maybe-keyword-value (value label)
  (unless (or (null value) (keywordp value))
    (error "Runtime ~A must be a keyword or NIL; got ~S." label value))
  value)

(defun runtime-keyword-value (value label)
  (unless (keywordp value)
    (error "Runtime ~A must be a keyword; got ~S." label value))
  value)

(defun runtime-boolean-value (value label)
  (unless (or (eq value t) (null value))
    (error "Runtime ~A must be a boolean; got ~S." label value))
  value)

(defun runtime-keyword-list-value (value label)
  (ensure-runtime-list value label)
  (mapcar (lambda (entry)
            (unless (keywordp entry)
              (error "Runtime ~A entries must be keywords; got ~S."
                     label
                     entry))
            entry)
          value))

(defun runtime-state-pair-p (entry)
  (consp entry))

(defun restore-runtime-global-state (game world globals)
  (ensure-runtime-list globals ":GLOBALS")
  (dolist (entry globals)
    (unless (runtime-state-pair-p entry)
      (error "Runtime global state entry must be (KEY . VALUE)."))
    (setf (gethash (ensure-declared-global-state-key game (car entry))
                   (world-globals world))
          (cdr entry))))

(defun restore-runtime-taken-choices (world taken-choices)
  (ensure-runtime-list taken-choices ":TAKEN-CHOICES")
  (clrhash (world-taken world))
  (dolist (choice-id taken-choices)
    (setf (gethash (choice-id-key choice-id) (world-taken world)) t)))

(defun restore-runtime-local-state-entry (game world entry)
  (ensure-runtime-property-list entry "local state entry")
  (let* ((room-name (runtime-state-required-field entry :room))
         (entity-id (runtime-state-required-field entry :entity))
         (state (runtime-state-field entry :state nil))
         (room (find-room game room-name))
         (entity (gethash (scene-id-key entity-id) (scene-index room))))
    (unless (and (typep entity 'entity) (state-declarations entity))
      (error "No saveable entity ~S in room ~S." entity-id room-name))
    (ensure-runtime-list state "local :STATE")
    (dolist (state-entry state)
      (unless (runtime-state-pair-p state-entry)
        (error "Runtime local state entry must be (KEY . VALUE)."))
      (setf (gethash (ensure-declared-state-key entity (car state-entry))
                     (entity-state world entity))
            (cdr state-entry)))))

(defun restore-runtime-table-state-entry (game world entry)
  (ensure-runtime-property-list entry "table state entry")
  (let* ((table-id (runtime-state-required-field entry :table))
         (sequence-index (runtime-state-field entry :sequence-index 0))
         (deck-drawn (runtime-state-field entry :deck-drawn nil))
         (state (world-table-state world (find-table game table-id))))
    (setf (table-state-sequence-index state)
          (non-negative-integer-value sequence-index "Table sequence index"))
    (ensure-runtime-list deck-drawn "table :DECK-DRAWN")
    (clrhash (table-state-deck-drawn state))
    (dolist (ordinal deck-drawn)
      (setf (gethash (non-negative-integer-value ordinal "Deck drawn ordinal")
                     (table-state-deck-drawn state))
            t))))

(defun restore-runtime-player-state (game world player-state)
  (ensure-runtime-list player-state ":PLAYER")
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
          (non-negative-integer-value
           (runtime-state-field state :rng-state (game-random-seed game))
           "Runtime RNG state"))
    (ensure-runtime-list roll-log ":ROLL-LOG")
    (setf (world-roll-log world) (reverse roll-log))
    (restore-runtime-player-state game world (runtime-state-field state :player nil))
    (restore-runtime-global-state game world (runtime-state-field state :globals nil))
    (let ((locals (runtime-state-field state :locals nil)))
      (ensure-runtime-list locals ":LOCALS")
      (dolist (entry locals)
        (restore-runtime-local-state-entry game world entry)))
    (let ((tables (runtime-state-field state :tables nil)))
      (ensure-runtime-list tables ":TABLES")
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
