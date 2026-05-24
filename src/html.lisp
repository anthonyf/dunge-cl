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

(defun compile-game-data (game)
  "Compile GAME to the browser data model used by the generated Parenscript."
  (dunge:validate-game game)
  (html-object
   "version" 1
   "start" (dunge:game-start game)
   "state" (compile-state-declarations
            (dunge:game-global-state-declarations game))
   "rooms" (html-array (mapcar #'compile-html-node
                               (dunge:game-rooms game)))))

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

(defun parenscript-runtime ()
  (ps:ps
    (defvar *game* nil)
    (defvar *state* nil)
    (defvar *current-location* nil)
    (defvar *return-stack* (array))
    (defvar *messages* (array))
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

    (defun runtime-error (message)
      (throw (new (-error message))))

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

    (defun pop-array (target)
      (let* ((index (- (@ target length) 1))
             (value (aref target index)))
        (setf (@ target length) index)
        value))

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
           (setf (@ node state) (initial-state (@ node state)))
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
      (dolist (room (@ *game* rooms))
        (setf (getprop *room-index* (@ room id)) room)
        (prepare-room room))
      (dolist (room (@ *game* rooms))
        (resolve-room-refs room))
      (setf *state* (create :globals (initial-state (@ *game* state))
                            :taken-choices (create)))
      (setf *current-location* (room-by-id (@ *game* start))))

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
                     (getprop (@ *state* taken-choices) (@ choice id))))
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
            (render-room title body choices-element))))

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

    (defun render-choices (choices choices-element)
      (if (> (@ choices length) 0)
          (dolist (choice choices)
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
          (append-text choices-element "p" "dunge-quit" "The scene rests here.")))

    (defun choose (choice)
      (when (and (@ choice once) (@ choice id))
        (setf (getprop (@ *state* taken-choices) (@ choice id)) t))
      (let ((context (create :scene (if (eql (@ *current-location* type) "room")
                                      *current-location*
                                      nil)
                            :self (@ choice self))))
        (handle-result (or (execute-effect (@ choice target) context)
                           (create :type "refresh")))))

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

    (defun boot-dunge-game ()
      (setf *game* (getprop window "DUNGE_GAME_DATA"))
      (prepare-game)
      (render-location))

    (chain document
           (add-event-listener "DOMContentLoaded" boot-dunge-game))))

(defun compile-game-script (game)
  "Return the embedded JavaScript for GAME."
  (format nil "window.DUNGE_GAME_DATA = ~A;~%~A"
          (json-string (compile-game-data game))
          (parenscript-runtime)))

(defun compile-index-html (game &key (title *default-title*)
                                      (style *default-style*))
  "Return a self-contained index.html document for GAME."
  (let ((script (compile-game-script game)))
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
         (:section :id "dunge-scene" :aria-live "polite"
          (:h1 :id "dunge-scene-title")
          (:div :id "dunge-scene-body"))
         (:nav :id "dunge-choices" :aria-label "Choices")))))))

(defun write-index-html (game pathname &key (title *default-title*)
                                       (style *default-style*)
                                       (if-exists :supersede))
  "Write a self-contained index.html document for GAME to PATHNAME."
  (ensure-directories-exist pathname)
  (with-open-file (stream pathname
                          :direction :output
                          :if-exists if-exists
                          :if-does-not-exist :create)
    (write-string (compile-index-html game :title title :style style) stream)
    (terpri stream))
  pathname)
