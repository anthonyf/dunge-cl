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
  width: min(1120px, calc(100vw - 32px));
  margin: 0 auto;
  padding: 48px 0;
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(240px, 300px);
  gap: 28px 36px;
  align-items: start;
}
#dunge-controls { grid-column: 1 / -1; }
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
  grid-column: 1;
  display: grid;
  gap: 10px;
  margin-top: 32px;
}
#dunge-status {
  grid-column: 2;
  grid-row: 2 / span 2;
  border-left: 1px solid #c9bfae;
  padding-left: 24px;
  font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif;
  font-size: 0.95rem;
  line-height: 1.35;
}
#dunge-status[hidden] { display: none; }
.dunge-status-section + .dunge-status-section {
  margin-top: 24px;
}
.dunge-status-title {
  margin: 0 0 10px;
  font-size: 0.95rem;
  font-weight: 700;
  letter-spacing: 0;
}
.dunge-status-meta {
  margin: -4px 0 12px;
  color: #6f675c;
}
.dunge-status-grid {
  display: grid;
  grid-template-columns: max-content minmax(0, 1fr);
  gap: 6px 14px;
  margin: 0;
}
.dunge-status-grid dt {
  color: #6f675c;
}
.dunge-status-grid dd {
  margin: 0;
  min-width: 0;
  overflow-wrap: anywhere;
}
.dunge-inventory {
  margin: 10px 0 0;
  padding-left: 1.1rem;
}
.dunge-inventory li {
  margin: 4px 0;
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
  #dunge-status { border-color: #474035; }
  .dunge-status-meta,
  .dunge-status-grid dt { color: #bbb3a6; }
}
@media (max-width: 820px) {
  #dunge-app {
    display: block;
    width: min(760px, calc(100vw - 32px));
  }
  #dunge-status {
    margin-top: 32px;
    padding-left: 0;
    padding-top: 24px;
    border-left: 0;
    border-top: 1px solid #c9bfae;
  }
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
          (loop for (key value) in declarations
                append (list (keyword-name key)
                             (compile-runtime-value value))))))

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
  (html-object
   "type" "p"
   "text" (dunge:text paragraph)))

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

(defmethod compile-html-condition ((reference dunge:state-ref))
  (compile-html-expression reference))

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

(defun compile-html-player (player)
  (when player
    (html-object
     "name" (dunge:player-name player)
     "background" (and (dunge:player-background player)
                       (compile-keyword-value (dunge:player-background player)))
     "str" (dunge:player-str player)
     "maxStr" (dunge:player-max-str player)
     "dex" (dunge:player-dex player)
     "maxDex" (dunge:player-max-dex player)
     "wil" (dunge:player-wil player)
     "maxWil" (dunge:player-max-wil player)
     "hp" (dunge:player-hp player)
     "maxHp" (dunge:player-max-hp player)
     "armor" (dunge:player-armor player)
     "gold" (dunge:player-gold player)
     "fate" (dunge:player-fate player)
     "inventoryCapacity" dunge:+player-inventory-capacity+
     "inventory" (html-array
                  (mapcar #'compile-html-literal-data
                          (dunge:player-inventory player)))
     "fatigue" (dunge:player-fatigue player)
     "conditions" (html-array
                   (mapcar #'compile-keyword-value
                           (dunge:player-conditions player))))))

(defun compile-html-encounter (encounter)
  (html-object
   "room" (dunge:encounter-room-name encounter)
   "enemy" (compile-keyword-value (dunge:encounter-enemy-id encounter))
   "reaction" (and (dunge:encounter-reaction encounter)
                   (compile-keyword-value
                    (dunge:encounter-reaction encounter)))
   "hp" (dunge:encounter-hp encounter)
   "maxHp" (dunge:encounter-max-hp encounter)
   "str" (dunge:encounter-str encounter)
   "maxStr" (dunge:encounter-max-str encounter)
   "armor" (dunge:encounter-armor encounter)
   "damage" (compile-runtime-value (dunge:encounter-damage encounter))
   "round" (dunge:encounter-round encounter)
   "status" (compile-keyword-value (dunge:encounter-status encounter))))

(defun compile-game-data (game)
  "Compile GAME to the browser data model used by the generated Parenscript."
  (let ((encounters (dunge:game-encounter-states game)))
    (dunge:validate-game game)
    (dolist (encounter encounters)
      (dunge:register-encounter-state game encounter))
    (html-object
     "version" 1
     "start" (dunge:game-start game)
     "player" (compile-html-player (dunge:game-player game))
     "encounters" (html-array
                   (mapcar #'compile-html-encounter encounters))
     "state" (compile-state-declarations
              (dunge:game-global-state-declarations game))
     "rooms" (html-array (mapcar #'compile-html-node
                                 (dunge:game-rooms game))))))

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

(defun game-save-key (signature)
  (format nil "dunge-save:~A" signature))

(defun parenscript-runtime ()
  (ps:ps
    (defvar *|__PS_MV_REG|* (array))
    (defvar *save-version* 1)
    (defvar *save-key* nil)
    (defvar *save-signature* nil)
    (defvar *progress-made* nil)
    (defvar *debug* nil)
    (defvar *game* nil)
    (defvar *state* nil)
    (defvar *player* nil)
    (defvar *encounters* (array))
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

    (defun value-equal (left right)
      (if (and (keyword-p left) (keyword-p right))
          (eql (@ left name) (@ right name))
          (eql left right)))

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
      (copy-object (@ state-data values)))

    (defun room-by-id (room-id)
      (let ((room (getprop *room-index* room-id)))
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

    (defun titleize-name (name)
      (let ((parts (chain (or name "") (split "-")))
            (labels (array)))
        (dolist (part parts)
          (when (> (@ part length) 0)
            (push-array labels
                        (+ (chain (chain part (char-at 0)) (to-upper-case))
                           (chain part (slice 1))))))
        (chain labels (join " "))))

    (defun display-value (value)
      (cond
        ((keyword-p value)
         (titleize-name (@ value name)))
        ((eql value nil)
         "None")
        ((eql value undefined)
         "None")
        ((eql value t)
         "Yes")
        ((eql value false)
         "No")
        (t
         (+ "" value))))

    (defun append-status-row (list-element label value)
      (append-text list-element "dt" nil label)
      (append-text list-element "dd" nil (display-value value)))

    (defun append-status-section (panel title)
      (let ((section (chain document (create-element "section"))))
        (setf (@ section class-name) "dunge-status-section")
        (append-text section "h2" "dunge-status-title" title)
        (chain panel (append-child section))
        section))

    (defun append-status-grid (section)
      (let ((grid (chain document (create-element "dl"))))
        (setf (@ grid class-name) "dunge-status-grid")
        (chain section (append-child grid))
        grid))

    (defun keyword-list-text (values)
      (let ((labels (array)))
        (dolist (value (node-list values))
          (push-array labels (display-value value)))
        (if (> (@ labels length) 0)
            (chain labels (join ", "))
            "None")))

    (defun inventory-option (entry option default-value)
      (let ((result default-value)
            (length (@ entry length)))
        (dotimes (offset length)
          (let ((index (+ 2 (* offset 2))))
            (when (< (+ index 1) length)
              (let ((key (aref entry index)))
                (when (and (keyword-p key)
                           (eql (@ key name) option))
                  (setf result (aref entry (+ index 1))))))))
        result))

    (defun inventory-entry-count (entry)
      (let ((count (inventory-option entry "count" 1)))
        (if (eql (typeof count) "number")
            count
            1)))

    (defun inventory-entry-slots (entry)
      (let ((explicit (inventory-option entry "slots" undefined)))
        (if (not (eql explicit undefined))
            explicit
            (let ((kind (and (keyword-p (aref entry 0))
                             (@ (aref entry 0) name))))
              (cond
                ((eql kind "item")
                 (* (inventory-entry-count entry)
                    (if (truthy (inventory-option entry "bulky" nil)) 2 1)))
                ((eql kind "supply")
                 1)
                (t
                 0))))))

    (defun inventory-used-slots ()
      (let ((used (or (@ *player* fatigue) 0)))
        (dolist (entry (node-list (@ *player* inventory)))
          (setf used (+ used (inventory-entry-slots entry))))
        used))

    (defun inventory-entry-label (entry)
      (let* ((id (display-value (aref entry 1)))
             (count (inventory-entry-count entry)))
        (if (> count 1)
            (+ id " x" count)
            id)))

    (defun render-inventory-list (section)
      (let ((inventory (node-list (@ *player* inventory))))
        (if (> (@ inventory length) 0)
            (let ((list (chain document (create-element "ul"))))
              (setf (@ list class-name) "dunge-inventory")
              (dolist (entry inventory)
                (append-text list "li" nil (inventory-entry-label entry)))
              (chain section (append-child list)))
            (append-text section "p" "dunge-status-meta" "Inventory is empty."))))

    (defun render-player-status (panel)
      (when *player*
        (let* ((section (append-status-section
                         panel
                         (or (@ *player* name) "Character")))
               (used (inventory-used-slots))
               (capacity (or (@ *player* inventory-capacity) 10)))
          (when (@ *player* background)
            (append-text section
                         "p"
                         "dunge-status-meta"
                         (display-value (@ *player* background))))
          (let ((grid (append-status-grid section)))
            (append-status-row grid "HP" (+ (@ *player* hp)
                                            "/"
                                            (@ *player* max-hp)))
            (append-status-row grid "STR" (+ (@ *player* str)
                                             "/"
                                             (@ *player* max-str)))
            (append-status-row grid "DEX" (+ (@ *player* dex)
                                             "/"
                                             (@ *player* max-dex)))
            (append-status-row grid "WIL" (+ (@ *player* wil)
                                             "/"
                                             (@ *player* max-wil)))
            (append-status-row grid "Armor" (@ *player* armor))
            (append-status-row grid "Gold" (@ *player* gold))
            (append-status-row grid "Fate" (@ *player* fate))
            (append-status-row grid "Fatigue" (@ *player* fatigue))
            (append-status-row grid "Conditions"
                               (keyword-list-text (@ *player* conditions)))
            (append-status-row grid "Slots" (+ used
                                               "/"
                                               capacity
                                               " used")))
          (render-inventory-list section))))

    (defun encounter-for-current-room ()
      (let ((room-id (fallback-current-room-id))
            (match nil))
        (when room-id
          (dolist (encounter (node-list *encounters*))
            (when (and (not match)
                       (eql (@ encounter room) room-id))
              (setf match encounter))))
        match))

    (defun render-encounter-status (panel encounter)
      (when encounter
        (let ((grid (append-status-grid
                     (append-status-section panel "Encounter"))))
          (append-status-row grid "Enemy" (@ encounter enemy))
          (append-status-row grid "Status" (@ encounter status))
          (append-status-row grid "HP" (+ (@ encounter hp)
                                          "/"
                                          (@ encounter max-hp)))
          (append-status-row grid "STR" (+ (@ encounter str)
                                           "/"
                                           (@ encounter max-str)))
          (append-status-row grid "Armor" (@ encounter armor))
          (append-status-row grid "Damage" (@ encounter damage))
          (append-status-row grid "Round" (@ encounter round))
          (when (@ encounter reaction)
            (append-status-row grid "Reaction" (@ encounter reaction))))))

    (defun render-status-panel ()
      (let ((panel (by-id "dunge-status"))
            (encounter (encounter-for-current-room)))
        (when panel
          (clear-element panel)
          (if (or *player* encounter)
              (progn
                (setf (@ panel hidden) false)
                (render-player-status panel)
                (render-encounter-status panel encounter))
              (setf (@ panel hidden) t)))))

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
      (setf (@ room scene-index) (create))
      (walk-nodes
       (@ room body)
       (lambda (node)
         (when (and (eql (@ node type) "entity") (@ node id))
           (unless (@ node state-data)
             (setf (@ node state-data) (@ node state)))
           (setf (@ node state) (initial-state (@ node state-data)))
           (setf (@ node resolved-refs) (create))
           (setf (getprop (@ room scene-index) (@ node id)) node)))))

    (defun resolve-room-refs (room)
      (walk-nodes
       (@ room body)
       (lambda (node)
         (when (eql (@ node type) "entity")
           (dolist (ref (node-list (@ node refs)))
             (setf (getprop (@ node resolved-refs) (@ ref role))
                   (getprop (@ room scene-index) (@ ref target))))))))

    (defun prepare-game ()
      (setf *room-index* (create))
      (setf *return-stack* (array))
      (setf *undo-stack* (array))
      (setf *messages* (array))
      (setf *visible-messages* (array))
      (dolist (room (@ *game* rooms))
        (setf (getprop *room-index* (@ room id)) room)
        (prepare-room room))
      (dolist (room (@ *game* rooms))
        (resolve-room-refs room))
      (setf *state* (create :globals (initial-state (@ *game* state))
                            :taken-choices (create)))
      (setf *player* (copy-json-value (@ *game* player)))
      (setf *encounters* (copy-json-value (@ *game* encounters)))
      (setf *current-location* (room-by-id (@ *game* start))))

    (defun room-location-id (location)
      (if (and location (eql (@ location type) "room"))
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

    (defun capture-local-state ()
      (let ((locals (array)))
        (dolist (room (@ *game* rooms))
          (walk-nodes
           (@ room body)
           (lambda (node)
             (when (and (eql (@ node type) "entity")
                        (@ node id)
                        (> (object-key-count (@ node state)) 0))
               (push-array locals
                           (create :room (@ room id)
                                   :entity (@ node id)
                                   :state (copy-object (@ node state))))))))
        locals))

    (defun capture-runtime-state ()
      (create "version" *save-version*
              "signature" *save-signature*
              "currentRoom" (fallback-current-room-id)
              "returnStack" (capture-return-stack)
              "player" (copy-json-value *player*)
              "messages" (copy-array *visible-messages*)
              "globals" (copy-object (@ *state* globals))
              "locals" (capture-local-state)
              "takenChoices" (copy-object (getprop *state* "taken-choices"))))

    (defun restore-return-stack (room-ids)
      (setf *return-stack* (array))
      (dolist (room-id (node-list room-ids))
        (push-array *return-stack* (room-by-id room-id))))

    (defun restore-local-state (locals)
      (dolist (entry (node-list locals))
        (let* ((room (room-by-id (@ entry room)))
               (entity (getprop (@ room scene-index) (@ entry entity))))
          (if entity
              (setf (@ entity state) (copy-object (or (@ entry state)
                                                      (create))))
              (runtime-error
               (+ "No saveable entity " (@ entry entity) "."))))))

    (defun valid-save-p (save)
      (and save
           (eql (getprop save "version") *save-version*)
           (eql (getprop save "signature") *save-signature*)
           (getprop save "currentRoom")))

    (defun restore-runtime-state (state)
      (setf (@ *state* globals)
            (copy-object (or (getprop state "globals") (create))))
      (setf (getprop *state* "taken-choices")
            (copy-object (or (getprop state "takenChoices") (create))))
      (unless (eql (getprop state "player") undefined)
        (setf *player* (copy-json-value (getprop state "player"))))
      (restore-local-state (getprop state "locals"))
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
         (create :holder (@ *state* globals)
                 :key (@ reference key)))
        ((eql (@ reference scope) "self")
         (create :holder (@ (@ context self) state)
                 :key (@ reference key)))
        ((eql (@ reference scope) "ref")
         (let ((target (getprop (@ (@ context self) resolved-refs)
                                (@ reference role))))
           (create :holder (@ target state)
                   :key (@ reference key))))))

    (defun evaluate-expression (expression context)
      (if (eql (@ expression type) "state")
          (let ((resolved (resolve-state expression context)))
            (getprop (@ resolved holder) (@ resolved key)))
          (@ expression value)))

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
        (if (eql (typeof number) "number")
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
            (+ (numeric-value (state-value (@ effect target) context))
               (evaluate-expression (@ effect amount) context))
            context)
           nil))
        ((eql (@ effect type) "dec")
         (progn
           (set-state-value
            (@ effect target)
            (- (numeric-value (state-value (@ effect target) context))
               (evaluate-expression (@ effect amount) context))
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
                       (evaluate-expression (@ effect text) context))
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
         (append-text parent "p" nil (@ node text)))
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
                     (getprop (getprop *state* "taken-choices")
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
        (if (eql (@ *current-location* type) "container-view")
            (render-container-view title body choices-element)
            (render-room title body choices-element))
        (render-status-panel)
        (update-undo-control)))

    (defun render-room (title body choices-element)
      (let ((context (current-context))
            (choices (array)))
        (setf (@ title text-content) (@ *current-location* title))
        (render-messages body)
        (describe-nodes (@ *current-location* body) context body)
        (collect-choices-from (@ *current-location* body) context choices)
        (render-choices choices choices-element)))

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
        (setf (getprop (getprop *state* "taken-choices")
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

    (defun handle-result (result)
      (if (eql (@ result type) "quit")
          (progn
            (setf (@ (by-id "dunge-choices") inner-h-t-m-l) "")
            (append-text (by-id "dunge-choices")
                         "p"
                         "dunge-quit"
                         "The game has ended."))
          (progn
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
               (when (> (@ *return-stack* length) 0)
                 (setf *current-location* (pop-array *return-stack*)))))
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
         (signature (fnv1a-32 data-json)))
    (format nil "window.DUNGE_GAME_DATA = ~A;~%window.DUNGE_GAME_SIGNATURE = ~A;~%window.DUNGE_GAME_SAVE_KEY = ~A;~%window.DUNGE_GAME_DEBUG = ~A;~%~A"
            data-json
            (json-string signature)
            (json-string (game-save-key signature))
            (if debug "true" "false")
            (parenscript-runtime))))

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
         (:nav :id "dunge-choices" :aria-label "Choices")
         (:aside :id "dunge-status" :aria-label "Character status" :hidden "hidden")))))))

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
