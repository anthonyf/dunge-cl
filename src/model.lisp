(in-package #:dunge)

;;; Internal CLOS AST model

(defgeneric node-id (thing)
  (:documentation "Return the scene-local id for THING, or NIL."))

(defgeneric node-children (thing)
  (:documentation "Return child AST nodes that participate in scene indexing."))

(defmethod node-id ((thing t))
  nil)

(defmethod node-children ((thing t))
  nil)

(define-dunge-node game ()
  ((rooms :reader game-rooms :initarg :rooms :initform nil)
   (tables :reader game-tables :initarg :tables :initform nil)
   (random-seed :reader game-random-seed :initarg :seed :initform 1)
   (random-state :accessor game-random-state :initform 1)
   (roll-log :accessor game-roll-log-reversed :initform nil)
   (global-state :reader game-global-state
                 :initform (make-hash-table :test 'eql))
   (global-state-declarations :reader game-global-state-declarations
                              :initarg :state
                              :initform nil)
   (flag-state-declarations :reader game-flag-state-declarations
                            :initarg :flags
                            :initform nil)
   (marked-state-declarations :reader game-marked-state-declarations
                              :initarg :marked
                              :initform nil)
   (taken-choices :reader game-taken-choices
                  :initform (make-hash-table :test 'eql))
   (player :accessor game-player :initarg :player :initform nil)
   (room-index :reader room-index :initform (make-hash-table :test 'equal))
   (generated-room-index :reader generated-room-index
                         :initform (make-hash-table :test 'equal))
   (generated-room-counter :accessor game-generated-room-counter
                           :initform 0)
   (encounter-index :reader game-encounter-index
                    :initform (make-hash-table :test 'equal))
   (table-index :reader table-index :initform (make-hash-table :test 'eql))
   (start :accessor game-start :initarg :start :initform nil))
  (:children (thing) (append (game-rooms thing)
                             (game-tables thing)))
  (:source :game
   (:fields
    (:start :scene-id)
    (:state :state-declarations :default nil)
    (:flags :state-key-list :default nil)
    (:marked :state-key-list :default nil)
    (:seed :non-negative-integer :default 1)
    (:player :player)
    (:tables :table-list :default nil)
    (:rooms :room-list :required t))))

(defun game-roll-log (game)
  (reverse (copy-list (game-roll-log-reversed game))))

(defun (setf game-roll-log) (roll-log game)
  (setf (game-roll-log-reversed game) (reverse (copy-list roll-log)))
  roll-log)

(define-dunge-node player ()
  ((name :accessor player-name :initarg :name :initform nil)
   (background :accessor player-background
               :initarg :background
               :initform nil)
   (str :accessor player-str :initarg :str :initform 10)
   (max-str :accessor player-max-str :initarg :max-str :initform nil)
   (dex :accessor player-dex :initarg :dex :initform 10)
   (max-dex :accessor player-max-dex :initarg :max-dex :initform nil)
   (wil :accessor player-wil :initarg :wil :initform 10)
   (max-wil :accessor player-max-wil :initarg :max-wil :initform nil)
   (hp :accessor player-hp :initarg :hp :initform 1)
   (max-hp :accessor player-max-hp :initarg :max-hp :initform nil)
   (armor :accessor player-armor :initarg :armor :initform 0)
   (gold :accessor player-gold :initarg :gold :initform 0)
   (fate :accessor player-fate :initarg :fate :initform 0)
   (inventory :accessor player-inventory
              :initarg :inventory
              :initform nil)
   (fatigue :accessor player-fatigue :initarg :fatigue :initform 0)
   (conditions :accessor player-conditions
               :initarg :conditions
               :initform nil)
   (initial-state :accessor player-initial-state :initform nil))
  (:source :player
   (:fields
    (:name :string)
    (:background :keyword)
    (:str :non-negative-integer :default 10)
    (:max-str :non-negative-integer)
    (:dex :non-negative-integer :default 10)
    (:max-dex :non-negative-integer)
    (:wil :non-negative-integer :default 10)
    (:max-wil :non-negative-integer)
    (:hp :non-negative-integer :default 1)
    (:max-hp :non-negative-integer)
    (:armor :non-negative-integer :default 0)
    (:gold :non-negative-integer :default 0)
    (:fate :non-negative-integer :default 0)
    (:inventory :literal-list :default nil)
    (:fatigue :non-negative-integer :default 0)
    (:conditions :state-key-list :default nil))))

(defun player-state-plist (player)
  (when player
    (list :name (player-name player)
          :background (player-background player)
          :str (player-str player)
          :max-str (player-max-str player)
          :dex (player-dex player)
          :max-dex (player-max-dex player)
          :wil (player-wil player)
          :max-wil (player-max-wil player)
          :hp (player-hp player)
          :max-hp (player-max-hp player)
          :armor (player-armor player)
          :gold (player-gold player)
          :fate (player-fate player)
          :inventory (copy-tree (player-inventory player))
          :fatigue (player-fatigue player)
          :conditions (copy-list (player-conditions player)))))

(defun apply-player-state (player state)
  (setf (player-name player) (getf state :name)
        (player-background player) (getf state :background)
        (player-str player) (getf state :str)
        (player-max-str player) (getf state :max-str)
        (player-dex player) (getf state :dex)
        (player-max-dex player) (getf state :max-dex)
        (player-wil player) (getf state :wil)
        (player-max-wil player) (getf state :max-wil)
        (player-hp player) (getf state :hp)
        (player-max-hp player) (getf state :max-hp)
        (player-armor player) (getf state :armor)
        (player-gold player) (getf state :gold)
        (player-fate player) (getf state :fate)
        (player-inventory player) (copy-tree (getf state :inventory))
        (player-fatigue player) (getf state :fatigue)
        (player-conditions player) (copy-list (getf state :conditions)))
  player)

(defun reset-player-state (player)
  (when player
    (apply-player-state player (player-initial-state player))))

(defmethod initialize-instance :after ((player player) &key)
  (unless (player-max-str player)
    (setf (player-max-str player) (player-str player)))
  (unless (player-max-dex player)
    (setf (player-max-dex player) (player-dex player)))
  (unless (player-max-wil player)
    (setf (player-max-wil player) (player-wil player)))
  (unless (player-max-hp player)
    (setf (player-max-hp player) (player-hp player)))
  (setf (player-initial-state player) (player-state-plist player)))

(defconstant +player-inventory-capacity+ 10)

(defun proper-list-length-value (value label)
  (unless (listp value)
    (error "~A must be a proper list; got ~S." label value))
  (let ((length (handler-case
                    (list-length value)
                  (type-error ()
                    nil))))
    (unless length
      (error "~A must be a proper, non-circular list." label))
    length))

(defun inventory-entry-options (entry)
  (proper-list-length-value entry "Inventory entry")
  (unless (and (consp entry)
               (consp (cdr entry)))
    (error "Inventory entries must be (TYPE ID &KEY ...); got ~S." entry))
  (let ((options (cddr entry)))
    (unless (evenp (proper-list-length-value options "Inventory entry options"))
      (error "Inventory entry options must contain an even number of entries; got ~S."
             options))
    (loop for tail on options by #'cddr
          for key = (car tail)
          unless (keywordp key)
            do (error "Inventory entry option names must be keywords; got ~S."
                      key))
    options))

(defun inventory-entry-kind (entry)
  (inventory-entry-options entry)
  (let ((kind (first entry)))
    (unless (member kind '(:item :supply) :test #'eq)
      (error "Inventory entry type must be :ITEM or :SUPPLY; got ~S." kind))
    kind))

(defun inventory-entry-id (entry)
  (inventory-entry-options entry)
  (let ((id (second entry)))
    (unless (keywordp id)
      (error "Inventory entry ids must be keywords; got ~S." id))
    id))

(defun inventory-option-value (entry option &optional default)
  (getf (inventory-entry-options entry) option default))

(defun inventory-entry-count (entry)
  (positive-integer-value
   (inventory-option-value entry :count 1)
   "Inventory entry count"))

(defun inventory-entry-bulky-p (entry)
  (let ((bulky (inventory-option-value entry :bulky nil)))
    (unless (or (eq bulky t)
                (null bulky))
      (error "Inventory entry :BULKY must be a boolean; got ~S." bulky))
    bulky))

(defun inventory-entry-tags (entry)
  (let ((tags (inventory-option-value entry :tags nil)))
    (proper-list-length-value tags "Inventory entry :TAGS")
    (dolist (tag tags)
      (unless (keywordp tag)
        (error "Inventory entry tags must be keywords; got ~S." tag)))
    tags))

(defun inventory-entry-slots (entry)
  (let* ((missing '#:missing)
         (explicit-slots (inventory-option-value entry :slots missing)))
    (if (eq explicit-slots missing)
        (ecase (inventory-entry-kind entry)
          (:item
           (* (inventory-entry-count entry)
              (if (inventory-entry-bulky-p entry) 2 1)))
          (:supply
           1))
        (non-negative-integer-value explicit-slots "Inventory entry slots"))))

(defun validate-inventory-entry-data (entry)
  (let ((options (inventory-entry-options entry)))
    (inventory-entry-kind entry)
    (inventory-entry-id entry)
    (inventory-entry-count entry)
    (inventory-entry-slots entry)
    (inventory-entry-tags entry)
    (let ((condition (inventory-option-value entry :condition nil)))
      (unless (or (null condition)
                  (keywordp condition))
        (error "Inventory entry :CONDITION must be a keyword or NIL; got ~S."
               condition)))
    (loop for tail on options by #'cddr
          for key = (car tail)
          unless (member key '(:count :slots :bulky :condition :tags)
                         :test #'eq)
            do (error "Unknown inventory entry option ~S in ~S."
                      key
                      entry)))
  entry)

(defun validate-player-inventory-data (inventory)
  (proper-list-length-value inventory "Player inventory")
  (dolist (entry inventory)
    (validate-inventory-entry-data entry))
  inventory)

(defun inventory-entry-metadata (entry)
  (loop for (key value) on (inventory-entry-options entry) by #'cddr
        unless (eq key :count)
          append (list key value)))

(defun inventory-entry-matches-p (entry kind id
                                  &optional
                                    (metadata nil metadata-supplied-p))
  (and (eq (inventory-entry-kind entry) kind)
       (eq (inventory-entry-id entry) id)
       (or (not metadata-supplied-p)
           (equal (inventory-entry-metadata entry) metadata))))

(defun inventory-entry-with-count (entry count)
  (let ((kind (inventory-entry-kind entry))
        (id (inventory-entry-id entry))
        (metadata (inventory-entry-metadata entry)))
    (append (list kind id)
            (when (/= count 1)
              (list :count count))
            metadata)))

(defun normalize-inventory-entry (entry &optional count)
  (validate-inventory-entry-data entry)
  (inventory-entry-with-count entry
                              (or count
                                  (inventory-entry-count entry))))

(defun find-player-inventory-entry (player kind id)
  (find-if (lambda (entry)
             (and (eq (inventory-entry-kind entry) kind)
                  (eq (inventory-entry-id entry) id)))
           (player-inventory player)))

(defun player-inventory-count (player kind id)
  (loop for entry in (player-inventory player)
        when (and (eq (inventory-entry-kind entry) kind)
                  (eq (inventory-entry-id entry) id))
          sum (inventory-entry-count entry)))

(defun add-player-inventory-entry (player entry &key count)
  (let* ((count (if count
                    (positive-integer-value count "Inventory add count")
                    (inventory-entry-count entry)))
         (normalized (normalize-inventory-entry entry count))
         (kind (inventory-entry-kind normalized))
         (id (inventory-entry-id normalized))
         (metadata (inventory-entry-metadata normalized))
         (existing (find-if (lambda (candidate)
                              (inventory-entry-matches-p candidate
                                                         kind
                                                         id
                                                         metadata))
                            (player-inventory player))))
    (if existing
        (setf (player-inventory player)
              (mapcar (lambda (candidate)
                        (if (eq candidate existing)
                            (inventory-entry-with-count
                             candidate
                             (+ (inventory-entry-count candidate) count))
                            candidate))
                      (player-inventory player)))
        (setf (player-inventory player)
              (append (player-inventory player)
                      (list normalized)))))
  player)

(defun remove-player-inventory-entry (player kind id &key (count 1))
  (let* ((count (positive-integer-value count "Inventory remove count"))
         (available (player-inventory-count player kind id)))
    (when (< available count)
      (error "Player inventory has only ~D ~S ~S entries; cannot remove ~D."
             available
             kind
             id
             count))
    (let ((remaining-to-remove count)
          (new-inventory nil))
      (dolist (entry (player-inventory player))
        (if (and (plusp remaining-to-remove)
                 (eq (inventory-entry-kind entry) kind)
                 (eq (inventory-entry-id entry) id))
            (let* ((entry-count (inventory-entry-count entry))
                   (removed (min entry-count remaining-to-remove))
                   (remaining-entry-count (- entry-count removed)))
              (decf remaining-to-remove removed)
              (when (plusp remaining-entry-count)
                (push (inventory-entry-with-count entry remaining-entry-count)
                      new-inventory)))
            (push entry new-inventory)))
      (setf (player-inventory player) (nreverse new-inventory))))
  player)

(defun player-inventory-capacity (player)
  (declare (ignore player))
  +player-inventory-capacity+)

(defun player-inventory-used-slots (player)
  (+ (player-fatigue player)
     (loop for entry in (player-inventory player)
           sum (inventory-entry-slots entry))))

(defun player-inventory-free-slots (player)
  (max 0
       (- (player-inventory-capacity player)
          (player-inventory-used-slots player))))

(defun player-inventory-full-p (player)
  (>= (player-inventory-used-slots player)
      (player-inventory-capacity player)))

(defun player-deprived-p (player)
  (or (not (null (member :deprived (player-conditions player) :test #'eq)))
      (player-inventory-full-p player)))

(define-dunge-node room ()
  ((name :reader name :initarg :name :initform nil)
   (title :reader room-title :initarg :title :initform nil)
   (scene-index :reader scene-index
                :initform (make-hash-table :test 'equal))
   (entities :accessor entities :initform nil :initarg :entities))
  (:children (thing) (entities thing))
  (:source :room
   (:fields
    (:id :scene-id :required t :to :name)
    (:title :string)
    (:body :node-list :default nil :to :entities))))

(define-dunge-node generated-room (room)
  ((zone :reader generated-room-zone :initarg :zone :initform nil)
   (description :accessor generated-room-description
                :initarg :description
                :initform nil)
   (depth :accessor generated-room-depth :initarg :depth :initform 0)
   (results :accessor generated-room-results
            :initarg :results
            :initform nil)
   (exits :accessor generated-room-exits :initarg :exits :initform nil)
   (visited-p :accessor generated-room-visited-p
              :initarg :visited-p
              :initform nil)))

(define-dunge-node effect-node ()
  ())

(define-dunge-node control-node (effect-node)
  ())

(define-dunge-node fall-through (control-node)
  ())

(define-dunge-node goto (control-node)
  ((room-name :reader room-name :initarg :room-name :initform nil))
  (:source :%goto
   (:fields
    (:room :scene-id :required t :to :room-name))))

(define-dunge-node gosub (control-node)
  ((room-name :reader room-name :initarg :room-name :initform nil))
  (:source :%gosub
   (:fields
    (:room :scene-id :required t :to :room-name))))

(define-dunge-node enter (control-node)
  ((target :reader enter-target :initarg :target :initform nil)))

(define-dunge-node back (control-node)
  ()
  (:source :back
   (:fields)))

(defun state-scope-key (scope)
  (case scope
    ((:self :global :ref) scope)
    (otherwise
     (error "State scope must be one of :SELF, :GLOBAL, or :REF; got ~S."
            scope))))

(defun state-key (key)
  (unless (keywordp key)
    (error "State keys must be keywords; got ~S." key))
  key)

(defun ref-role-key (role)
  (unless (keywordp role)
    (error "Reference roles must be keywords; got ~S." role))
  role)

(defun scene-id-key (id)
  (unless (stringp id)
    (error "Scene ids must be strings; got ~S." id))
  id)

(defun choice-id-key (id)
  (unless (keywordp id)
    (error "Choice ids must be keywords; got ~S." id))
  id)

(define-dunge-field-type :scene-id (value context)
  (declare (ignore context))
  (scene-id-key value))

(define-dunge-field-type :choice-id (value context)
  (declare (ignore context))
  (choice-id-key value))

(define-dunge-field-type :state-key (value context)
  (declare (ignore context))
  (state-key value))

(define-dunge-field-type :state-key-list (value context)
  (declare (ignore context))
  (unless (listp value)
    (source-error "State key lists must be lists; got ~S." value))
  (mapcar #'state-key value))

(define-dunge-field-type :state-scope (value context)
  (declare (ignore context))
  (state-scope-key value))

(defun source-pair-p (value)
  (and (consp value)
       (consp (cdr value))
       (null (cddr value))))

(define-dunge-field-type :state-declarations (value context)
  (declare (ignore context))
  (unless (listp value)
    (source-error "State declarations must be a list; got ~S." value))
  (mapcar (lambda (declaration)
            (unless (source-pair-p declaration)
              (source-error "State declaration must be (KEY INITIAL-VALUE); got ~S."
                            declaration))
            (list (state-key (first declaration))
                  (second declaration)))
          value))

(defun state-declaration-key-list (declarations)
  (mapcar (lambda (declaration)
            (state-key (first declaration)))
          declarations))

(defun declared-global-state-keys (game)
  (state-declaration-key-list (game-global-state-declarations game)))

(defun global-state-declared-p (game)
  (not (null (game-global-state-declarations game))))

(defun ensure-declared-global-state-key (game key)
  (let ((state-key (state-key key)))
    (when (global-state-declared-p game)
      (unless (member state-key (declared-global-state-keys game) :test #'eql)
        (error "Game has no declared global state key ~S. Declared keys: ~S."
               state-key
               (declared-global-state-keys game))))
    state-key))

(define-dunge-field-type :refs (value context)
  (declare (ignore context))
  (unless (listp value)
    (source-error "Entity refs must be a list; got ~S." value))
  (mapcar (lambda (ref)
            (unless (source-pair-p ref)
              (source-error "Entity ref must be (ROLE TARGET-ID); got ~S."
                            ref))
            (list (ref-role-key (first ref))
                  (scene-id-key (second ref))))
          value))

(define-dunge-node state-ref ()
  ((scope :reader state-ref-scope :initarg :scope :initform :global)
   (role :reader state-ref-role :initarg :role :initform nil)
   (key :reader state-ref-key :initarg :key :initform nil))
  (:source :state
   (:fields
    (:scope :state-scope :required t)
    (:role :keyword)
    (:key :state-key :required t))))

(define-dunge-node condition-eq ()
  ((left :reader condition-left :initarg :left :initform nil)
   (right :reader condition-right :initarg :right :initform nil))
  (:source :eq
   (:fields
    (:left :expression :required t)
    (:right :expression :required t))))

(define-dunge-node condition-not ()
  ((condition :reader condition-child :initarg :condition :initform nil))
  (:source :not
   (:fields
    (:condition :condition :required t))))

(define-dunge-node condition-and ()
  ((conditions :reader conditions :initarg :conditions :initform nil))
  (:source :and
   (:fields
    (:conditions :condition-list :required t))))

(define-dunge-node condition-or ()
  ((conditions :reader conditions :initarg :conditions :initform nil))
  (:source :or
   (:fields
    (:conditions :condition-list :required t))))

(defgeneric availability-condition (thing))
(defgeneric available-p (thing context))
(defgeneric consumed-p (thing context))
(defgeneric consume-node (thing context))
(defgeneric consumable-id (thing))
(defgeneric consumable-once-p (thing))
(defgeneric node-tags (thing))
(defgeneric node-priority (thing))

(defclass availability-mixin ()
  ((condition :reader availability-condition
              :initarg :condition
              :initform nil)))

(defclass consumable-mixin ()
  ((id :reader consumable-id :initarg :id :initform nil)
   (once :reader consumable-once-p :initarg :once :initform nil)))

(defclass tagged-mixin ()
  ((tags :reader node-tags :initarg :tags :initform nil)))

(defclass prioritized-mixin ()
  ((priority :reader node-priority :initarg :priority :initform 0)))

(defmethod availability-condition ((thing t))
  nil)

(defmethod consumed-p ((thing t) context)
  (declare (ignore thing context))
  nil)

(defmethod consume-node ((thing t) context)
  (declare (ignore thing context))
  nil)

(defmethod consumable-id ((thing t))
  nil)

(defmethod consumable-once-p ((thing t))
  nil)

(defmethod node-tags ((thing t))
  (declare (ignore thing))
  nil)

(defmethod node-priority ((thing t))
  (declare (ignore thing))
  0)

(defmethod available-p ((thing t) context)
  (not (consumed-p thing context)))

(defmethod available-p ((thing availability-mixin) context)
  (and (call-next-method)
       (or (null (availability-condition thing))
           (evaluate-condition (availability-condition thing) context))))

(defgeneric choice-condition (choice))
(defgeneric choice-id (choice))
(defgeneric choice-once-p (choice))

(define-dunge-node sequence (effect-node)
  ((effects :reader sequence-effects :initarg :effects :initform nil))
  (:source :sequence
   (:fields
    (:effects :effect-list :default nil))))

(define-dunge-node state-effect (effect-node)
  ((target :reader effect-target :initarg :target :initform nil)))

(define-dunge-node state-set (state-effect)
  ((value :reader effect-value :initarg :value :initform nil))
  (:source :set
   (:fields
    (:target :state-reference :required t)
    (:value :expression :required t))))

(define-dunge-node state-clear (state-effect)
  ()
  (:source :clear
   (:fields
    (:target :state-reference :required t))))

(define-dunge-node state-inc (state-effect)
  ((amount :reader effect-amount :initarg :amount :initform 1))
  (:source :inc
   (:fields
    (:target :state-reference :required t)
    (:amount :expression :default 1))))

(define-dunge-node state-dec (state-effect)
  ((amount :reader effect-amount :initarg :amount :initform 1))
  (:source :dec
   (:fields
    (:target :state-reference :required t)
    (:amount :expression :default 1))))

(define-dunge-node state-toggle (state-effect)
  ()
  (:source :toggle
   (:fields
    (:target :state-reference :required t))))

(define-dunge-node say (effect-node)
  ((text :reader say-text :initarg :text :initform nil))
  (:source :say
   (:fields
    (:text :expression :required t))))

(define-dunge-node conditional-effect (effect-node)
  ((condition :reader conditional-effect-condition
              :initarg :condition
              :initform nil)
   (then-effects :reader conditional-effect-then
                 :initarg :then
                 :initform nil)
   (else-effects :reader conditional-effect-else
                 :initarg :else
                 :initform nil))
  (:source :if
   (:fields
    (:when :condition :required t :to :condition)
    (:then :effect-block :default nil)
    (:else :effect-block :default nil))))

(define-dunge-node encounter-action (effect-node)
  ((room-name :reader encounter-action-room-name
              :initarg :room-name
              :initform nil)
   (action :reader encounter-action-kind
           :initarg :action
           :initform nil)))

(define-dunge-node choice (availability-mixin consumable-mixin)
  ((label :accessor label :initarg :label :initform nil)
   (target :accessor target :initarg :target :initform nil))
  (:source :%choice
   (:fields
    (:label :string :required t)
    (:do :effect-or-block :required t :to :target)
    (:id :choice-id)
    (:when :condition :to :condition)
    (:once :boolean))))

(defmethod choice-condition ((choice choice))
  (availability-condition choice))

(defmethod choice-id ((choice choice))
  (consumable-id choice))

(defmethod choice-once-p ((choice choice))
  (consumable-once-p choice))

(define-dunge-node choices ()
  ((options :accessor options :initarg :options :initform nil)))

(defun table-id-key (id)
  (unless (keywordp id)
    (error "Table ids must be keywords; got ~S." id))
  id)

(defun table-mode-key (mode)
  (unless (member mode '(:weighted :roll :deck :sequence :first-match :bundle)
                  :test #'eq)
    (error "Table mode must be one of :WEIGHTED, :ROLL, :DECK, :SEQUENCE, :FIRST-MATCH, or :BUNDLE; got ~S."
           mode))
  mode)

(defun positive-integer-value (value label)
  (unless (and (integerp value) (plusp value))
    (error "~A must be a positive integer; got ~S." label value))
  value)

(defun non-negative-integer-value (value label)
  (unless (and (integerp value) (not (minusp value)))
    (error "~A must be a non-negative integer; got ~S." label value))
  value)

(defclass encounter-state ()
  ((room-name :accessor encounter-room-name
              :initarg :room
              :initform nil)
   (enemy-id :accessor encounter-enemy-id
             :initarg :enemy-id
             :initform nil)
   (reaction :accessor encounter-reaction
             :initarg :reaction
             :initform nil)
   (hp :accessor encounter-hp :initarg :hp :initform 1)
   (max-hp :accessor encounter-max-hp :initarg :max-hp :initform nil)
   (str :accessor encounter-str :initarg :str :initform 10)
   (max-str :accessor encounter-max-str :initarg :max-str :initform nil)
   (armor :accessor encounter-armor :initarg :armor :initform 0)
   (damage :accessor encounter-damage :initarg :damage :initform 1)
   (round :accessor encounter-round :initarg :round :initform 0)
   (status :accessor encounter-status :initarg :status :initform :active)
   (source :accessor encounter-source :initarg :source :initform nil)))

(defparameter +encounter-statuses+
  '(:active :defeated :escaped :player-defeated))

(defun encounter-room-name-string (room)
  (cond
    ((typep room 'room)
     (scene-id-key (name room)))
    ((stringp room)
     (scene-id-key room))
    (t
     (error "Encounter room must be a room or room id string; got ~S."
            room))))

(defun encounter-enemy-id-key (enemy-id)
  (unless (keywordp enemy-id)
    (error "Encounter enemy id must be a keyword; got ~S." enemy-id))
  enemy-id)

(defun encounter-maybe-keyword-value (value label)
  (unless (or (null value) (keywordp value))
    (error "~A must be a keyword or NIL; got ~S." label value))
  value)

(defun encounter-damage-value (damage)
  (unless (or (stringp damage)
              (and (integerp damage) (not (minusp damage))))
    (error "Encounter damage must be a non-negative integer or dice string; got ~S."
           damage))
  damage)

(defun encounter-status-key (status)
  (unless (member status +encounter-statuses+ :test #'eq)
    (error "Encounter status must be one of ~S; got ~S."
           +encounter-statuses+
           status))
  status)

(defun validate-encounter-current-maximum (current maximum label)
  (when (> current maximum)
    (error "Encounter ~A current value ~D exceeds maximum ~D."
           label
           current
           maximum)))

(defun make-encounter-state (&key room enemy-id reaction (hp 1) max-hp
                                  (str 10) max-str (armor 0) (damage 1)
                                  (round 0) (status :active) source)
  (let* ((room-name (encounter-room-name-string room))
         (enemy-id (encounter-enemy-id-key enemy-id))
         (reaction (encounter-maybe-keyword-value reaction
                                                  "Encounter reaction"))
         (hp (non-negative-integer-value hp "Encounter HP"))
         (max-hp (non-negative-integer-value (or max-hp hp)
                                             "Encounter max HP"))
         (str (non-negative-integer-value str "Encounter STR"))
         (max-str (non-negative-integer-value (or max-str str)
                                              "Encounter max STR"))
         (armor (non-negative-integer-value armor "Encounter armor"))
         (damage (encounter-damage-value damage))
         (round (non-negative-integer-value round "Encounter round"))
         (status (encounter-status-key status)))
    (validate-encounter-current-maximum hp max-hp "HP")
    (validate-encounter-current-maximum str max-str "STR")
    (make-instance 'encounter-state
                   :room room-name
                   :enemy-id enemy-id
                   :reaction reaction
                   :hp hp
                   :max-hp max-hp
                   :str str
                   :max-str max-str
                   :armor armor
                   :damage damage
                   :round round
                   :status status
                   :source (copy-tree source))))

(defun encounter-state-plist (encounter)
  (list :room (encounter-room-name encounter)
        :enemy (encounter-enemy-id encounter)
        :reaction (encounter-reaction encounter)
        :hp (encounter-hp encounter)
        :max-hp (encounter-max-hp encounter)
        :str (encounter-str encounter)
        :max-str (encounter-max-str encounter)
        :armor (encounter-armor encounter)
        :damage (encounter-damage encounter)
        :round (encounter-round encounter)
        :status (encounter-status encounter)
        :source (copy-tree (encounter-source encounter))))

(defun encounter-active-p (encounter)
  (eq (encounter-status encounter) :active))

(defun encounter-finished-p (encounter)
  (not (encounter-active-p encounter)))

(defun clear-encounter-states (game)
  (clrhash (game-encounter-index game))
  game)

(defun game-encounter-states (game)
  (sort (loop for encounter being the hash-values of (game-encounter-index game)
              collect encounter)
        #'string<
        :key #'encounter-room-name))

(defun find-encounter-state (game room &key errorp active-only)
  (let ((room-name (encounter-room-name-string room)))
    (multiple-value-bind (encounter present-p)
        (gethash room-name (game-encounter-index game))
      (cond
        ((and present-p
              (or (not active-only)
                  (encounter-active-p encounter)))
         encounter)
        (errorp
         (error "No encounter state for room ~S." room-name))
        (t nil)))))

(defun register-encounter-state (game encounter)
  (unless (typep encounter 'encounter-state)
    (error "Can only register ENCOUNTER-STATE instances; got ~S."
           encounter))
  (let ((room-name (encounter-room-name encounter)))
    (when (nth-value 1 (gethash room-name (game-encounter-index game)))
      (error "Duplicate encounter state for room ~S." room-name))
    (setf (gethash room-name (game-encounter-index game)) encounter)
    encounter))

(defun generated-room-zone-key (zone)
  (unless (keywordp zone)
    (error "Generated room zone must be a keyword; got ~S." zone))
  zone)

(defun generated-room-id-string (id)
  (scene-id-key id))

(defun generated-room-title-string (title id)
  (cond
    ((null title) id)
    ((stringp title) title)
    (t
     (error "Generated room title must be a string or NIL; got ~S."
            title))))

(defun generated-room-description-string (description)
  (cond
    ((null description) nil)
    ((stringp description) description)
    (t
     (error "Generated room description must be a string or NIL; got ~S."
            description))))

(defun generated-room-exit-list (exits)
  (proper-list-length-value exits "Generated room exits")
  (dolist (exit exits)
    (unless (and (consp exit)
                 (keywordp (car exit))
                 (stringp (cdr exit)))
      (error "Generated room exits must be (DIRECTION . ROOM-ID) pairs; got ~S."
             exit)))
  exits)

(defun generated-room-exit-direction-key (direction)
  (unless (keywordp direction)
    (error "Generated room exit directions must be keywords; got ~S."
           direction))
  direction)

(defun generated-room-exit-target-string (target)
  (cond
    ((typep target 'room)
     (scene-id-key (name target)))
    ((stringp target)
     (scene-id-key target))
    (t
     (error "Generated room exit targets must be room ids or rooms; got ~S."
            target))))

(defun generated-room-value (room label)
  (unless (typep room 'generated-room)
    (error "~A must be a generated room; got ~S." label room))
  room)

(defun generated-room-result-list (results)
  (proper-list-length-value results "Generated room results")
  results)

(defun generated-zone-id-part (zone)
  (string-downcase (symbol-name (generated-room-zone-key zone))))

(defun allocate-generated-room-id (game zone)
  (let ((counter (incf (game-generated-room-counter game))))
    (format nil "generated:~A:~D" (generated-zone-id-part zone) counter)))

(defun generated-room-id-counter (id)
  (let ((separator (position #\: id :from-end t)))
    (when (and separator (< (1+ separator) (length id)))
      (handler-case
          (let ((counter (parse-integer id
                                        :start (1+ separator)
                                        :junk-allowed nil)))
            (when (plusp counter)
              counter))
        (error ()
          nil)))))

(defun note-generated-room-id-counter (game id)
  (let ((counter (generated-room-id-counter id)))
    (when counter
      (setf (game-generated-room-counter game)
            (max (game-generated-room-counter game) counter)))))

(defun make-generated-room (&key id title description zone (depth 0) results exits
                              visited-p)
  (let ((id (generated-room-id-string id)))
    (make-instance 'generated-room
                   :name id
                   :title (generated-room-title-string title id)
                   :description (generated-room-description-string
                                 description)
                   :zone (generated-room-zone-key zone)
                   :depth (non-negative-integer-value
                           depth
                           "Generated room depth")
                   :results (copy-tree (generated-room-result-list
                                        (or results nil)))
                   :exits (copy-tree (generated-room-exit-list
                                      (or exits nil)))
                   :visited-p (not (null visited-p)))))

(defun clear-generated-rooms (game)
  (clrhash (generated-room-index game))
  (setf (game-generated-room-counter game) 0)
  game)

(defun game-generated-rooms (game)
  (sort (loop for room being the hash-values of (generated-room-index game)
              collect room)
        #'string<
        :key #'name))

(defun find-generated-room (game room-id &key errorp)
  (let ((key (generated-room-id-string room-id)))
    (multiple-value-bind (room present-p)
        (gethash key (generated-room-index game))
      (cond
        (present-p room)
        (errorp
         (error "No generated room named ~S." room-id))
        (t nil)))))

(defun register-generated-room (game room)
  (unless (typep room 'generated-room)
    (error "Can only register GENERATED-ROOM instances; got ~S." room))
  (let ((id (generated-room-id-string (name room))))
    (when (nth-value 1 (gethash id (room-index game)))
      (error "Generated room id ~S conflicts with an authored room." id))
    (when (nth-value 1 (gethash id (generated-room-index game)))
      (error "Duplicate generated room id ~S." id))
    (prepare-room-scene room)
    (setf (gethash id (generated-room-index game)) room)
    (note-generated-room-id-counter game id)
    room))

(defun create-generated-room (game &key id title description zone (depth 0)
                                results exits
                                visited-p)
  (let ((room-id (or id (allocate-generated-room-id game zone))))
    (register-generated-room
     game
     (make-generated-room :id room-id
                          :title title
                          :description description
                          :zone zone
                          :depth depth
                          :results results
                          :exits exits
                          :visited-p visited-p))))

(defun generated-room-exit-target (room direction)
  (let ((room (generated-room-value room "Generated room exit source")))
    (cdr (assoc (generated-room-exit-direction-key direction)
                (generated-room-exits room)
                :test #'eq))))

(defun set-generated-room-exit (room direction target)
  (let* ((room (generated-room-value room "Generated room exit source"))
         (direction (generated-room-exit-direction-key direction))
         (target (generated-room-exit-target-string target))
         (existing (assoc direction (generated-room-exits room) :test #'eq)))
    (if existing
        (setf (cdr existing) target)
        (setf (generated-room-exits room)
              (append (generated-room-exits room)
                      (list (cons direction target)))))
    room))

(defun link-generated-rooms (from direction to &key reverse-direction)
  (let* ((from (generated-room-value from "Generated room link source"))
         (to (generated-room-value to "Generated room link target"))
         (direction (generated-room-exit-direction-key direction))
         (reverse-direction (when reverse-direction
                              (generated-room-exit-direction-key
                               reverse-direction)))
         (to-target (generated-room-exit-target-string to))
         (from-target (when reverse-direction
                        (generated-room-exit-target-string from))))
    (set-generated-room-exit from direction to-target)
    (when reverse-direction
      (set-generated-room-exit to reverse-direction from-target))
    (values from to)))

(defun generated-room-state-plist (room)
  (list :id (name room)
        :title (room-title room)
        :description (generated-room-description room)
        :zone (generated-room-zone room)
        :depth (generated-room-depth room)
        :results (copy-tree (generated-room-results room))
        :exits (copy-tree (generated-room-exits room))
        :visited (generated-room-visited-p room)))

(defun tag-list-value (value)
  (unless (listp value)
    (source-error "Tag lists must be lists; got ~S." value))
  (mapcar (lambda (tag)
            (unless (keywordp tag)
              (source-error "Tags must be keywords; got ~S." tag))
            tag)
          value))

(define-dunge-field-type :table-id (value context)
  (declare (ignore context))
  (table-id-key value))

(define-dunge-field-type :table-mode (value context)
  (declare (ignore context))
  (table-mode-key value))

(define-dunge-field-type :positive-integer (value context)
  (declare (ignore context))
  (positive-integer-value value "Value"))

(define-dunge-field-type :non-negative-integer (value context)
  (declare (ignore context))
  (non-negative-integer-value value "Value"))

(define-dunge-field-type :tag-list (value context)
  (declare (ignore context))
  (tag-list-value value))

(define-dunge-field-type :literal-list (value context)
  (declare (ignore context))
  (ensure-source-list :literal-list value))

(define-dunge-field-type :player (value context)
  (let ((node (compile-dunge-source-form value context)))
    (unless (typep node 'player)
      (source-error "Expected a player source form, got ~S." value))
    node))

(defun table-range-value (value)
  (cond
    ((integerp value)
     (let ((point (positive-integer-value value "Table range")))
       (cons point point)))
    ((and (source-pair-p value)
          (integerp (first value))
          (integerp (second value)))
     (let ((low (positive-integer-value (first value) "Table range low"))
           (high (positive-integer-value (second value) "Table range high")))
       (when (> low high)
         (source-error "Table range low ~D is greater than high ~D."
                       low
                       high))
       (cons low high)))
    (t
     (source-error "Table ranges must be an integer or (LOW HIGH); got ~S."
                   value))))

(define-dunge-field-type :table-range (value context)
  (declare (ignore context))
  (table-range-value value))

(define-dunge-node table-entry (availability-mixin tagged-mixin)
  ((id :reader table-entry-id :initarg :id :initform nil)
   (weight :reader table-entry-weight :initarg :weight :initform 1)
   (range :reader table-entry-range :initarg :range :initform nil)
   (result :reader table-entry-result :initarg :result :initform nil)
   (ordinal :accessor table-entry-ordinal :initform nil))
  (:source :table-entry
   (:fields
    (:id :state-key)
    (:weight :positive-integer :default 1)
    (:range :table-range)
    (:when :condition :to :condition)
    (:tags :tag-list :default nil)
    (:result :literal :required t))))

(define-dunge-node random-table ()
  ((id :reader table-id :initarg :id :initform nil)
   (mode :reader table-mode :initarg :mode :initform :weighted)
   (entries :reader table-entries :initarg :entries :initform nil)
   (sequence-index :accessor table-sequence-index :initform 0)
   (deck-drawn :reader table-deck-drawn
               :initform (make-hash-table :test 'eql)))
  (:children (thing) (table-entries thing))
  (:source :table
   (:fields
    (:id :table-id :required t)
    (:mode :table-mode :default :weighted)
    (:entries :table-entry-list :required t))))

(defmethod initialize-instance :after ((table random-table) &key)
  (loop for entry in (table-entries table)
        for ordinal from 0
        do (setf (table-entry-ordinal entry) ordinal)))

(defun reset-table-state (table)
  (setf (table-sequence-index table) 0)
  (clrhash (table-deck-drawn table))
  table)

(define-dunge-field-type :table-entry-list (value context)
  (mapcar (lambda (form)
            (let ((node (compile-dunge-source-form form context)))
              (unless (typep node 'table-entry)
                (source-error "Expected a table entry source form, got ~S."
                              form))
              node))
          (ensure-source-list :table-entry-list value)))

(define-dunge-field-type :table-list (value context)
  (mapcar (lambda (form)
            (let ((node (compile-dunge-source-form form context)))
              (unless (typep node 'random-table)
                (source-error "Expected a table source form, got ~S."
                              form))
              node))
          (ensure-source-list :table-list value)))

(define-dunge-node entity ()
  ((name :reader name :initarg :name :initform nil)
   (id :reader entity-id :initarg :id :initform nil)
   (state-declarations :reader state-declarations
                       :initarg :state
                       :initform nil)
   (local-state :reader local-state
                :initform (make-hash-table :test 'eql))
   (refs :reader entity-refs :initarg :refs :initform nil)
   (resolved-refs :reader resolved-refs
                  :initform (make-hash-table :test 'eql))
   (entities :accessor entities :initarg :entities :initform nil))
  (:id (thing) (entity-id thing))
  (:children (thing) (entities thing))
  (:source :entity
   (:fields
    (:name :string :required t)
    (:id :scene-id)
    (:state :state-declarations :default nil)
    (:refs :refs :default nil)
    (:body :node-list :default nil :to :entities))))

(define-dunge-node branch ()
  ((condition :reader branch-condition :initarg :condition :initform nil)
   (then-entities :reader branch-then-entities :initarg :then :initform nil)
   (else-entities :reader branch-else-entities :initarg :else :initform nil))
  (:children (thing)
    (append (branch-then-entities thing)
            (branch-else-entities thing)))
  (:source :branch
   (:fields
    (:when :condition :required t :to :condition)
    (:then :node-list :default nil)
    (:else :node-list :default nil))))

(define-dunge-node action ()
  ((label :accessor label :initarg :label :initform nil)
   (effects :reader effects :initarg :effects :initform nil)
   (owner :accessor action-owner :initarg :owner :initform nil))
  (:source :action
   (:fields
    (:label :string :required t)
    (:do :effect-block :default nil :to :effects))))

(define-dunge-node refresh (control-node)
  ())

(define-dunge-node placement ()
  ((thing :reader placed-thing :initarg :thing :initform nil)
   (description :reader placement-description :initarg :description :initform nil)
   (interaction-label :reader interaction-label
                      :initarg :interaction-label
                      :initform nil)
   (interaction-target :reader interaction-target
                       :initarg :interaction-target
                       :initform nil))
  (:source :placed
   (:fields
    (:thing :node :required t)
    (:description :string)
    (:label :string :to :interaction-label)
    (:do :effect :to :interaction-target))))

(define-dunge-node item ()
  ((name :reader name :initarg :name :initform nil)
   (description :reader description :initarg :description :initform nil))
  (:source :item
   (:fields
    (:name :string :required t)
    (:description :string))))

(define-dunge-node container ()
  ((name :reader name :initarg :name :initform nil)
   (description :reader description :initarg :description :initform nil)
   (open-choice :reader open-choice :initarg :open-choice :initform nil)
   (close-choice :reader close-choice :initarg :close-choice :initform nil)
   (contents :accessor contents :initarg :contents :initform nil))
  (:children (thing) (contents thing))
  (:source :container
   (:fields
    (:name :string :required t)
    (:description :string)
    (:open :string :to :open-choice)
    (:close :string :to :close-choice)
    (:contents :node-list :default nil))))

(define-dunge-node container-view ()
  ((container :reader viewed-container :initarg :container :initform nil)))

(define-dunge-node p ()
  ((text :reader text :initarg :text :initform nil))
  (:source :p
   (:fields
    (:text :string :required t))))

(define-dunge-node quit (control-node)
  ()
  (:source :quit
   (:fields)))

(defmethod initialize-instance :after ((game game) &key)
  (setf (game-random-state game) (game-random-seed game))
  (setf (slot-value game 'global-state-declarations)
        (append (game-global-state-declarations game)
                (mapcar (lambda (key)
                          (list key nil))
                        (game-flag-state-declarations game))
                (mapcar (lambda (key)
                          (list key t))
                        (game-marked-state-declarations game))))
  (clrhash (room-index game))
  (dolist (room (game-rooms game))
    (when (nth-value 1 (gethash (name room) (room-index game)))
      (error "Duplicate room named ~S." (name room)))
    (setf (gethash (name room) (room-index game)) room))
  (clrhash (table-index game))
  (dolist (table (game-tables game))
    (when (nth-value 1 (gethash (table-id table) (table-index game)))
      (error "Duplicate table id ~S." (table-id table)))
    (setf (gethash (table-id table) (table-index game)) table))
  (unless (game-start game)
    (setf (game-start game) (and (game-rooms game)
                                 (name (first (game-rooms game)))))))

(defun walk-node-tree (thing function)
  (funcall function thing)
  (dolist (child (node-children thing))
    (walk-node-tree child function)))

(defun reset-local-state (thing)
  (walk-node-tree
   thing
   (lambda (node)
     (when (typep node 'entity)
       (clrhash (local-state node))
       (dolist (declaration (state-declarations node))
         (destructuring-bind (name value) declaration
           (setf (gethash (state-key name) (local-state node))
                 value)))))))

(defun reset-global-state (game)
  (clrhash (game-global-state game))
  (dolist (declaration (game-global-state-declarations game))
    (destructuring-bind (name value) declaration
      (setf (gethash (state-key name) (game-global-state game))
            value))))

(defun index-scene-node (scene thing)
  (walk-node-tree
   thing
   (lambda (node)
     (let ((id (node-id node)))
       (when id
         (let ((key (scene-id-key id)))
           (when (nth-value 1 (gethash key (scene-index scene)))
             (error "Duplicate scene id ~S in room ~S." id (name scene)))
           (setf (gethash key (scene-index scene)) node)))))))

(defun resolve-node-refs (scene thing)
  (walk-node-tree
   thing
   (lambda (node)
     (when (typep node 'entity)
       (clrhash (resolved-refs node))
       (dolist (ref (entity-refs node))
         (destructuring-bind (role target-id) ref
           (let* ((role-key (ref-role-key role))
                  (target-key (scene-id-key target-id))
                  (target (gethash target-key (scene-index scene))))
             (unless target
               (error "Entity ~S in room ~S has ref ~S to missing id ~S."
                      (or (entity-id node) (name node))
                      (name scene)
                      role
                      target-id))
             (setf (gethash role-key (resolved-refs node)) target))))))))

(defun assign-action-owners (thing owner)
  (cond
    ((typep thing 'entity)
     (dolist (child (entities thing))
       (assign-action-owners child thing)))
    ((typep thing 'action)
     (setf (action-owner thing) owner))
    (t
     (dolist (child (node-children thing))
       (assign-action-owners child owner)))))

(defun prepare-room-scene (room)
  (clrhash (scene-index room))
  (reset-local-state room)
  (dolist (entity (entities room))
    (index-scene-node room entity))
  (dolist (entity (entities room))
    (resolve-node-refs room entity))
  (dolist (entity (entities room))
    (assign-action-owners entity nil)))

(defun prepare-game (game)
  (reset-global-state game)
  (clrhash (game-taken-choices game))
  (setf (game-random-state game) (game-random-seed game)
        (game-roll-log-reversed game) nil)
  (clear-generated-rooms game)
  (clear-encounter-states game)
  (reset-player-state (game-player game))
  (dolist (table (game-tables game))
    (reset-table-state table))
  (dolist (room (game-rooms game))
    (prepare-room-scene room))
  game)

(defvar *validation-errors* nil)
(defvar *validation-choice-ids* nil)
(defvar *validation-resolve-room-targets* nil)

(defgeneric validate-node (thing game context)
  (:documentation "Validate a Dunge AST node in GAME and CONTEXT."))

(defun validation-error (format-control &rest format-arguments)
  (push (apply #'format nil format-control format-arguments)
        *validation-errors*))

(defun static-room-name-p (thing)
  (stringp thing))

(defun validate-room-target (node game room-name)
  (when (and *validation-resolve-room-targets*
             (static-room-name-p room-name))
    (unless (nth-value 1 (gethash room-name (room-index game)))
      (validation-error "~A targets missing room ~S."
                        (class-name (class-of node))
                        room-name))))

(defun validate-game-start (game)
  (let ((start (game-start game)))
    (cond
      ((null start)
       (validation-error "Game must declare or infer a start room."))
      ((not (static-room-name-p start))
       (validation-error "Game start room must be a string; got ~S." start))
      ((not (nth-value 1 (gethash start (room-index game))))
       (validation-error "Game start room ~S does not exist." start)))))

(defun validate-choice-id (choice)
  (let ((id (choice-id choice)))
    (cond
      ((and (choice-once-p choice)
            (null id))
       (validation-error "Once-only choice ~S must declare :ID."
                         (label choice)))
      ((and id (not (keywordp id)))
       (validation-error "Choice id must be a keyword; got ~S." id))
      (id
       (let ((key (choice-id-key id)))
         (multiple-value-bind (existing present-p) (gethash key *validation-choice-ids*)
           (if present-p
               (validation-error "Duplicate choice id ~S on choices ~S and ~S."
                                 id
                                 (label existing)
                                 (label choice))
               (setf (gethash key *validation-choice-ids*) choice))))))))

(defun validate-availability-node (thing game context)
  (let ((condition (availability-condition thing)))
    (when condition
      (validate-condition condition game context))))

(defun validate-consumable-node (thing)
  (let ((id (consumable-id thing)))
    (cond
      ((and (consumable-once-p thing)
            (null id))
       (validation-error "Once-only node ~S must declare :ID." thing))
      ((and id (not (keywordp id)))
       (validation-error "Consumable node id must be a keyword; got ~S."
                         id)))))

(defun validate-state-declaration-list (owner-label declarations)
  (let ((seen (make-hash-table :test 'eql)))
    (dolist (declaration declarations)
      (destructuring-bind (key value) declaration
        (declare (ignore value))
        (let ((state-key (state-key key)))
          (if (nth-value 1 (gethash state-key seen))
              (validation-error "~A declares state key ~S more than once."
                                owner-label
                                state-key)
              (setf (gethash state-key seen) t)))))))

(defun validate-player-current-maximum (current maximum label)
  (when (> current maximum)
    (validation-error "Player ~A current value ~D exceeds maximum ~D."
                      label
                      current
                      maximum)))

(defun condition-literal-p (thing)
  (or (stringp thing)
      (keywordp thing)
      (numberp thing)
      (eq thing t)
      (null thing)))

(defun validate-condition-operand (thing game context)
  (cond
    ((typep thing 'state-ref)
     (validate-node thing game context))
    ((condition-literal-p thing)
     nil)
    (t
     (validation-error "Condition operands must be a state-ref or literal; got ~S."
                       thing))))

(defun validate-condition (condition game context)
  (cond
    ((typep condition 'condition-eq)
     (validate-condition-operand (condition-left condition) game context)
     (validate-condition-operand (condition-right condition) game context))
    ((typep condition 'condition-not)
     (validate-condition (condition-child condition) game context))
    ((typep condition 'condition-and)
     (dolist (child (conditions condition))
       (validate-condition child game context)))
    ((typep condition 'condition-or)
     (dolist (child (conditions condition))
       (validate-condition child game context)))
    ((typep condition 'state-ref)
     (validate-node condition game context))
    (t
     (validation-error "Condition must be a condition-* or state-ref node; got ~S."
                       condition))))

(defun signal-validation-errors (label)
  (when *validation-errors*
    (error "~A validation failed:~%~{  - ~A~%~}"
           label
           (nreverse *validation-errors*))))

(defun validate-room (room)
  (prepare-room-scene room)
  (let ((*validation-errors* nil)
        (*validation-choice-ids* (make-hash-table :test 'eql))
        (*validation-resolve-room-targets* nil))
    (validate-node room nil room)
    (signal-validation-errors "Room"))
  room)

(defun validate-game (game)
  (prepare-game game)
  (let ((*validation-errors* nil)
        (*validation-choice-ids* (make-hash-table :test 'eql))
        (*validation-resolve-room-targets* t))
    (validate-game-start game)
    (validate-state-declaration-list "Game"
                                     (game-global-state-declarations game))
    (when (game-player game)
      (validate-node (game-player game) game game))
    (dolist (table (game-tables game))
      (validate-node table game game))
    (dolist (room (game-rooms game))
      (validate-node room game room))
    (signal-validation-errors "Game"))
  game)

(defmethod validate-node ((thing t) game context)
  (declare (ignore thing game context))
  nil)

(defun validate-node-list (nodes game context)
  (dolist (node nodes)
    (validate-node node game context)))

(defmethod validate-node ((thing room) game context)
  (declare (ignore context))
  (validate-node-list (entities thing) game thing))

(defmethod validate-node ((thing entity) game context)
  (declare (ignore context))
  (validate-state-declaration-list
   (format nil "Entity ~S" (or (entity-id thing) (name thing)))
   (state-declarations thing))
  (validate-node-list (entities thing) game thing))

(defmethod validate-node ((thing branch) game context)
  (validate-condition (branch-condition thing) game context)
  (validate-node-list (branch-then-entities thing) game context)
  (validate-node-list (branch-else-entities thing) game context))

(defmethod validate-node ((thing choices) game context)
  (validate-node-list (options thing) game context))

(defmethod validate-node ((thing choice) game context)
  (validate-availability-node thing game context)
  (validate-choice-id thing)
  (validate-node (target thing) game context))

(defmethod validate-node ((thing player) game context)
  (declare (ignore game context))
  (validate-player-current-maximum (player-str thing)
                                   (player-max-str thing)
                                   "STR")
  (validate-player-current-maximum (player-dex thing)
                                   (player-max-dex thing)
                                   "DEX")
  (validate-player-current-maximum (player-wil thing)
                                   (player-max-wil thing)
                                   "WIL")
  (validate-player-current-maximum (player-hp thing)
                                   (player-max-hp thing)
                                   "HP")
  (handler-case
      (validate-player-inventory-data (player-inventory thing))
    (error (condition)
      (validation-error "~A" condition))))

(defun table-result-reference-id (result)
  (when (and (consp result)
             (eq (first result) :table)
             (consp (rest result))
             (null (cddr result)))
    (second result)))

(defun table-range-high (range)
  (cdr range))

(defun table-ranges-overlap-p (left right)
  (and (<= (car left) (cdr right))
       (<= (car right) (cdr left))))

(defun validate-table-entry-list (table)
  (when (null (table-entries table))
    (validation-error "Table ~S must contain at least one entry."
                      (table-id table)))
  (when (eq (table-mode table) :roll)
    (let ((seen-ranges nil))
      (dolist (entry (table-entries table))
        (let ((range (table-entry-range entry)))
          (unless range
            (validation-error "Roll table ~S entry ~S is missing :RANGE."
                              (table-id table)
                              (table-entry-result entry)))
          (when range
            (dolist (seen seen-ranges)
              (when (table-ranges-overlap-p range seen)
                (validation-error "Roll table ~S has overlapping ranges ~S and ~S."
                                  (table-id table)
                                  range
                                  seen)))
            (push range seen-ranges)))))))

(defmethod validate-node ((thing random-table) game context)
  (declare (ignore context))
  (validate-table-entry-list thing)
  (dolist (entry (table-entries thing))
    (validate-node entry game thing)))

(defmethod validate-node ((thing table-entry) game context)
  (declare (ignore context))
  (validate-availability-node thing game nil)
  (let ((table-id (table-result-reference-id (table-entry-result thing))))
    (when table-id
      (unless (keywordp table-id)
        (validation-error "Table reference result must use a keyword id; got ~S."
                          table-id))
      (when (and game
                 (keywordp table-id)
                 (not (nth-value 1 (gethash table-id (table-index game)))))
        (validation-error "Table entry references missing table ~S."
                          table-id)))))

(defun validate-effect-tree (effects game context)
  (cond
    ((null effects)
     nil)
    ((listp effects)
     (validation-error
      "Effect lists are not valid; wrap authored effects in (:sequence :effects ...)."))
    ((typep effects 'effect-node)
     (validate-node effects game context))
    (t
     (validation-error "Expected an effect node, got ~S." effects))))

(defun validate-effect-list (effects game context)
  (dolist (effect effects)
    (validate-effect-tree effect game context)))

(defmethod validate-node ((thing action) game context)
  (unless (typep context 'entity)
    (validation-error "Action ~S must be inside an entity." (label thing)))
  (validate-effect-tree (effects thing) game context))

(defmethod validate-node ((thing container) game context)
  (validate-node-list (contents thing) game context))

(defmethod validate-node ((thing placement) game context)
  (when (interaction-target thing)
    (validate-node (interaction-target thing) game context)))

(defmethod validate-node ((thing condition-eq) game context)
  (validate-condition thing game context))

(defmethod validate-node ((thing condition-not) game context)
  (validate-condition thing game context))

(defmethod validate-node ((thing condition-and) game context)
  (validate-condition thing game context))

(defmethod validate-node ((thing condition-or) game context)
  (validate-condition thing game context))

(defmethod validate-node ((thing state-ref) game context)
  (declare (ignore context))
  (case (state-ref-scope thing)
    (:ref
     (unless (state-ref-role thing)
       (validation-error "REF state reference with key ~S is missing a role."
                         (state-ref-key thing)))
     (when (and (state-ref-role thing)
                (not (keywordp (state-ref-role thing))))
       (validation-error "REF state reference role must be a keyword; got ~S."
                         (state-ref-role thing)))
     (unless (state-ref-key thing)
       (validation-error "REF state reference with role ~S is missing a key."
                         (state-ref-role thing))))
    ((:self :global)
     (unless (state-ref-key thing)
       (validation-error "~S state reference is missing a key."
                         (state-ref-scope thing)))
     (when (and (eq (state-ref-scope thing) :global)
                game
                (state-ref-key thing)
                (global-state-declared-p game)
                (not (member (state-key (state-ref-key thing))
                             (declared-global-state-keys game)
                             :test #'eql)))
       (validation-error "GLOBAL state reference uses undeclared key ~S. Declared keys: ~S."
                         (state-ref-key thing)
                         (declared-global-state-keys game))))
    (otherwise
     (validation-error "Unknown state scope ~S."
                       (state-ref-scope thing))))
  (when (and (state-ref-key thing)
             (not (keywordp (state-ref-key thing))))
    (validation-error "State reference key must be a keyword; got ~S."
                      (state-ref-key thing))))

(defmethod validate-node ((thing sequence) game context)
  (validate-effect-list (sequence-effects thing) game context))

(defmethod validate-node ((thing state-effect) game context)
  (validate-node (effect-target thing) game context))

(defmethod validate-node ((thing state-set) game context)
  (call-next-method)
  (validate-node (effect-value thing) game context))

(defmethod validate-node ((thing state-inc) game context)
  (call-next-method)
  (validate-node (effect-amount thing) game context))

(defmethod validate-node ((thing state-dec) game context)
  (call-next-method)
  (validate-node (effect-amount thing) game context))

(defmethod validate-node ((thing say) game context)
  (validate-node (say-text thing) game context))

(defmethod validate-node ((thing conditional-effect) game context)
  (validate-condition (conditional-effect-condition thing) game context)
  (validate-effect-tree (conditional-effect-then thing) game context)
  (validate-effect-tree (conditional-effect-else thing) game context))

(defmethod validate-node ((thing goto) game context)
  (declare (ignore context))
  (validate-room-target thing game (room-name thing)))

(defmethod validate-node ((thing gosub) game context)
  (declare (ignore context))
  (validate-room-target thing game (room-name thing)))
