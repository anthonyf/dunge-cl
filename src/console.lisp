(in-package #:dunge)

;;; Console
;;;
;;; Playing a session at a terminal: the game loop, rendering rooms and choices,
;;; reading input, and debug undo.

(defun make-runtime-session (game &key current-room return-stack world)
  "A session playing GAME in WORLD, a fresh world by default. CURRENT-ROOM and
RETURN-STACK, room names, move the world's player when given; otherwise the
player stays where WORLD has them."
  (let ((world (or world (make-world game))))
    (when (or current-room (null (world-location world)))
      (let ((start-room (or current-room (game-start game))))
        (unless start-room
          (error "Cannot start a runtime session for a game with no rooms."))
        (setf (world-location world)
              (find-room game
                         (ensure-runtime-room-name start-room "current room")))))
    (when (or current-room return-stack)
      (setf (world-return-stack world)
            (mapcar (lambda (room-name)
                      (find-room game room-name))
                    (ensure-runtime-return-stack return-stack))))
    (%make-runtime-session game world)))

(defun ensure-saveable-room-location (location purpose)
  (unless (typep location 'room)
    (error "Cannot save ~A while it is a transient ~A."
           purpose
           (class-name (class-of location))))
  location)

(defun runtime-session-current-room-name (session)
  (name (ensure-saveable-room-location
         (runtime-session-location session)
         "the current location")))

(defun runtime-session-return-stack-room-names (session)
  (mapcar (lambda (location)
            (name (ensure-saveable-room-location location "the return stack")))
          (runtime-session-return-stack session)))

(defun read-choice-index (count)
  (loop
    (format *output* "> ")
    (finish-output *output*)
    (let* ((line (read-line *input* nil nil))
           (index (and line (parse-integer line :junk-allowed t))))
      (unless line
        (return nil))
      (when (and index (<= 1 index count))
        (setf *pending-choice-spacing* t)
        (return index))
      (format *output* "Choose 1-~D.~%" count))))

(defun render-pending-choice-spacing ()
  (when *pending-choice-spacing*
    (terpri *output*)
    (setf *pending-choice-spacing* nil)))

(defun pause-after-say ()
  (when *pause-after-say*
    (format *output* "Press Enter to continue.")
    (finish-output *output*)
    (read-line *input* nil nil)
    (terpri *output*)))

(defun evaluate-session (session &key (debug *debug*))
  (check-type session runtime-session)
  (let ((*pending-choice-spacing* nil)
        (*debug* debug))
    (let* ((game (runtime-session-game session))
           (game-context (make-runtime-context
                          :game game
                          :world (runtime-session-world session)
                          :session session)))
      (loop do (let* ((location (runtime-session-location session))
                      (location-context
                        (runtime-context-for-location game-context location))
                      (result (evaluate location location-context)))
                 (match result
                   ((quit)
                    (return result))
                   ((refresh)
                    nil)
                   ((goto (room-name room-name))
                    (setf (runtime-session-location session)
                          (find-room game room-name)))
                   ((gosub (room-name room-name))
                    (push location (runtime-session-return-stack session))
                    (setf (runtime-session-location session)
                          (find-room game room-name)))
                   ((enter (target target))
                    (push location (runtime-session-return-stack session))
                    (setf (runtime-session-location session) target))
                   ((back)
                    (if (runtime-session-return-stack session)
                        (setf (runtime-session-location session)
                              (pop (runtime-session-return-stack session)))
                        (return result)))
                   ((fall-through)
                    (return location))
                   (_
                    (return result))))))))

(defmethod evaluate ((game game) &optional context)
  (declare (ignore context))
  (terpri *output*)
  (evaluate-session (make-runtime-session game)))

(defun render-scene-title (title)
  (render-pending-choice-spacing)
  (format *output* "~&~A~%~A~%~%"
          title
          (make-string (length title) :initial-element #\=)))

(defmethod evaluate ((room room) &optional context)
  (let ((room-context (runtime-context-for-scene context room)))
    (render-scene-title (or (room-title room) (name room)))
    (let ((result (describe-children (entities room) room-context)))
      (when result
        (return-from evaluate result)))
    (present-location-choices (collect-options-from (entities room) room-context)
                              room-context)))

(defun runtime-return-stack-p (context)
  (let ((session (and context (runtime-context-session context))))
    (and session
         (runtime-session-return-stack session)
         t)))

(defun continue-choice ()
  (%make-choice :label "Continue" :target (%make-back)))

(defun present-location-choices (options context)
  "Offer OPTIONS for the current location.
A location with no choices offers a single Continue choice back to its caller
when the return stack is not empty, and otherwise ends play with FALL-THROUGH."
  (let ((options (if (and (null options)
                          (runtime-return-stack-p context))
                     (list (continue-choice))
                     options)))
    (if (or options
            (runtime-debug-undo-available-p context))
        (evaluate (%make-choices :options options) context)
        (%make-fall-through))))

(defun runtime-debug-undo-available-p (context)
  (and *debug*
       context
       (runtime-context-session context)
       (runtime-session-undo-stack (runtime-context-session context))))

(defun remember-runtime-undo-state (context)
  (when (and *debug*
             context
             (runtime-context-session context))
    (let ((session (runtime-context-session context)))
      (push (copy-world (runtime-session-world session))
            (runtime-session-undo-stack session)))))

(defun undo-runtime-session (context)
  (let ((session (and context (runtime-context-session context))))
    (if (and session (runtime-session-undo-stack session))
        (progn
          (restore-world-contents (runtime-session-world session)
                                  (pop (runtime-session-undo-stack session)))
          (%make-refresh))
        (progn
          (format *output* "Nothing to undo.~%")
          (%make-refresh)))))

(defmethod evaluate ((choices choices) &optional context)
  (let ((options (remove-if-not (lambda (choice)
                                  (choice-visible-p choice context))
                                (options choices))))
    (loop for option in options
          for index from 1
          do (format *output* "~D. ~A~%" index (label option)))
    (let* ((story-option-count (length options))
           (undo-index (and (runtime-debug-undo-available-p context)
                            (1+ story-option-count)))
           (option-count (or undo-index story-option-count)))
      (when undo-index
        (format *output* "~D. Undo~%" undo-index))
      (let ((index (and (> option-count 0)
                        (read-choice-index option-count))))
        (cond
          ((null index)
           (%make-quit))
          ((and undo-index (= index undo-index))
           (undo-runtime-session context))
          (t
           (let ((option (elt options (1- index))))
             (remember-runtime-undo-state context)
             (consume-node option context)
             (evaluate (target option) context))))))))

(defmethod evaluate ((view container-view) &optional context)
  (let* ((container (viewed-container view))
         (collected-options nil))
    (render-scene-title (name container))
    (if (contents container)
        (let ((result (describe-children (contents container) context)))
          (when result
            (return-from evaluate result)))
        (format *output* "There is nothing here.~%"))
    (setf collected-options (collect-options-from (contents container) context))
    (setf collected-options
          (append collected-options
                  (list (%make-choice :label (or (close-choice container) "Back")
                                      :target (%make-back)))))
    (evaluate (%make-choices :options collected-options) context)))
