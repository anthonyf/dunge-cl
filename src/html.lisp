(in-package #:dunge-html)

;;; Single-file HTML compiler for the Dunge CLOS AST.

(defgeneric compile-html-node (thing)
  (:documentation "Compile a Dunge AST node to browser runtime data."))

(defgeneric compile-html-expression (thing)
  (:documentation "Compile a Dunge expression AST node or literal."))

(defgeneric compile-html-condition (thing)
  (:documentation "Compile a Dunge condition AST node."))

(defgeneric compile-html-effect (thing)
  (:documentation "Compile a Dunge effect/control AST node."))

(defparameter *default-title* "Dunge")

(defparameter *default-style*
  "*, *::before, *::after { box-sizing: border-box; }
html { color-scheme: light dark; }
body {
  margin: 0;
  min-height: 100vh;
  font-family: ui-serif, Georgia, Cambria, \"Times New Roman\", serif;
  line-height: 1.55;
  color: #211f1c;
  background: #f7f4ed;
}
#dunge-app {
  width: min(760px, calc(100vw - 32px));
  margin: 0 auto;
  padding: 48px 0;
}
#dunge-scene { min-width: 0; }
#dunge-scene-title {
  margin: 0 0 24px;
  font-size: clamp(2rem, 7vw, 3.75rem);
  line-height: 1.05;
  font-weight: 700;
  letter-spacing: 0;
}
#dunge-scene-body {
  font-size: 1.1rem;
}
#dunge-scene-body p {
  margin: 0 0 1rem;
}
.dunge-message {
  margin: 0 0 1rem;
  padding-left: 1rem;
  border-left: 3px solid #8f6a3a;
  font-style: italic;
}
#dunge-choices {
  display: grid;
  gap: 10px;
  margin-top: 32px;
}
.dunge-choice {
  display: block;
  width: 100%;
  min-height: 44px;
  padding: 10px 14px;
  border: 1px solid #6f6a5f;
  border-radius: 6px;
  color: inherit;
  background: #fffaf0;
  font: inherit;
  text-align: left;
  cursor: pointer;
}
.dunge-choice:hover,
.dunge-choice:focus {
  border-color: #211f1c;
  outline: 2px solid transparent;
  background: #fffdf8;
}
.dunge-quit {
  color: #666056;
}
#dunge-controls {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-bottom: 24px;
}
#dunge-new-game,
#dunge-undo {
  min-height: 36px;
  padding: 6px 10px;
  border: 1px solid #6f6a5f;
  border-radius: 6px;
  color: inherit;
  background: transparent;
  font: inherit;
  cursor: pointer;
}
#dunge-new-game:hover,
#dunge-new-game:focus,
#dunge-undo:hover,
#dunge-undo:focus {
  border-color: #211f1c;
  outline: 2px solid transparent;
  background: #fffaf0;
}
#dunge-undo:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
@media (prefers-color-scheme: dark) {
  body { color: #f4efe5; background: #181713; }
  .dunge-choice {
    border-color: #80776a;
    background: #25221c;
  }
  .dunge-choice:hover,
  .dunge-choice:focus {
    border-color: #f4efe5;
    background: #302c24;
  }
  #dunge-new-game:hover,
  #dunge-new-game:focus,
  #dunge-undo:hover,
  #dunge-undo:focus { border-color: #f4efe5; background: #25221c; }
  .dunge-quit { color: #bbb3a6; }
}")

(defun html-object (&rest pairs)
  (cons :object pairs))

(defun html-array (values)
  (cons :array values))

(defun keyword-name (keyword)
  (string-downcase (symbol-name keyword)))

(defun compile-keyword-value (keyword)
  (html-object
   "type" "keyword"
   "name" (keyword-name keyword)))

(defun compile-runtime-number (value)
  (unless (integerp value)
    (error "HTML compiler only supports integer numeric values; got ~S." value))
  (unless (dunge::safe-integer-p value)
    (error "HTML compiler only supports integers within plus or minus ~D; got ~D."
           dunge::+max-safe-integer+
           value))
  value)

(defun compile-runtime-value (value)
  (cond
    ((keywordp value)
     (compile-keyword-value value))
    ((numberp value)
     (compile-runtime-number value))
    ((or (stringp value)
         (eq value t)
         (null value))
     value)
    (t
     (error "Cannot compile ~S as a browser runtime value." value))))

(defun compile-html-literal-data (value)
  (cond
    ((consp value)
     (html-array (mapcar #'compile-html-literal-data value)))
    ((null value)
     nil)
    (t
     (compile-runtime-value value))))

(defun compile-state-declarations (declarations)
  (html-object
   "keys"
   (html-array
    (mapcar (lambda (declaration)
              (keyword-name (first declaration)))
            declarations))
   "values"
   (apply #'html-object
          (loop for declaration in declarations
                for key = (first declaration)
                append (list (keyword-name key)
                             (compile-runtime-value (second declaration)))))))

(defun compile-ref-list (refs)
  (html-array
   (mapcar (lambda (ref)
             (destructuring-bind (role target-id) ref
               (html-object
                "role" (keyword-name role)
                "target" target-id)))
           refs)))

(defun compile-node-list (nodes)
  (html-array (mapcar #'compile-html-node nodes)))

(defun compile-effect-list (effects)
  (html-array (mapcar #'compile-html-effect effects)))

(defun compile-empty-sequence ()
  (html-object
   "type" "sequence"
   "effects" (html-array nil)))

(defun compile-choice-data (choice)
  (html-object
   "type" "choice"
   "label" (dunge:label choice)
   "target" (compile-html-effect (dunge:target choice))
   "id" (and (dunge:choice-id choice)
             (keyword-name (dunge:choice-id choice)))
   "once" (not (null (dunge:choice-once-p choice)))
   "condition" (and (dunge:choice-condition choice)
                    (compile-html-condition (dunge:choice-condition choice)))))

(defmethod compile-html-node ((room dunge:room))
  (html-object
   "type" "room"
   "id" (dunge:name room)
   "title" (or (dunge:room-title room) (dunge:name room))
   "body" (compile-node-list (dunge:entities room))))

(defmethod compile-html-node ((paragraph dunge:p))
  (let ((text (dunge:text paragraph)))
    (html-object
     "type" "p"
     "text" (if (stringp text)
                text
                (compile-html-expression text)))))

(defmethod compile-html-node ((entity dunge:entity))
  (html-object
   "type" "entity"
   "id" (dunge::entity-id entity)
   "name" (dunge:name entity)
   "state" (compile-state-declarations (dunge::state-declarations entity))
   "refs" (compile-ref-list (dunge::entity-refs entity))
   "body" (compile-node-list (dunge:entities entity))))

(defmethod compile-html-node ((branch dunge:branch))
  (html-object
   "type" "branch"
   "condition" (compile-html-condition (dunge::branch-condition branch))
   "then" (compile-node-list (dunge::branch-then-entities branch))
   "else" (compile-node-list (dunge::branch-else-entities branch))))

(defmethod compile-html-node ((choices dunge:choices))
  (html-object
   "type" "choices"
   "options" (html-array (mapcar #'compile-choice-data
                                 (dunge:options choices)))))

(defmethod compile-html-node ((choice dunge:choice))
  (compile-choice-data choice))

(defmethod compile-html-node ((action dunge:action))
  (html-object
   "type" "action"
   "label" (dunge:label action)
   "effects" (if (dunge::effects action)
                 (compile-html-effect (dunge::effects action))
                 (compile-empty-sequence))))

(defmethod compile-html-node ((item dunge:item))
  (html-object
   "type" "item"
   "name" (dunge:name item)
   "description" (dunge:description item)))

(defmethod compile-html-node ((container dunge:container))
  (html-object
   "type" "container"
   "name" (dunge:name container)
   "description" (dunge:description container)
   "openLabel" (dunge:open-choice container)
   "closeLabel" (dunge:close-choice container)
   "contents" (compile-node-list (dunge:contents container))))

(defmethod compile-html-node ((placement dunge::placement))
  (html-object
   "type" "placement"
   "description" (dunge:placement-description placement)
   "label" (dunge:interaction-label placement)
   "target" (and (dunge:interaction-target placement)
                 (compile-html-effect (dunge:interaction-target placement)))))

(defmethod compile-html-node ((view dunge:container-view))
  (html-object
   "type" "container-view"
   "container" (compile-html-node (dunge:viewed-container view))))

(defmethod compile-html-expression ((expression t))
  (html-object
   "type" "literal"
   "value" (compile-runtime-value expression)))

(defmethod compile-html-expression ((reference dunge:state-ref))
  (html-object
   "type" "state"
   "scope" (keyword-name (dunge::state-ref-scope reference))
   "role" (and (dunge::state-ref-role reference)
               (keyword-name (dunge::state-ref-role reference)))
   "key" (keyword-name (dunge::state-ref-key reference))))

(defmethod compile-html-expression ((expression dunge:arithmetic))
  (html-object
   "type" "arithmetic"
   "operator" (keyword-name (dunge::arithmetic-operator expression))
   "operands" (html-array (mapcar #'compile-html-expression
                                  (dunge::arithmetic-operands expression)))))

(defmethod compile-html-expression ((expression dunge:roll))
  (let ((spec (dunge::roll-spec expression)))
    (html-object
     "type" "roll"
     "dice" (getf spec :expression)
     "count" (compile-runtime-number (getf spec :count))
     "sides" (compile-runtime-number (getf spec :sides))
     "modifier" (compile-runtime-number (getf spec :modifier))
     "label" (and (dunge::roll-label expression)
                  (keyword-name (dunge::roll-label expression))))))

(defmethod compile-html-expression ((expression dunge:concat))
  (html-object
   "type" "concat"
   "parts" (html-array (mapcar #'compile-html-expression
                               (dunge::concat-parts expression)))))

(defmethod compile-html-condition ((reference dunge:state-ref))
  (compile-html-expression reference))

(defmethod compile-html-condition ((condition dunge:condition-compare))
  (html-object
   "type" "compare"
   "operator" (keyword-name (dunge::comparison-operator condition))
   "left" (compile-html-expression (dunge::condition-left condition))
   "right" (compile-html-expression (dunge::condition-right condition))))

(defmethod compile-html-condition ((condition dunge:condition-eq))
  (html-object
   "type" "eq"
   "left" (compile-html-expression (dunge::condition-left condition))
   "right" (compile-html-expression (dunge::condition-right condition))))

(defmethod compile-html-condition ((condition dunge:condition-not))
  (html-object
   "type" "not"
   "condition" (compile-html-condition (dunge::condition-child condition))))

(defmethod compile-html-condition ((condition dunge:condition-and))
  (html-object
   "type" "and"
   "conditions" (html-array (mapcar #'compile-html-condition
                                    (dunge::conditions condition)))))

(defmethod compile-html-condition ((condition dunge:condition-or))
  (html-object
   "type" "or"
   "conditions" (html-array (mapcar #'compile-html-condition
                                    (dunge::conditions condition)))))

(defmethod compile-html-effect ((effect dunge:sequence))
  (html-object
   "type" "sequence"
   "effects" (compile-effect-list (dunge::sequence-effects effect))))

(defmethod compile-html-effect ((effect dunge:state-set))
  (html-object
   "type" "set"
   "target" (compile-html-expression (dunge::effect-target effect))
   "value" (compile-html-expression (dunge::effect-value effect))))

(defmethod compile-html-effect ((effect dunge:state-clear))
  (html-object
   "type" "clear"
   "target" (compile-html-expression (dunge::effect-target effect))))

(defmethod compile-html-effect ((effect dunge:state-inc))
  (html-object
   "type" "inc"
   "target" (compile-html-expression (dunge::effect-target effect))
   "amount" (compile-html-expression (dunge::effect-amount effect))))

(defmethod compile-html-effect ((effect dunge:state-dec))
  (html-object
   "type" "dec"
   "target" (compile-html-expression (dunge::effect-target effect))
   "amount" (compile-html-expression (dunge::effect-amount effect))))

(defmethod compile-html-effect ((effect dunge:state-toggle))
  (html-object
   "type" "toggle"
   "target" (compile-html-expression (dunge::effect-target effect))))

(defmethod compile-html-effect ((effect dunge:say))
  (html-object
   "type" "say"
   "text" (compile-html-expression (dunge::say-text effect))))

(defmethod compile-html-effect ((effect dunge:conditional-effect))
  (html-object
   "type" "if"
   "condition" (compile-html-condition
                (dunge::conditional-effect-condition effect))
   "then" (if (dunge::conditional-effect-then effect)
              (compile-html-effect (dunge::conditional-effect-then effect))
              (compile-empty-sequence))
   "else" (if (dunge::conditional-effect-else effect)
              (compile-html-effect (dunge::conditional-effect-else effect))
              (compile-empty-sequence))))

(defmethod compile-html-effect ((effect dunge:goto))
  (html-object
   "type" "goto"
   "room" (compile-html-expression (dunge:room-name effect))))

(defmethod compile-html-effect ((effect dunge:gosub))
  (html-object
   "type" "gosub"
   "room" (compile-html-expression (dunge:room-name effect))))

(defmethod compile-html-effect ((effect dunge:enter))
  (html-object
   "type" "enter"
   "target" (compile-html-node (dunge:enter-target effect))))

(defmethod compile-html-effect ((effect dunge:back))
  (declare (ignore effect))
  (html-object "type" "back"))

(defmethod compile-html-effect ((effect dunge:quit))
  (declare (ignore effect))
  (html-object "type" "quit"))

(defun compile-game-data (game)
  "Compile GAME's definition to the browser data model used by the generated
Parenscript. Play state is not part of it: the browser makes its own world."
  (dunge:validate-game game)
  (html-object
   "version" 1
   "start" (dunge:game-start game)
   ;; Play starts from the seed. The next state depends only on the seed
   ;; modulo 2^31, which is always a safe integer for JSON.
   "rngState" (mod (dunge:game-random-seed game) dunge::+dunge-rng-modulus+)
   "player" (compile-state-declarations
             (dunge:game-player-state-declarations game))
   "state" (compile-state-declarations
            (dunge:game-global-state-declarations game))
   "rooms" (html-array (mapcar #'compile-html-node (dunge:game-rooms game)))))

(defun json-escape-string (string stream)
  (write-char #\" stream)
  (loop for char across string
        for code = (char-code char)
        do (case char
             (#\" (write-string "\\\"" stream))
             (#\\ (write-string "\\\\" stream))
             (#\Backspace (write-string "\\b" stream))
             (#\Page (write-string "\\f" stream))
             (#\Newline (write-string "\\n" stream))
             (#\Return (write-string "\\r" stream))
             (#\Tab (write-string "\\t" stream))
             (#\< (write-string "\\u003C" stream))
             (otherwise
              (cond
                ((or (= code #x2028) (= code #x2029))
                 (format stream "\\u~4,'0X" code))
                ((< code 32)
                 (format stream "\\u~4,'0X" code))
                (t
                 (write-char char stream))))))
  (write-char #\" stream))

(defun write-json (value stream)
  (cond
    ((and (consp value) (eq (car value) :object))
     (write-char #\{ stream)
     (loop for (key value) on (cdr value) by #'cddr
           for first = t then nil
           unless first
             do (write-char #\, stream)
           do (progn
                (json-escape-string key stream)
                (write-char #\: stream)
                (write-json value stream)))
     (write-char #\} stream))
    ((and (consp value) (eq (car value) :array))
     (write-char #\[ stream)
     (loop for child in (cdr value)
           for first = t then nil
           unless first
             do (write-char #\, stream)
           do (write-json child stream))
     (write-char #\] stream))
    ((stringp value)
     (json-escape-string value stream))
    ((numberp value)
     (compile-runtime-number value)
     (format stream "~D" value))
    ((eq value t)
     (write-string "true" stream))
    ((null value)
     (write-string "null" stream))
    (t
     (error "Cannot encode ~S as JSON." value))))

(defun json-string (value)
  (with-output-to-string (stream)
    (write-json value stream)))

(defun fnv1a-32 (string)
  (let ((hash #x811c9dc5))
    (loop for char across string
          do (setf hash
                   (logand #xffffffff
                           (* (logxor hash (char-code char))
                              #x01000193))))
    (format nil "~8,'0X" hash)))

(defun game-save-signature (data-json runtime-script)
  "Identify a build for browser saves. Saves only restore into a build with the
same game data and the same runtime, since either can change the save shape."
  (fnv1a-32 (concatenate 'string data-json runtime-script)))

(defun game-save-key (signature)
  (format nil "dunge-save:~A" signature))

(defun parenscript-runtime ()
  ;; PS-DOC expands with Parenscript's gensym counter reset, so the generated
  ;; variable names (and therefore the built HTML) do not depend on what else
  ;; the image compiled first.
  (ps:ps-doc
    (defvar *|__PS_MV_REG|* (array))
    (defvar *save-version* 1)
    (defvar *save-key* nil)
    (defvar *save-signature* nil)
    (defvar *progress-made* nil)
    (defvar *debug* nil)
    (defvar *game* nil)
    ;; All mutable play data: globals, player, entity state by room and
    ;; entity, taken choices, and the generator. Saves serialize it and undo
    ;; copies it; the game data itself is never changed.
    (defvar *world* nil)
    (defvar *current-location* nil)
    (defvar *return-stack* (array))
    (defvar *undo-stack* (array))
    (defvar *messages* (array))
    (defvar *visible-messages* (array))
    (defvar *room-index* nil)

    (defun by-id (id)
      (chain document (get-element-by-id id)))

    (defun clear-element (element)
      (setf (@ element inner-h-t-m-l) ""))

    (defun append-text (parent tag class-name text)
      (let ((element (chain document (create-element tag))))
        (when class-name
          (setf (@ element class-name) class-name))
        (setf (@ element text-content) text)
        (chain parent (append-child element))
        element))

    (defun copy-object (source)
      (let ((target (create)))
        (dolist (key (chain -object (keys source)))
          (setf (getprop target key) (getprop source key)))
        target))

    (defun keyword-p (value)
      (and value
           (eql (@ value type) "keyword")))

    (defun nil-value-p (value)
      (or (eql value nil)
          (eql value undefined)
          (eql value false)))

    (defun value-equal (left right)
      (cond
        ((and (keyword-p left) (keyword-p right))
         (eql (@ left name) (@ right name)))
        ;; CL has one NIL for false, cleared, and unset state.
        ((and (nil-value-p left) (nil-value-p right))
         t)
        (t
         (eql left right))))

    (defun truthy (value)
      (not (or (eql value nil)
               (eql value false)
               (eql value undefined))))

    (defun debug-query-flag-p (search)
      (let ((query (or search ""))
            (matched nil))
        (when (and (> (@ query length) 0)
                   (eql (chain query (char-at 0)) "?"))
          (setf query (chain query (slice 1))))
        (dolist (part (chain query (split "&")))
          (when (eql part "debug=1")
            (setf matched t)))
        matched))

    (defun debug-hash-flag-p (hash)
      (eql hash "#debug"))

    (defun debug-requested-p ()
      (or (truthy (getprop window "DUNGE_GAME_DEBUG"))
          (debug-query-flag-p (@ window location search))
          (debug-hash-flag-p (@ window location hash))))

    (defun runtime-error (message)
      (throw (-error message)))

    (defun encode-json (value)
      (chain -j-s-o-n (stringify value)))

    (defun decode-json (text)
      (chain -j-s-o-n (parse text)))

    (defun copy-json-value (value)
      (if (or (eql value nil)
              (eql value undefined))
          nil
          (decode-json (encode-json value))))

    (defun storage-get (key)
      (try (chain window local-storage (get-item key))
           (:catch (error) nil)))

    (defun storage-set (key value)
      (try (progn
             (chain window local-storage (set-item key value))
             t)
           (:catch (error) nil)))

    (defun storage-remove (key)
      (try (progn
             (chain window local-storage (remove-item key))
             t)
           (:catch (error) nil)))

    (defun initial-state (state-data)
      ;; A deep copy, so no world shares a value with the game data.
      (copy-json-value (@ state-data values)))

    (defun room-by-id (room-id)
      (let ((room (and room-id
                       (getprop *room-index* room-id))))
        (if room
            room
            (runtime-error (+ "No room named " room-id ".")))))

    (defun node-list (value)
      (or value (array)))

    (defun push-array (target value)
      (setf (aref target (@ target length)) value)
      value)

    (defun copy-array (source)
      (let ((target (array)))
        (dolist (value (node-list source))
          (push-array target value))
        target))

    (defun pop-array (target)
      (let* ((index (- (@ target length) 1))
             (value (aref target index)))
        (setf (@ target length) index)
        value))

    (defun keyword-name (value)
      (and (keyword-p value) (@ value name)))

    (defun keyword-name-p (value name)
      (and (keyword-p value)
           (eql (@ value name) name)))

    (defun object-key-count (object)
      (@ (chain -object (keys object)) length))

    (defun walk-nodes (nodes callback)
      (dolist (node (node-list nodes))
        (callback node)
        (cond
          ((eql (@ node type) "entity")
           (walk-nodes (@ node body) callback))
          ((eql (@ node type) "branch")
           (progn
             (walk-nodes (@ node then) callback)
             (walk-nodes (@ node else) callback)))
          ((eql (@ node type) "container")
           (walk-nodes (@ node contents) callback)))))

    (defun prepare-room (room)
      "Index ROOM's entities. Every entity learns its room and a key for its
state in the world: its id, or its position in the room for hand-built data
without one (the validator requires ids on stateful entities)."
      (setf (@ room scene-index) (create))
      (let ((position 0))
        (walk-nodes
         (@ room body)
         (lambda (node)
           (when (eql (@ node type) "entity")
             (setf position (+ position 1))
             (setf (@ node room-id) (@ room id))
             (setf (@ node state-key) (or (@ node id) (+ "#" position)))
             (setf (@ node resolved-refs) (create))
             (when (@ node id)
               (setf (getprop (@ room scene-index) (@ node id)) node)))))))

    (defun stateful-p (node)
      (and (eql (@ node type) "entity")
           (@ node state)
           (> (@ (@ (@ node state) keys) length) 0)))

    (defun make-world ()
      "A fresh world: every declared value at its start."
      (let ((world (create :globals (initial-state (@ *game* state))
                           :player (initial-state (@ *game* player))
                           :locals (create)
                           :taken (create)
                           "rngState" (@ *game* rng-state)
                           "rollLog" (array))))
        (dolist (room (@ *game* rooms))
          (let ((room-locals (create)))
            (walk-nodes
             (@ room body)
             (lambda (node)
               (when (stateful-p node)
                 (setf (getprop room-locals (@ node state-key))
                       (initial-state (@ node state))))))
            (setf (getprop (@ world locals) (@ room id)) room-locals)))
        world))

    (defun entity-state (node)
      (getprop (getprop (@ *world* locals) (@ node room-id)) (@ node state-key)))

    (defun resolve-room-refs (room)
      (walk-nodes
       (@ room body)
       (lambda (node)
         (when (eql (@ node type) "entity")
           (dolist (ref (node-list (@ node refs)))
             (setf (getprop (@ node resolved-refs) (@ ref role))
                   (getprop (@ room scene-index) (@ ref target))))))))

    (defun index-room (room)
      (setf (getprop *room-index* (@ room id)) room)
      (prepare-room room))

    (defun rebuild-room-index ()
      (setf *room-index* (create))
      (dolist (room (@ *game* rooms))
        (index-room room))
      (dolist (room (@ *game* rooms))
        (resolve-room-refs room))
)

    (defun prepare-game ()
      (setf *return-stack* (array))
      (setf *undo-stack* (array))
      (setf *messages* (array))
      (setf *visible-messages* (array))
      (rebuild-room-index)
      (setf *world* (make-world))
      (setf *current-location* (room-by-id (@ *game* start))))

    (defun room-location-id (location)
      (if (and location
               (eql (@ location type) "room"))
          (@ location id)
          nil))

    (defun return-stack-room-id ()
      (let ((room-id nil))
        (dotimes (offset (@ *return-stack* length))
          (unless room-id
            (let* ((index (- (- (@ *return-stack* length) 1) offset))
                   (candidate (room-location-id (aref *return-stack* index))))
              (when candidate
                (setf room-id candidate)))))
        room-id))

    (defun fallback-current-room-id ()
      (let ((current-room-id (room-location-id *current-location*)))
        (or current-room-id
            (return-stack-room-id)
            (@ *game* start))))

    (defun capture-return-stack ()
      (let ((ids (array))
            (limit (@ *return-stack* length)))
        (unless (room-location-id *current-location*)
          (setf limit (- limit 1)))
        (dotimes (index limit)
          (let ((room-id (room-location-id (aref *return-stack* index))))
            (when room-id
              (push-array ids room-id))))
        ids))

    (defun capture-runtime-state ()
      (create "version" *save-version*
              "signature" *save-signature*
              "currentRoom" (fallback-current-room-id)
              "returnStack" (capture-return-stack)
              "messages" (copy-array *visible-messages*)
              "world" (copy-json-value *world*)))

    (defun restore-return-stack (room-ids)
      (setf *return-stack* (array))
      (dolist (room-id (node-list room-ids))
        (push-array *return-stack* (room-by-id room-id))))

    (defun valid-save-p (save)
      (and save
           (eql (getprop save "version") *save-version*)
           (eql (getprop save "signature") *save-signature*)
           (getprop save "currentRoom")))

    (defun restore-runtime-state (state)
      (setf *world* (copy-json-value (getprop state "world")))
      (restore-return-stack (getprop state "returnStack"))
      (setf *messages* (copy-array (getprop state "messages")))
      (setf *current-location*
            (room-by-id (getprop state "currentRoom"))))

    (defun restore-saved-game ()
      (try
       (let* ((raw (and *save-key* (storage-get *save-key*)))
              (save (and raw (decode-json raw))))
         (if (valid-save-p save)
             (progn
               (restore-runtime-state save)
               (setf *progress-made* t)
               t)
             (progn
               (when raw
                 (storage-remove *save-key*))
               nil)))
       (:catch (error)
         (progn
           (when *save-key*
             (storage-remove *save-key*))
           nil))))

    (defun save-game ()
      (when *save-key*
        (storage-set *save-key* (encode-json (capture-runtime-state)))))

    (defun clear-save ()
      (when *save-key*
        (storage-remove *save-key*)))

    (defun remember-undo-state ()
      (when *debug*
        (push-array *undo-stack* (capture-runtime-state))
        (update-undo-control)))

    (defun undo-last-choice ()
      (when (> (@ *undo-stack* length) 0)
        (restore-runtime-state (pop-array *undo-stack*))
        (setf *messages* (array))
        (setf *visible-messages* (array))
        (setf *progress-made* t)
        (save-game)
        (render-location)))

    (defun resolve-state (reference context)
      (cond
        ((eql (@ reference scope) "global")
         (create :holder (@ *world* globals)
                 :key (@ reference key)))
        ((eql (@ reference scope) "player")
         (create :holder (@ *world* player)
                 :key (@ reference key)))
        ((eql (@ reference scope) "self")
         (create :holder (entity-state (@ context self))
                 :key (@ reference key)))
        ((eql (@ reference scope) "ref")
         (let ((target (getprop (@ (@ context self) resolved-refs)
                                (@ reference role))))
           (create :holder (entity-state target)
                   :key (@ reference key))))))

    (defun format-value (value)
      (cond
        ((eql (typeof value) "string") value)
        ((eql (typeof value) "number") (+ "" value))
        ((nil-value-p value) "")
        ((eql value t) "true")
        ((keyword-p value) (@ value name))
        (t (runtime-error "Cannot display value."))))

    (defun integer-operand (value)
      (cond
        ((or (eql value nil) (eql value undefined)) 0)
        ((chain -number (is-integer value)) value)
        (t (runtime-error (+ "Arithmetic needs integer values; got \""
                             (format-value value)
                             "\".")))))

    (defun checked-integer (value)
      (if (chain -number (is-safe-integer value))
          value
          (runtime-error
           "Arithmetic result is outside the supported integer range.")))

    (defun arithmetic-step (operator left right)
      (cond
        ((eql operator "add") (+ left right))
        ((eql operator "sub") (- left right))
        ((eql operator "mul") (* left right))
        ((eql operator "min") (if (< right left) right left))
        ((eql operator "max") (if (> right left) right left))
        (t (runtime-error (+ "Unknown arithmetic operator " operator ".")))))

    (defun evaluate-arithmetic (expression context)
      (let ((result nil))
        (dolist (operand (@ expression operands))
          (let ((value (integer-operand (evaluate-expression operand context))))
            (setf result
                  (checked-integer
                   (if (eql result nil)
                       value
                       (arithmetic-step (@ expression operator) result value))))))
        result))

    ;; The console's linear congruential generator, exactly: state' =
    ;; (1103515245 * state + 12345) mod 2^31. The product can exceed 2^53, but
    ;; only its low 31 bits matter, and Math.imul computes the low 32 bits of
    ;; an integer product exactly.
    (defun next-random-state (state)
      (logand (+ (chain -math (imul 1103515245 state)) 12345)
              #x7fffffff))

    (defun game-random (limit)
      (setf (@ *world* rng-state) (next-random-state (@ *world* rng-state)))
      (rem (@ *world* rng-state) limit))

    (defun evaluate-roll (expression)
      (let ((rolls (array))
            (total (@ expression modifier)))
        (dotimes (index (@ expression count))
          (let ((value (+ 1 (game-random (@ expression sides)))))
            (push-array rolls value)
            (setf total (+ total value))))
        (let ((entry (create "dice" (@ expression dice)
                             "count" (@ expression count)
                             "sides" (@ expression sides)
                             "rolls" rolls)))
          (unless (eql (@ expression modifier) 0)
            (setf (getprop entry "modifier") (@ expression modifier)))
          (when (@ expression label)
            (setf (getprop entry "label") (@ expression label)))
          (setf (getprop entry "result") total)
          (push-array (@ *world* roll-log) entry))
        total))

    (defun evaluate-concat (expression context)
      (let ((text ""))
        (dolist (part (@ expression parts))
          (setf text (+ text (format-value (evaluate-expression part context)))))
        text))

    (defun evaluate-expression (expression context)
      (cond
        ((eql (@ expression type) "state")
         (let ((resolved (resolve-state expression context)))
           (getprop (@ resolved holder) (@ resolved key))))
        ((eql (@ expression type) "arithmetic")
         (evaluate-arithmetic expression context))
        ((eql (@ expression type) "concat")
         (evaluate-concat expression context))
        ((eql (@ expression type) "roll")
         (evaluate-roll expression))
        (t
         (@ expression value))))

    (defun compare-values (operator left right)
      (cond
        ((eql operator "lt") (< left right))
        ((eql operator "lte") (<= left right))
        ((eql operator "gt") (> left right))
        ((eql operator "gte") (>= left right))
        (t (runtime-error (+ "Unknown comparison operator " operator ".")))))

    (defun every-condition (conditions context)
      (let ((result t))
        (dolist (child (node-list conditions))
          (unless (evaluate-condition child context)
            (setf result nil)))
        result))

    (defun some-condition (conditions context)
      (let ((result nil))
        (dolist (child (node-list conditions))
          (when (evaluate-condition child context)
            (setf result t)))
        result))

    (defun evaluate-condition (condition context)
      (cond
        ((eql (@ condition type) "state")
         (truthy (evaluate-expression condition context)))
        ((eql (@ condition type) "eq")
         (value-equal (evaluate-expression (@ condition left) context)
                      (evaluate-expression (@ condition right) context)))
        ((eql (@ condition type) "compare")
         (compare-values
          (@ condition operator)
          (integer-operand (evaluate-expression (@ condition left) context))
          (integer-operand (evaluate-expression (@ condition right) context))))
        ((eql (@ condition type) "not")
         (not (evaluate-condition (@ condition condition) context)))
        ((eql (@ condition type) "and")
         (every-condition (@ condition conditions) context))
        ((eql (@ condition type) "or")
         (some-condition (@ condition conditions) context))
        (t
         (truthy (evaluate-expression condition context)))))

    (defun state-value (reference context)
      (let ((resolved (resolve-state reference context)))
        (getprop (@ resolved holder) (@ resolved key))))

    (defun set-state-value (reference value context)
      (let ((resolved (resolve-state reference context)))
        (setf (getprop (@ resolved holder) (@ resolved key)) value)))

    (defun numeric-value (value)
      (let ((number (if (or (eql value nil)
                            (eql value undefined))
                        0
                        value)))
        (if (and (eql (typeof number) "number")
                 (chain -number (is-integer number)))
            number
            (runtime-error "Cannot increment or decrement non-numeric state value."))))

    (defun toggle-value (value)
      (cond
        ((value-equal value (create :type "keyword" :name "on"))
         (create :type "keyword" :name "off"))
        ((value-equal value (create :type "keyword" :name "off"))
         (create :type "keyword" :name "on"))
        ((eql value t) nil)
        ((eql value nil) t)
        (t
         (runtime-error "Cannot toggle non-toggleable state value."))))

    (defun execute-effect (effect context)
      (cond
        ((eql (@ effect type) "sequence")
         (let ((result nil))
           (dolist (child (@ effect effects))
             (setf result (execute-effect child context))
             (when result
               (return result)))
           result))
        ((eql (@ effect type) "set")
         (progn
           (set-state-value (@ effect target)
                            (evaluate-expression (@ effect value) context)
                            context)
           nil))
        ((eql (@ effect type) "clear")
         (progn
           (set-state-value (@ effect target) nil context)
           nil))
        ((eql (@ effect type) "inc")
         (progn
           (set-state-value
            (@ effect target)
            (checked-integer
             (+ (numeric-value (state-value (@ effect target) context))
                (integer-operand
                 (evaluate-expression (@ effect amount) context))))
            context)
           nil))
        ((eql (@ effect type) "dec")
         (progn
           (set-state-value
            (@ effect target)
            (checked-integer
             (- (numeric-value (state-value (@ effect target) context))
                (integer-operand
                 (evaluate-expression (@ effect amount) context))))
            context)
           nil))
        ((eql (@ effect type) "toggle")
         (progn
           (set-state-value (@ effect target)
                            (toggle-value (state-value (@ effect target)
                                                       context))
                            context)
           nil))
        ((eql (@ effect type) "say")
         (progn
           (push-array *messages*
                       (format-value
                        (evaluate-expression (@ effect text) context)))
           nil))
        ((eql (@ effect type) "if")
         (execute-effect
          (if (evaluate-condition (@ effect condition) context)
              (@ effect then)
              (@ effect else))
          context))
        ((eql (@ effect type) "goto")
         (create :type "goto"
                 :room (evaluate-expression (@ effect room) context)))
        ((eql (@ effect type) "gosub")
         (create :type "gosub"
                 :room (evaluate-expression (@ effect room) context)))
        ((eql (@ effect type) "enter")
         (create :type "enter"
                 :target (@ effect target)))
        ((eql (@ effect type) "back")
         (create :type "back"))
        ((eql (@ effect type) "quit")
         (create :type "quit"))))

    (defun describe-node (node context parent)
      (cond
        ((eql (@ node type) "p")
         (append-text parent "p" nil
                      (if (eql (typeof (@ node text)) "string")
                          (@ node text)
                          (format-value
                           (evaluate-expression (@ node text) context)))))
        ((eql (@ node type) "entity")
         (describe-nodes (@ node body)
                         (create :scene (@ context scene)
                                 :self node)
                         parent))
        ((eql (@ node type) "branch")
         (describe-nodes
          (if (evaluate-condition (@ node condition) context)
              (@ node then)
              (@ node else))
          context
          parent))
        ((eql (@ node type) "item")
         (append-text parent "p" nil (or (@ node description)
                                         (@ node name))))
        ((eql (@ node type) "container")
         (when (@ node description)
           (append-text parent "p" nil (@ node description))))
        ((eql (@ node type) "placement")
         (when (@ node description)
           (append-text parent "p" nil (@ node description))))))

    (defun describe-nodes (nodes context parent)
      (dolist (node (node-list nodes))
        (describe-node node context parent)))

    (defun choice-visible-p (choice context)
      (and (not (and (@ choice once)
                     (getprop (@ *world* taken)
                              (@ choice id))))
           (or (not (@ choice condition))
               (evaluate-condition (@ choice condition) context))))

    (defun collect-node-choices (node context choices)
      (cond
        ((eql (@ node type) "choice")
         (when (choice-visible-p node context)
           (push-array choices
                       (create :label (@ node label)
                               :target (@ node target)
                               :id (@ node id)
                               :once (@ node once)
                               :self (@ context self)))))
        ((eql (@ node type) "choices")
         (dolist (choice (@ node options))
           (collect-node-choices choice context choices)))
        ((eql (@ node type) "entity")
         (collect-choices-from (@ node body)
                               (create :scene (@ context scene)
                                       :self node)
                               choices))
        ((eql (@ node type) "branch")
         (collect-choices-from
          (if (evaluate-condition (@ node condition) context)
              (@ node then)
              (@ node else))
          context
          choices))
        ((eql (@ node type) "action")
         (push-array choices
                     (create :label (@ node label)
                             :target (@ node effects)
                             :self (@ context self))))
        ((eql (@ node type) "container")
         (when (@ node open-label)
           (push-array choices
                       (create :label (@ node open-label)
                               :target (create :type "enter"
                                               :target (create :type "container-view"
                                                               :container node))
                               :self (@ context self)))))
        ((eql (@ node type) "placement")
         (when (and (@ node label) (@ node target))
           (push-array choices
                       (create :label (@ node label)
                               :target (@ node target)
                               :self (@ context self))))))
      choices)

    (defun collect-choices-from (nodes context choices)
      (dolist (node (node-list nodes))
        (collect-node-choices node context choices))
      choices)

    (defun current-context ()
      (create :scene (if (eql (@ *current-location* type) "room")
                         *current-location*
                         nil)
              :self nil))

    (defun render-messages (body)
      (setf *visible-messages* (copy-array *messages*))
      (dolist (message *messages*)
        (append-text body "p" "dunge-message" message))
      (setf *messages* (array)))

    (defun render-location ()
      (let ((title (by-id "dunge-scene-title"))
            (body (by-id "dunge-scene-body"))
            (choices-element (by-id "dunge-choices")))
        (clear-element body)
        (clear-element choices-element)
        (cond
          ((eql (@ *current-location* type) "container-view")
           (render-container-view title body choices-element))
          (t
           (render-room title body choices-element)))
        (update-undo-control)))

    (defun with-continue-choice (choices)
      "Give a location with no choices a Continue choice back to its caller."
      (when (and (eql (@ choices length) 0)
                 (> (@ *return-stack* length) 0))
        (push-array choices
                    (create :label "Continue"
                            :target (create :type "back"))))
      choices)

    (defun render-room (title body choices-element)
      (let ((context (current-context))
            (choices (array)))
        (setf (@ title text-content) (@ *current-location* title))
        (render-messages body)
        (describe-nodes (@ *current-location* body) context body)
        (collect-choices-from (@ *current-location* body) context choices)
        (render-choices (with-continue-choice choices) choices-element)))

    (defun render-container-view (title body choices-element)
      (let* ((container (@ *current-location* container))
             (context (create :scene nil :self nil))
             (choices (array)))
        (setf (@ title text-content) (@ container name))
        (render-messages body)
        (if (> (@ (@ container contents) length) 0)
            (describe-nodes (@ container contents) context body)
            (append-text body "p" nil "There is nothing here."))
        (collect-choices-from (@ container contents) context choices)
        (push-array choices
                    (create :label (or (@ container close-label) "Back")
                            :target (create :type "back")))
        (render-choices choices choices-element)))

    (defun render-choice-button (choice choices-element)
      (let ((button (chain document (create-element "button"))))
        (setf (@ button type) "button")
        (setf (@ button class-name) "dunge-choice")
        (setf (@ button text-content) (@ choice label))
        (chain button
               (add-event-listener
                "click"
                (lambda ()
                  (choose choice))))
        (chain choices-element (append-child button))))

    (defun render-choices (choices choices-element)
      (if (> (@ choices length) 0)
          (dolist (choice choices)
            (render-choice-button choice choices-element))
          (append-text choices-element "p" "dunge-quit" "The scene rests here.")))

    (defun choose (choice)
      (remember-undo-state)
      (when (and (@ choice once) (@ choice id))
        (setf (getprop (@ *world* taken)
                       (@ choice id))
              t))
      (let ((context (create :scene (if (eql (@ *current-location* type) "room")
                                      *current-location*
                                      nil)
                            :self (@ choice self))))
        (setf *progress-made* t)
        (setf *visible-messages* (array))
        (handle-result (or (execute-effect (@ choice target) context)
                           (create :type "refresh")))
        (save-game)))

    (defun end-game ()
      "Show any messages from the final choice below the current scene and
replace the choices with the end-of-game note."
      (let ((body (by-id "dunge-scene-body"))
            (choices-element (by-id "dunge-choices")))
        (setf *visible-messages* (copy-array *messages*))
        (dolist (message *messages*)
          (append-text body "p" "dunge-message" message))
        (setf *messages* (array))
        (clear-element choices-element)
        (append-text choices-element "p" "dunge-quit" "The game has ended.")))

    (defun handle-result (result)
      (cond
        ((eql (@ result type) "quit")
         (end-game))
        ;; BACK with nowhere to return to ends play, as in the console.
        ((and (eql (@ result type) "back")
              (eql (@ *return-stack* length) 0))
         (end-game))
        (t
         (cond
           ((eql (@ result type) "refresh")
            nil)
           ((eql (@ result type) "goto")
            (setf *current-location* (room-by-id (@ result room))))
           ((eql (@ result type) "gosub")
            (progn
              (push-array *return-stack* *current-location*)
              (setf *current-location* (room-by-id (@ result room)))))
           ((eql (@ result type) "enter")
            (progn
              (push-array *return-stack* *current-location*)
              (setf *current-location* (@ result target))))
           ((eql (@ result type) "back")
            (setf *current-location* (pop-array *return-stack*))))
         (render-location))))

    (defun reset-game ()
      (clear-save)
      (setf *progress-made* nil)
      (prepare-game)
      (render-location))

    (defun bind-new-game-control ()
      (let ((button (by-id "dunge-new-game")))
        (when button
          (chain button
                 (add-event-listener "click" reset-game)))))

    (defun update-undo-control ()
      (let ((button (by-id "dunge-undo")))
        (when button
          (setf (@ button disabled) (<= (@ *undo-stack* length) 0)))))

    (defun bind-debug-controls ()
      (when *debug*
        (let ((controls (by-id "dunge-controls"))
              (button (by-id "dunge-undo")))
          (when (and controls (not button))
            (setf button (chain document (create-element "button")))
            (setf (@ button id) "dunge-undo")
            (setf (@ button type) "button")
            (setf (@ button text-content) "Undo")
            (chain button
                   (add-event-listener "click" undo-last-choice))
            (chain controls (append-child button)))
          (update-undo-control))))

    (defun install-refresh-guard ()
      (chain window
             (add-event-listener
              "beforeunload"
              (lambda (event)
                (when *progress-made*
                  (setf (@ event return-value) "")
                  "")))))

    (defun boot-dunge-game ()
      (setf *game* (getprop window "DUNGE_GAME_DATA"))
      (setf *save-signature* (getprop window "DUNGE_GAME_SIGNATURE"))
      (setf *save-key* (getprop window "DUNGE_GAME_SAVE_KEY"))
      (setf *debug* (debug-requested-p))
      (prepare-game)
      (restore-saved-game)
      (bind-new-game-control)
      (bind-debug-controls)
      (install-refresh-guard)
      (render-location))

    (chain document
           (add-event-listener "DOMContentLoaded" boot-dunge-game))))

(defun compile-game-script (game &key debug)
  "Return the embedded JavaScript for GAME."
  (let* ((data-json (json-string (compile-game-data game)))
         (runtime-script (parenscript-runtime))
         (signature (game-save-signature data-json runtime-script)))
    (format nil "window.DUNGE_GAME_DATA = ~A;~%window.DUNGE_GAME_SIGNATURE = ~A;~%window.DUNGE_GAME_SAVE_KEY = ~A;~%window.DUNGE_GAME_DEBUG = ~A;~%~A"
            data-json
            (json-string signature)
            (json-string (game-save-key signature))
            (if debug "true" "false")
            runtime-script)))

(defun compile-index-html (game &key (title *default-title*)
                                      (style *default-style*)
                                      debug)
  "Return a self-contained index.html document for GAME."
  (let ((script (compile-game-script game :debug debug)))
    (cl-who:with-html-output-to-string (stream nil :prologue "<!doctype html>")
      (:html :lang "en"
       (:head
        (:meta :charset "utf-8")
        (:meta :name "viewport" :content "width=device-width, initial-scale=1")
        (:title (cl-who:str title))
        (:style (cl-who:fmt "~A" style))
        (:script (cl-who:fmt "~A" script)))
       (:body
        (:main :id "dunge-app"
         (:div :id "dunge-controls"
          (:button :id "dunge-new-game" :type "button" "New game"))
         (:section :id "dunge-scene" :aria-live "polite"
          (:h1 :id "dunge-scene-title")
          (:div :id "dunge-scene-body"))
         (:nav :id "dunge-choices" :aria-label "Choices")))))))

(defun write-index-html (game pathname &key (title *default-title*)
                                       (style *default-style*)
                                       debug
                                       (if-exists :supersede))
  "Write a self-contained index.html document for GAME to PATHNAME."
  (ensure-directories-exist pathname)
  (with-open-file (stream pathname
                          :direction :output
                          :if-exists if-exists
                          :if-does-not-exist :create)
    (write-string (compile-index-html game
                                      :title title
                                      :style style
                                      :debug debug)
                  stream)
    (terpri stream))
  pathname)
