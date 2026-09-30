(in-package #:dunge)

;;; Dice and tables
;;;
;;; The game generator, dice expressions, and table rolls. Rolls draw from a
;;; WORLD's generator and are recorded in its roll log.

(defun find-table (game table-id)
  (multiple-value-bind (table present-p) (gethash (table-id-key table-id)
                                                  (table-index game))
    (if present-p
        table
        (error "No table named ~S." table-id))))

(defun runtime-context-for-table (game world context)
  "A context for rolling GAME's tables: CONTEXT, playing in WORLD when one is
given explicitly."
  (cond
    ((null context)
     (make-runtime-context :game game :world world))
    ((and world (not (eq world (runtime-context-world context))))
     (let ((copy (copy-runtime-context context)))
       (setf (runtime-context-world copy) world)
       copy))
    (t
     context)))

(defun next-dunge-random-state (state)
  (mod (+ (* +dunge-rng-multiplier+ state)
          +dunge-rng-increment+)
       +dunge-rng-modulus+))

(defun world-random (world limit)
  "Draw from WORLD's generator: a number from 0 below LIMIT."
  (positive-integer-value limit "Random limit")
  (let ((next-state (next-dunge-random-state (world-rng-state world))))
    (setf (world-rng-state world) next-state)
    (mod next-state limit)))

(defun table-random (world limit random-state)
  (if random-state
      (random limit random-state)
      (world-random world limit)))

(defun dice-expression-string (expression)
  (unless (stringp expression)
    (error "Dice expressions must be strings; got ~S." expression))
  (let ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return)
                              expression)))
    (when (string= trimmed "")
      (error "Dice expressions cannot be empty."))
    trimmed))

(defun dice-integer-substring (expression start end label &key positive)
  (when (= start end)
    (error "~A is missing in dice expression ~S." label expression))
  (let ((value (handler-case
                   (parse-integer expression
                                  :start start
                                  :end end
                                  :junk-allowed nil)
                 (error ()
                   nil))))
    (unless value
      (error "~A must be an integer in dice expression ~S."
             label
             expression))
    (if positive
        (positive-integer-value value label)
        (non-negative-integer-value value label))))

(defun dice-modifier-position (expression start)
  (loop for index from start below (length expression)
        for char = (char expression index)
        when (or (char= char #\+)
                 (char= char #\-))
          do (return index)))

(defun parse-dice-expression (expression)
  (let* ((expression (dice-expression-string expression))
         (d-position (position #\d expression :test #'char-equal)))
    (unless d-position
      (error "Dice expression ~S must contain D, as in \"1d6\"." expression))
    (when (position #\d expression
                    :test #'char-equal
                    :start (1+ d-position))
      (error "Dice expression ~S contains more than one D." expression))
    (let* ((modifier-position
             (dice-modifier-position expression (1+ d-position)))
           (sides-end (or modifier-position (length expression)))
           (count (if (zerop d-position)
                      1
                      (dice-integer-substring expression
                                              0
                                              d-position
                                              "Dice count"
                                              :positive t)))
           (sides (dice-integer-substring expression
                                          (1+ d-position)
                                          sides-end
                                          "Dice sides"
                                          :positive t))
           (modifier (if modifier-position
                         (let ((magnitude
                                 (dice-integer-substring expression
                                                         (1+ modifier-position)
                                                         (length expression)
                                                         "Dice modifier")))
                           (if (char= (char expression modifier-position) #\-)
                               (- magnitude)
                               magnitude))
                         0)))
      (list :expression expression
            :count count
            :sides sides
            :modifier modifier))))

(defun dice-roll-log-entry (spec rolls total label)
  (append (list :dice (getf spec :expression)
                :count (getf spec :count)
                :sides (getf spec :sides)
                :rolls (copy-list rolls))
          (unless (zerop (getf spec :modifier))
            (list :modifier (getf spec :modifier)))
          (when label
            (list :label label))
          (list :result total)))

(defun dice-random-roll (world sides random-state)
  (1+ (table-random world sides random-state)))

(defun roll-dice (world expression &key label random-state (record t))
  (roll-dice-spec world
                  (parse-dice-expression expression)
                  :label label
                  :random-state random-state
                  :record record))

(defun roll-dice-spec (world spec &key label random-state (record t))
  "Roll the parsed dice SPEC, as returned by PARSE-DICE-EXPRESSION, from
WORLD's generator or an explicit RANDOM-STATE."
  (unless (or world random-state)
    (error "Rolling dice requires a world or explicit random state."))
  (let* ((rolls (loop repeat (getf spec :count)
                      collect (dice-random-roll world
                                                (getf spec :sides)
                                                random-state)))
         (total (+ (reduce #'+ rolls)
                   (getf spec :modifier)))
         (entry (dice-roll-log-entry spec rolls total label)))
    (when (and record world)
      (push entry (world-roll-log world)))
    (values total entry)))

(defun roll-dice-value (world value &key label random-state (record t))
  (cond
    ((integerp value)
     (values (non-negative-integer-value value "Dice value") nil))
    ((stringp value)
     (roll-dice world value
                :label label
                :random-state random-state
                :record record))
    (t
     (error "Dice values must be non-negative integers or dice strings; got ~S."
            value))))

(defun record-table-roll (world entry)
  (when world
    (push entry (world-roll-log world)))
  entry)

(defun table-available-entries (table context)
  (let ((entries (remove-if-not (lambda (entry)
                                  (available-p entry context))
                                (table-entries table))))
    (unless entries
      (error "Table ~S has no available entries." (table-id table)))
    entries))

(defun choose-indexed-entry (entries index)
  (elt entries index))

(defun choose-random-entry (world entries random-state)
  (let ((index (table-random world (length entries) random-state)))
    (values (choose-indexed-entry entries index)
            (list :index index))))

(defun choose-weighted-entry (world entries random-state)
  (let ((total (reduce #'+ entries :key #'table-entry-weight)))
    (loop with roll = (table-random world total random-state)
          with remaining = roll
          for entry in entries
          for weight = (table-entry-weight entry)
          do (if (< remaining weight)
                 (return (values entry
                                 (list :roll roll
                                       :total total)))
                 (decf remaining weight)))))

(defun table-range-contains-p (range value)
  (and (<= (car range) value)
       (<= value (cdr range))))

(defun choose-roll-entry (world table entries random-state)
  (let* ((highest (reduce #'max entries
                          :key (lambda (entry)
                                 (table-range-high (table-entry-range entry)))))
         (roll (1+ (table-random world highest random-state))))
    (let ((entry (find-if (lambda (entry)
                            (table-range-contains-p (table-entry-range entry) roll))
                          entries)))
      (unless entry
        (error "Roll table ~S rolled ~D, but no entry covers that result."
               (table-id table)
               roll))
      (values entry
              (list :roll roll
                    :die highest)))))

(defun choose-sequence-entry (world table entries)
  (let* ((state (world-table-state world table))
         (last-index (1- (length entries)))
         (index (min (table-state-sequence-index state)
                     last-index))
         (entry (choose-indexed-entry entries index)))
    (setf (table-state-sequence-index state)
          (min (1+ index) last-index))
    (values entry
            (list :index index))))

(defun choose-deck-entry (world table entries random-state)
  (let* ((drawn (table-state-deck-drawn (world-table-state world table)))
         (remaining (remove-if (lambda (entry)
                                 (gethash (table-entry-ordinal entry) drawn))
                               entries))
         (reshuffled nil))
    (unless remaining
      (clrhash drawn)
      (setf remaining entries
            reshuffled t))
    (multiple-value-bind (entry details)
        (choose-random-entry world remaining random-state)
      (setf (gethash (table-entry-ordinal entry) drawn) t)
      (values entry
              (append details
                      (list :remaining (length remaining)
                            :reshuffled reshuffled))))))

(defun choose-table-entry (world table context random-state)
  (let ((entries (table-available-entries table context)))
    (ecase (table-mode table)
      (:weighted
       (choose-weighted-entry world entries random-state))
      (:roll
       (choose-roll-entry world table entries random-state))
      (:deck
       (choose-deck-entry world table entries random-state))
      (:sequence
       (choose-sequence-entry world table entries))
      (:first-match
       (values (first entries)
               (list :index 0))))))

(defun table-reference-result-id (result)
  (when (and (consp result)
             (eq (first result) :table)
             (consp (rest result))
             (null (cddr result)))
    (second result)))

(defun resolve-table-result (game result context random-state)
  (let ((nested-table-id (table-reference-result-id result)))
    (if nested-table-id
        (roll-table game nested-table-id
                    :context context
                    :random-state random-state)
        result)))

(defun table-roll-log-entry (table entry result details)
  (append (list :table (table-id table)
                :mode (table-mode table)
                :entry (and entry (table-entry-ordinal entry)))
          details
          (list :result result)))

(defun roll-table (game table-id &key world context random-state)
  "Roll GAME's table TABLE-ID. Dice, table positions, and the roll log come
from WORLD, or from CONTEXT's world when WORLD is not given."
  (let* ((table (find-table game table-id))
         (context (runtime-context-for-table game world context))
         (world (runtime-context-world context)))
    (if (eq (table-mode table) :bundle)
        (let ((result (mapcar (lambda (entry)
                                (resolve-table-result game
                                                      (table-entry-result entry)
                                                      context
                                                      random-state))
                              (table-available-entries table context))))
          (record-table-roll
           world
           (table-roll-log-entry table nil result nil))
          (values result nil))
        (multiple-value-bind (entry details)
            (choose-table-entry world table context random-state)
          (let ((result (resolve-table-result game
                                              (table-entry-result entry)
                                              context
                                              random-state)))
            (record-table-roll
             world
             (table-roll-log-entry table entry result details))
            (values result entry))))))
