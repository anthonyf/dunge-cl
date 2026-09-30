(in-package #:dunge.crawler)

;;; Crawler build procedures
;;;
;;; Common Lisp code that turns tables and rules into ordinary Dunge content
;;; before play. Nothing here runs during play: loot, rations, and the
;;; player's inventory are plain choices and :PLAYER state that both runtimes
;;; already understand.

(defconstant +inventory-capacity+ 10
  "How many inventory slots a player has. Fatigue fills slots too.")

;;; Inventory entries: (KIND ID &key count slots bulky condition tags), where
;;; KIND is :ITEM or :SUPPLY.

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

;;; Table results

(defun table-result-data-p (result)
  (and (consp result)
       (keywordp (first result))))

(defun table-result-kind (result)
  (unless (table-result-data-p result)
    (error "Table result must be a list beginning with a keyword; got ~S."
           result))
  (first result))

(defun table-result-keyword-payload (result label)
  (let ((payload (second result)))
    (unless (keywordp payload)
      (error "~A table result must name a keyword id; got ~S."
             label
             result))
    payload))

(defun table-result-shape-length (result label)
  (let ((length (handler-case
                    (list-length result)
                  (type-error ()
                    nil))))
    (unless length
      (error "~A table result must be a proper, non-circular list; got ~S."
             label
             result))
    length))

(defun ensure-table-result-shape (result label shape length)
  (unless (= (table-result-shape-length result label) length)
    (error "~A table result must be ~A; got ~S."
           label
           shape
           result))
  result)

(defun resolve-table-result-amount (game amount label random-state record)
  (multiple-value-bind (value roll-entry)
      (roll-dice-value game amount
                       :label label
                       :random-state random-state
                       :record record)
    (declare (ignore roll-entry))
    value))

(defun resolve-table-result-options (game options random-state record)
  (ensure-runtime-property-list options "table result options")
  (loop for (key value) on options by #'cddr
        append (list key
                     (if (eq key :count)
                         (positive-integer-value
                          (resolve-table-result-amount game
                                                       value
                                                       :result-count
                                                       random-state
                                                       record)
                          "Table result count")
                         value))))

(defun resolve-inventory-table-result (game result random-state record)
  (let* ((kind (table-result-kind result))
         (id (table-result-keyword-payload result "Inventory"))
         (options (resolve-table-result-options game
                                                (cddr result)
                                                random-state
                                                record))
         (entry (append (list kind id) options)))
    (validate-inventory-entry-data entry)
    entry))

(defun resolve-gold-table-result (game result random-state record)
  (ensure-table-result-shape result "Gold" "(:GOLD AMOUNT)" 2)
  (list :gold
        (resolve-table-result-amount game
                                     (second result)
                                     :result-gold
                                     random-state
                                     record)))

(defun resolve-counted-table-result (game result random-state record label)
  (let* ((kind (table-result-kind result))
         (id (table-result-keyword-payload result label))
         (options (resolve-table-result-options game
                                                (cddr result)
                                                random-state
                                                record)))
    (append (list kind id) options)))

(defun resolve-exit-table-result (result)
  (ensure-table-result-shape result "Exit" "(:EXIT DIRECTION ROOM-ID)" 3)
  (let ((direction (second result))
        (target (third result)))
    (unless (keywordp direction)
      (error "Exit table result direction must be a keyword; got ~S."
             result))
    (unless (stringp target)
      (error "Exit table result target must be a room id string; got ~S."
             result))
    (list :exit direction target)))

(defun resolve-table-result-data (game result &key random-state (record t))
  (cond
    ((table-result-data-p result)
     (case (table-result-kind result)
       (:gold
        (resolve-gold-table-result game result random-state record))
       ((:item :supply)
        (resolve-inventory-table-result game result random-state record))
       ((:encounter)
        (resolve-counted-table-result game
                                      result
                                      random-state
                                      record
                                      "Encounter"))
       ((:exit)
        (resolve-exit-table-result result))
       (otherwise
        (copy-tree result))))
    ((listp result)
     (mapcar (lambda (entry)
               (resolve-table-result-data game
                                          entry
                                          :random-state random-state
                                          :record record))
             result))
    (t
     result)))

(defun table-result-loot-p (result)
  (and (table-result-data-p result)
       (member (table-result-kind result) '(:gold :item :supply) :test #'eq)))

(defun table-result-loot-results (result)
  (cond
    ((table-result-loot-p result)
     (list (copy-tree result)))
    ((and (listp result)
          (not (table-result-data-p result)))
     (loop for entry in result
           append (table-result-loot-results entry)))
    (t nil)))

(defun table-result-exit-p (result)
  (and (table-result-data-p result)
       (eq (table-result-kind result) :exit)))

(defun table-result-exit (result)
  (when (table-result-exit-p result)
    (destructuring-bind (kind direction target) (resolve-exit-table-result result)
      (declare (ignore kind))
      (cons direction target))))

(defun table-result-exits (result)
  (cond
    ((table-result-exit-p result)
     (list (table-result-exit result)))
    ((and (listp result)
          (not (table-result-data-p result)))
     (loop for entry in result
           append (table-result-exits entry)))
    (t nil)))

(defun table-result-encounter-p (result)
  (and (table-result-data-p result)
       (eq (table-result-kind result) :encounter)))

(defun table-result-encounters (result)
  (cond
    ((table-result-encounter-p result)
     (list (copy-tree result)))
    ((and (listp result)
          (not (table-result-data-p result)))
     (loop for entry in result
           append (table-result-encounters entry)))
    (t nil)))

(defun table-result-option (result key &optional default)
  (ensure-runtime-property-list (cddr result) "table result options")
  (let ((missing '#:missing))
    (let ((value (getf (cddr result) key missing)))
      (if (eq value missing)
          default
          value))))

;;; Player state
;;;
;;; The player is ordinary :PLAYER state. Each inventory item or supply is a
;;; counter named by its id, so (:item :lantern) held once is (:lantern 1).

(defun item-catalog (entries)
  "Return an alist of (ID . ENTRY) for inventory ENTRIES, keeping the first
entry for each id. Counts in ENTRIES are ignored."
  (let ((catalog '()))
    (dolist (entry entries)
      (let* ((id (inventory-entry-id entry))
             (known (cdr (assoc id catalog))))
        (cond
          ((null known)
           (push (cons id entry) catalog))
          ((not (eq (inventory-entry-kind known) (inventory-entry-kind entry)))
           ;; One counter per id cannot hold both an item and a supply.
           (error "Inventory id ~S is both an ~(~A~) and a ~(~A~)."
                  id
                  (inventory-entry-kind known)
                  (inventory-entry-kind entry))))))
    (nreverse catalog)))

(defun table-loot-entries (game)
  "Return every :ITEM and :SUPPLY result that GAME's tables can produce."
  (loop for table in (game-tables game)
        append (loop for entry in (table-entries table)
                     append (remove-if-not
                             (lambda (result)
                               (member (table-result-kind result)
                                       '(:item :supply)))
                             (table-result-loot-results
                              (table-entry-result entry))))))

(defun slot-term (id entry)
  "The slots ID's counter uses, as an expression, or NIL for none.
A stack with explicit :SLOTS uses that many however large it is; otherwise a
supply stack uses one slot and each item one, or two when :BULKY."
  (let* ((missing '#:missing)
         (slots (inventory-option-value entry :slots missing)))
    (cond
      ((not (eq slots missing))
       (non-negative-integer-value slots "Inventory entry :SLOTS")
       (unless (zerop slots)
         `(:mul ,slots (:min 1 (:player ,id)))))
      ((eq (inventory-entry-kind entry) :supply)
       `(:min 1 (:player ,id)))
      (t
       `(:mul ,(if (inventory-entry-bulky-p entry) 2 1) (:player ,id))))))

(defun used-slots-expression (catalog)
  "An expression for the inventory slots the player uses: fatigue plus each
item and supply in CATALOG."
  `(:add (:player :fatigue)
         ,@(loop for (id . entry) in catalog
                 for term = (slot-term id entry)
                 when term
                   collect term)))

(defparameter +player-stat-keys+
  '(:name :background :str :max-str :dex :max-dex :wil :max-wil :hp :max-hp
    :armor :gold :fate :fatigue :deprived))

(defun player-declarations (&key name background (str 10) max-str (dex 10)
                              max-dex (wil 10) max-wil (hp 1) max-hp
                              (armor 0) (gold 0) (fate 0) (fatigue 0)
                              deprived inventory catalog)
  "Return :PLAYER state declarations. INVENTORY entries give starting counts;
every id in INVENTORY or CATALOG, an ITEM-CATALOG, gets a counter."
  (loop for (label value) on (list "STR" str "DEX" dex "WIL" wil "HP" hp
                                   "armor" armor "gold" gold "fate" fate
                                   "fatigue" fatigue)
        by #'cddr
        do (non-negative-integer-value value (format nil "Player ~A" label)))
  (let ((counts '()))
    (dolist (entry inventory)
      (validate-inventory-entry-data entry)
      (let ((id (inventory-entry-id entry)))
        (setf (getf counts id)
              (+ (getf counts id 0) (inventory-entry-count entry)))))
    (let ((ids (mapcar #'car (item-catalog
                              (append inventory (mapcar #'cdr catalog))))))
      (dolist (id ids)
        (when (member id +player-stat-keys+)
          (error "Inventory id ~S collides with a player stat." id)))
      (append
       `((:name ,name) (:background ,background)
         (:str ,str) (:max-str ,(or max-str str))
         (:dex ,dex) (:max-dex ,(or max-dex dex))
         (:wil ,wil) (:max-wil ,(or max-wil wil))
         (:hp ,hp) (:max-hp ,(or max-hp hp))
         (:armor ,armor) (:gold ,gold) (:fate ,fate)
         (:fatigue ,fatigue) (:deprived ,deprived))
       (mapcar (lambda (id) (list id (getf counts id 0))) ids)))))

(defun ration-choice-form (&key (used-slots '(:player :fatigue))
                             (capacity +inventory-capacity+))
  "An \"Eat ration\" choice, offered when the player has a ration and is
hurt, fatigued, or deprived. A full inventory (USED-SLOTS at CAPACITY) counts
as deprived."
  `(:choice "Eat ration"
    ((:dec :target (:player :ration))
     (:set :target (:player :hp)
           :value (:min (:player :max-hp) (:add (:player :hp) 1)))
     (:set :target (:player :fatigue)
           :value (:max 0 (:sub (:player :fatigue) 1)))
     (:set :target (:player :deprived) :value nil)
     (:say "You eat a ration and recover."))
    :when (:and (:gt (:player :ration) 0)
                (:or (:lt (:player :hp) (:player :max-hp))
                     (:gt (:player :fatigue) 0)
                     (:player :deprived)
                     (:gte ,used-slots ,capacity)))))

;;; Generated rooms

(defun display-word (value)
  "Show VALUE as the browser's DISPLAY-VALUE does: a keyword's words split at
hyphens with each first letter capitalized, anything else as plain text."
  (if (keywordp value)
      (format nil "~{~A~^ ~}"
              (loop for part in (uiop:split-string
                                 (string-downcase (symbol-name value))
                                 :separator "-")
                    when (plusp (length part))
                      collect (concatenate 'string
                                           (string-upcase (subseq part 0 1))
                                           (subseq part 1))))
      (format-dunge-value value)))

(defun display-lower (value)
  (string-downcase (display-word value)))

(defun exit-label (direction)
  (case direction
    (:back "Return")
    (:deeper "Continue deeper")
    (:out "Leave")
    (otherwise
     (format nil "Go ~A" (string-downcase (symbol-name direction))))))


(defun escape-braces (text)
  "Make TEXT safe to use as a string expression, which interpolates {...}."
  (with-output-to-string (out)
    (loop for char across text
          do (when (member char '(#\{ #\}))
               (write-char char out))
             (write-char char out))))

(defun result-count (result)
  (positive-integer-value (getf (cddr result) :count 1)
                          "Generated room result count"))

(defun result-line (result)
  "Describe one generated room table RESULT."
  (let ((kind (and (consp result) (first result))))
    (case kind
      (:gold
       (format nil "Treasure: ~D gold." (second result)))
      ((:item :supply)
       (let ((count (result-count result)))
         (format nil "Find: ~A~:[~; x~D~]."
                 (display-word (second result))
                 (> count 1)
                 count)))
      (:encounter
       (format nil "Sign: ~A stirs here."
               (display-word (second result))))
      (:exit
       (format nil "Passage: ~A." (display-word (second result))))
      (t
       (if (and (consp result) (keywordp (second result)))
           (format nil "~A: ~A."
                   (display-word kind)
                   (display-word (second result)))
           (format nil "~A."
                   (display-word (if (consp result)
                                                    kind
                                                    result))))))))

(defun loot-text (result)
  (ecase (table-result-kind result)
    (:gold
     (format nil "~D gold"
             (non-negative-integer-value (second result)
                                         "Generated room gold amount")))
    ((:item :supply)
     (let ((count (result-count result))
           (name (display-lower (second result))))
       (if (= count 1)
           name
           (format nil "~A x~D" name count))))))

(defun loot-choice-form (id result)
  "A once-only choice with id ID that adds the loot RESULT to the player."
  (let ((text (loot-text result)))
    (multiple-value-bind (key amount)
        (if (eq (table-result-kind result) :gold)
            (values :gold (second result))
            (values (second result) (result-count result)))
      `(:choice ,(format nil "Take ~A" text)
        ((:inc :target (:player ,key) :amount ,amount)
         (:say ,(escape-braces (format nil "You take ~A." text))))
        :id ,id
        :once t))))

(defun id-part (string)
  "Encode STRING for use in a keyword id: lower-case letters and digits stand
for themselves, and any other character becomes _ and its code in hex, so
distinct strings, even ones differing only in case, stay distinct."
  (with-output-to-string (out)
    (loop for char across string
          do (if (or (char<= #\a char #\z) (char<= #\0 char #\9))
                 (write-char char out)
                 (format out "_~(~X~)_" (char-code char))))))

(defun encounter-spec (result &key hp max-hp armor damage)
  "Describe the encounter an :ENCOUNTER table RESULT starts. Keyword
arguments override the result's own options."
  (unless (table-result-encounter-p result)
    (error "An encounter needs an :ENCOUNTER table result; got ~S." result))
  (let* ((hp (non-negative-integer-value
              (or hp (table-result-option result :hp 3))
              "Encounter HP"))
         (max-hp (non-negative-integer-value
                  (or max-hp (table-result-option result :max-hp hp))
                  "Encounter max HP"))
         (damage (or damage (table-result-option result :damage 1))))
    (when (> hp max-hp)
      (error "Encounter HP ~D is above its maximum ~D." hp max-hp))
    (if (stringp damage)
        (parse-dice-expression damage)
        (non-negative-integer-value damage "Encounter damage"))
    (list :enemy (second result)
          :hp hp
          :max-hp max-hp
          :armor (non-negative-integer-value
                  (or armor (table-result-option result :armor 0))
                  "Encounter armor")
          :damage damage)))

(defun damage-expression (damage label)
  "DAMAGE, an integer or dice, as an expression. Integers roll nothing."
  (etypecase damage
    (integer damage)
    (string `(:roll ,damage :label ,label))))

(defun encounter-entity-form (spec &key active-options inactive-options)
  "An entity holding the encounter SPEC describes. While it is active it
offers Attack, ACTIVE-OPTIONS, and Flee; afterwards, INACTIVE-OPTIONS."
  (destructuring-bind (&key enemy hp max-hp armor damage) spec
    (let ((name (escape-braces (display-word enemy))))
      `(:entity
        :name ,name
        :id "encounter"
        :state ((:status :active) (:hp ,hp) (:max-hp ,max-hp) (:armor ,armor)
                (:dealt 0) (:taken 0) (:round 0))
        :body
        ((:p ,(format nil "Encounter: ~A ({self:status}, HP {self:hp}/{self:max-hp})."
                      name))
         (:branch
          :when (:eq (:self :status) :active)
          :then
          ((:action
            :label ,(format nil "Attack ~A"
                            (escape-braces (display-lower enemy)))
            :do
            ((:inc :target (:self :round))
             (:set :target (:self :dealt)
                   :value (:max 0 (:sub (:roll "1d6" :label :player-damage)
                                        (:self :armor))))
             (:set :target (:self :hp)
                   :value (:max 0 (:sub (:self :hp) (:self :dealt))))
             (:if
              :when (:lte (:self :hp) 0)
              :then
              ((:set :target (:self :status) :value :defeated)
               (:say ,(format nil "You strike for {self:dealt} damage. ~A falls."
                              name)))
              :else
              ((:set :target (:self :taken)
                     :value (:max 0 (:sub ,(damage-expression damage :enemy-damage)
                                          (:player :armor))))
               (:set :target (:player :hp)
                     :value (:max 0 (:sub (:player :hp) (:self :taken))))
               (:if
                :when (:lte (:player :hp) 0)
                :then
                ((:set :target (:self :status) :value :player-defeated)
                 (:say "You strike for {self:dealt} damage, but take {self:taken} damage and fall.")
                 (:quit))
                :else
                ((:say ,(format nil "You strike for {self:dealt} damage. ~A hits back for {self:taken} damage."
                                name))))))))
           ,@active-options
           (:action
            :label "Flee"
            :do
            ((:inc :target (:self :round))
             (:set :target (:self :status) :value :escaped)
             (:say ,(format nil "You escape from ~A." name)))))
          :else ,inactive-options))))))


;;; Building a game
;;;
;;; BUILD-GAME compiles a game's source once as a scratch game, lets a builder
;;; roll its tables and plan rooms, then compiles the final game from the
;;; source with the planned rooms and initial values spliced in. The builder's
;;; dice come from a stream derived from the seed, so play starts from the
;;; seed itself with an empty roll log.

(defstruct (build (:constructor %make-build (scratch)))
  "What a builder has planned so far."
  scratch
  (rooms '())
  (room-counter 0)
  player
  ;; Whether SET-PLAYER was called, since NIL is a valid set of declarations.
  (player-set-p nil)
  (globals '()))

(defstruct room-plan
  id title description results exits options encounter encounter-options)

(defun build-seed (seed)
  "The build's generator state for game SEED: a stream separate from play."
  (mod (+ (* seed 2654435761) 1013904223) +dunge-rng-modulus+))

(defun build-game-object (build)
  "The scratch game whose tables and generator BUILD uses."
  (build-scratch build))

(defun next-room-id (build zone)
  "The next automatic id for a room in ZONE, skipping ids already planned."
  (loop for id = (format nil "generated:~(~A~):~D"
                         (or zone :room)
                         (incf (build-room-counter build)))
        unless (find id (build-rooms build) :key #'room-plan-id :test #'equal)
          return id))

(defun create-generated-room (build &key id zone title description results
                                      exits options encounter
                                      encounter-options)
  "Plan a room built from resolved table RESULTS and return its plan.
When the game is built, its body describes the room and offers a once-only
choice for each loot result, then OPTIONS (choice source forms), then a choice
per exit. ENCOUNTER, an ENCOUNTER-SPEC, adds an encounter that must end
before any of those are offered; while it is active it offers Attack,
ENCOUNTER-OPTIONS, and Flee. A plan whose ID matches an authored room
replaces that room."
  (let ((plan (make-room-plan
               :id (or id (next-room-id build zone))
               :title title
               :description description
               :results (copy-tree results)
               :exits (copy-tree exits)
               :options options
               :encounter encounter
               :encounter-options encounter-options)))
    (when (find (room-plan-id plan) (build-rooms build)
                :key #'room-plan-id :test #'equal)
      (error "Duplicate planned room id ~S." (room-plan-id plan)))
    (push plan (build-rooms build))
    plan))

(defun room-plan-exit (plan direction)
  (cdr (assoc direction (room-plan-exits plan))))

(defun set-room-plan-exit (plan direction target)
  "Point PLAN's DIRECTION exit at TARGET, a room id or plan."
  (unless (keywordp direction)
    (error "Exit directions must be keywords; got ~S." direction))
  (let ((target (if (room-plan-p target) (room-plan-id target) target))
        (existing (assoc direction (room-plan-exits plan))))
    (unless (stringp target)
      (error "Exit targets must be room ids or plans; got ~S." target))
    (if existing
        (setf (cdr existing) target)
        (setf (room-plan-exits plan)
              (append (room-plan-exits plan) (list (cons direction target)))))
    plan))

(defun link-rooms (from direction to &key reverse-direction)
  "Link plan FROM to plan TO through DIRECTION, and back through
REVERSE-DIRECTION when given."
  (unless (keywordp direction)
    (error "Exit directions must be keywords; got ~S." direction))
  (when reverse-direction
    (unless (keywordp reverse-direction)
      (error "Exit directions must be keywords; got ~S." reverse-direction))
    (unless (room-plan-p to)
      (error "A reverse exit needs a planned room to start from; got ~S." to)))
  (set-room-plan-exit from direction to)
  (when reverse-direction
    (set-room-plan-exit to reverse-direction from))
  (values from to))

(defun loot-choice-id (room-id index)
  (intern (string-upcase (format nil "~A-loot-~D" (id-part room-id) index))
          :keyword))

(defun room-plan-form (plan)
  "The :ROOM source form for PLAN."
  (let* ((choices (append
                   (loop for result in (room-plan-results plan)
                         for index from 0
                         when (table-result-loot-p result)
                           collect (loot-choice-form
                                    (loot-choice-id (room-plan-id plan) index)
                                    result))
                   (room-plan-options plan)
                   (mapcar (lambda (exit)
                             `(:choice ,(exit-label (car exit)) (:go ,(cdr exit))))
                           (room-plan-exits plan))))
         (body (append
                (when (room-plan-description plan)
                  (list `(:p ,(escape-braces (room-plan-description plan)))))
                (mapcar (lambda (result)
                          `(:p ,(escape-braces (result-line result))))
                        (room-plan-results plan))
                (if (room-plan-encounter plan)
                    (list (encounter-entity-form
                           (room-plan-encounter plan)
                           :active-options (room-plan-encounter-options plan)
                           :inactive-options choices))
                    choices))))
    `(:room :id ,(room-plan-id plan)
            :title ,(or (room-plan-title plan) (room-plan-id plan))
            :body ,body)))

(defun set-player (build declarations)
  "Replace the built game's :PLAYER declarations, even with none."
  (setf (build-player build) declarations
        (build-player-set-p build) t))

(defun set-initial-global (build key value)
  "Start the built game with global KEY set to VALUE."
  (setf (getf (build-globals build) key) value))

(defun source-plist-set (plist key value)
  (let ((copy (copy-list plist)))
    (setf (getf copy key) value)
    copy))

(defun compile-source (source base-path)
  (if base-path
      (compile-dunge-source-at source base-path)
      (compile-dunge-source source)))

(defun room-entry-id (entry base-path)
  "The id of room ENTRY: a room source form, or a file path relative to
BASE-PATH."
  (when (and (stringp entry) (null base-path))
    (error "Room file ~S needs a BASE-PATH to resolve against." entry))
  (let ((form (if (stringp entry)
                  (read-dunge-file
                   (merge-pathnames entry
                                    (uiop:pathname-directory-pathname base-path)))
                  entry)))
    (getf (rest form) :id)))

(defun built-state-fields (plist globals)
  "PLIST with :STATE, :FLAGS, and :MARKED updated for the initial GLOBALS."
  (let ((state (copy-tree (getf plist :state)))
        (flags (copy-list (getf plist :flags)))
        (marked (copy-list (getf plist :marked))))
    (loop for (key value) on globals by #'cddr
          do (let ((declaration (assoc key state)))
               (cond
                 (declaration
                  (setf (second declaration) value))
                 ((or (member key flags) (member key marked))
                  (setf flags (remove key flags)
                        marked (remove key marked))
                  (if value
                      (push key marked)
                      (push key flags)))
                 (t
                  (error "The built game declares no global ~S." key)))))
    (source-plist-set
     (source-plist-set (source-plist-set plist :state state) :flags flags)
     :marked (reverse marked))))

(defun built-source (source build base-path)
  (destructuring-bind (tag &rest plist) source
    (let* ((plans (reverse (build-rooms build)))
           (authored-ids (mapcar (lambda (entry)
                                   (room-entry-id entry base-path))
                                 (getf plist :rooms)))
           ;; A plan replaces its authored room in place, so room order (and
           ;; a start room inferred from the first room) is kept; other plans
           ;; follow the authored rooms.
           (rooms (append
                   (loop for entry in (getf plist :rooms)
                         for id in authored-ids
                         for plan = (find id plans :key #'room-plan-id
                                                   :test #'equal)
                         collect (if plan (room-plan-form plan) entry))
                   (loop for plan in plans
                         unless (member (room-plan-id plan) authored-ids
                                        :test #'equal)
                           collect (room-plan-form plan))))
           (plist (source-plist-set plist :rooms rooms))
           (plist (if (build-player-set-p build)
                      (source-plist-set plist :player (build-player build))
                      plist)))
      (cons tag (built-state-fields plist (build-globals build))))))

(defun build-game (source &key base-path seed (builder (constantly nil)))
  "Build a game from SOURCE, a (:GAME ...) form read from BASE-PATH, if any.
SEED, when given, replaces the source's :SEED. BUILDER is called with a BUILD
whose scratch game rolls from a stream derived from the seed; it plans rooms
and sets initial values, which the returned game starts with."
  (let* ((source (if seed
                     (cons (first source)
                           (source-plist-set (rest source) :seed seed))
                     source))
         (scratch (let ((dunge::*validate-room-targets* nil))
                    (compile-source source base-path)))
         (build (%make-build scratch)))
    (setf (game-random-state scratch) (build-seed (game-random-seed scratch)))
    (funcall builder build)
    (compile-source (built-source source build base-path) base-path)))
