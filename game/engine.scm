;;; engine.scm — Dunge IF engine
;;; Provides room system, choice menus, player record, and game loop.

;;;
;;; Player Record
;;;

(define-record character
  name background str dex wil hp hp-max armor gold fate inventory)

(define *player* nil)

(define (player-ref field)
  "Return a thunk that reads a player field by name."
  (lambda () (hash-ref *player* field)))

(define (init-player!)
  "Initialize *player* with a blank character record."
  (set *player* (make-character nil nil nil nil nil nil nil nil nil nil '())))

(define (callable? x)
  "Check if x is a procedure (compound or primitive)."
  (and (pair? x)
       (or (eq? (car x) 'procedure)
           (eq? (car x) 'primitive))))

;;;
;;; Room Registry
;;;

(define *rooms* (hash-table))
(define *current-room* nil)

(define (get-room name)
  (hash-ref *rooms* name))

(define (goto name)
  "Set the next room to navigate to."
  (set *current-room* name))

;;;
;;; Room Elements
;;;
;;; Each element is a tagged list: (type . data)
;;; The render function dispatches on type.

(define (make-text-element args)
  (list 'text args))

(define-macro (text . args)
  `(list 'text (list ,@args)))

(define (make-exit-element label target)
  (list 'exit label target))

(define-macro (exit label target)
  `(list 'exit ,label (quote ,target)))

(define (make-gate-element condition then-branch else-branch)
  (list 'gate condition then-branch else-branch))

(define-macro (gate condition then-branch . else-branch)
  `(list 'gate (lambda () ,condition)
         (list ,@then-branch)
         (list ,@(if (null? else-branch) '() (car else-branch)))))

(define (make-prompt-element question validate-fn action-fn)
  (list 'prompt question validate-fn action-fn))

(define-macro (prompt question validate-fn action-fn)
  `(list 'prompt ,question ,validate-fn ,action-fn))

(define-macro (dynamic thunk)
  "A dynamic element whose content is generated at render time.
   The thunk receives no arguments and should return a list of choices, a prompt, or nil."
  `(list 'dynamic ,thunk))

(define-macro (combat-encounter . args)
  "Create a combat-encounter element for room definitions."
  `(list 'combat-encounter (hash-table ,@args)))

;;;
;;; define-room macro
;;;

(define-macro (define-room name title . body)
  `(hash-set! *rooms* (quote ,name)
              (hash-table 'title ,title
                          'body (list ,@body))))

;;;
;;; Choice System
;;;

(define (make-choice label action . rest)
  "Create a choice. Optional :guard keyword arg."
  (let ((guard (if (null? rest) (lambda () t) (car rest))))
    (hash-table 'label label
                'action action
                'guard guard)))

(define (choice-visible? choice)
  ((hash-ref choice 'guard)))

(define (display-choices choices)
  "Display numbered menu of choices."
  (let loop ((cs choices) (n 1))
    (when (not (null? cs))
      (display "  ")
      (display n)
      (display ". ")
      (display (hash-ref (car cs) 'label))
      (newline)
      (loop (cdr cs) (+ n 1)))))

(define (read-choice choices)
  "Read and validate player choice. Returns the selected choice."
  (display "> ")
  (let ((input (string->number (read-line))))
    (if (and input (> input 0) (<= input (length choices)))
        (list-ref choices (- input 1))
        (begin
          (display "Invalid choice. Try again.")
          (newline)
          (read-choice choices)))))

;;;
;;; Room Rendering
;;;
;;; render-room walks the body elements, collecting choices.
;;; Returns either a list of choices or a prompt element.

(define (render-element element)
  "Render a single room element. Returns a list of choices, a prompt, or nil."
  (let ((type (car element)))
    (cond
      ((eq? type 'text)
       (let ((args (cadr element)))
         (for-each (lambda (arg)
                     (if (callable? arg)
                         (display (arg))
                         (display arg)))
                   args)
         (newline)
         nil))
      ((eq? type 'exit)
       (let ((label (cadr element))
             (target (caddr element)))
         (list (make-choice label (lambda () (goto target))))))
      ((eq? type 'gate)
       (let ((cond-fn (cadr element))
             (then-branch (caddr element))
             (else-branch (car (cdr (cddr element)))))
         (if (cond-fn)
             (render-elements then-branch)
             (render-elements else-branch))))
      ((eq? type 'prompt)
       element)
      ((eq? type 'dynamic)
       (let ((thunk (cadr element)))
         (thunk)))
      ((eq? type 'combat-encounter)
       (let ((ce (cadr element)))
         ;; Setup on first visit
         (when (not *current-encounter*)
           (let ((enemy-data (hash-ref ce 'enemy)))
             (setup-encounter (make-enemy-from-bestiary (car enemy-data))))
           (let ((intro (hash-ref ce 'intro)))
             (when intro (render-element intro))))
         ;; Active encounter
         (let* ((enc *current-encounter*)
                (state (encounter-state enc)))
           ;; Drain combat log
           (when (encounter-log enc)
             (display (encounter-log enc))
             (newline)
             (set-encounter-log! enc nil))
           ;; First-round DEX save
           (when (and (eq? state 'active) (encounter-first-round enc))
             (set-encounter-first-round! enc nil)
             (if (dex-save *player*)
                 (begin (display "You react quickly!") (newline))
                 (let* ((enemy-result (resolve-enemy-attack))
                        (lines (cons "Caught off guard! The enemy strikes first."
                                     (format-enemy-attack-lines enemy-result))))
                   (display (join-lines lines))
                   (newline)
                   (update-encounter-state enc nil enemy-result nil)
                   (set state (encounter-state enc)))))
           (if (eq? state 'active)
               ;; Show stats + return combat choices
               (let ((e (encounter-enemy enc)))
                 (display (fmt "  " (enemy-name e) " HP: " (enemy-hp e)
                               "/" (enemy-hp-max e) "  STR: " (enemy-str e)))
                 (newline)
                 (display (fmt "  Your HP: " (character-hp *player*)
                               "/" (character-hp-max *player*)
                               "  STR: " (character-str *player*)))
                 (newline)
                 (newline)
                 (combat-choices))
               ;; Terminal state: cleanup + show outcome elements
               (let ((outcome (cond
                                ((eq? state 'victory) (hash-ref ce 'victory))
                                ((eq? state 'death) (hash-ref ce 'death))
                                ((eq? state 'incapacitated) (hash-ref ce 'incapacitated))
                                ((eq? state 'fled) (hash-ref ce 'fled))
                                (else nil))))
                 (cleanup-combat state)
                 (when outcome (render-element outcome)))))))
      (else nil))))

(define (render-elements elements)
  "Render a list of elements. Returns collected choices or a prompt."
  (let loop ((elts elements) (choices '()))
    (if (null? elts)
        choices
        (let ((result (render-element (car elts))))
          (cond
            ;; Prompt - return immediately
            ((and (pair? result) (eq? (car result) 'prompt))
             result)
            ;; List of choices - accumulate
            ((pair? result)
             (loop (cdr elts) (append choices result)))
            ;; Nil - continue
            (else
             (loop (cdr elts) choices)))))))

(define (render-room room-name)
  "Render a room by name. Returns choices or a prompt."
  (let ((room (get-room room-name)))
    (display (hash-ref room 'title))
    (newline)
    (newline)
    (render-elements (hash-ref room 'body))))

;;;
;;; Prompt Handling
;;;

(define (non-empty-string? s)
  (and (string? s) (> (string-length s) 0)))

(define (handle-prompt p)
  "Handle a prompt element: ask question, validate, execute action."
  (let ((question (cadr p))
        (validate-fn (caddr p))
        (action-fn (car (cddr (cdr p)))))
    (display question)
    (display " > ")
    (let ((input (read-line)))
      (if (validate-fn input)
          (action-fn input)
          (begin
            (display "Invalid input. Try again.")
            (newline)
            (handle-prompt p))))))

;;;
;;; Game Loop
;;;

(define (game-loop)
  "Main game loop. Renders current room, handles choices/prompts, repeats."
  (when *current-room*
    (let ((result (render-room *current-room*)))
      (cond
        ;; Prompt
        ((and (pair? result) (eq? (car result) 'prompt))
         (handle-prompt result)
         (game-loop))
        ;; List of choices
        ((and (pair? result) (not (null? result)))
         (let ((visible (filter choice-visible? result)))
           (newline)
           (display-choices visible)
           (let ((chosen (read-choice visible)))
             ((hash-ref chosen 'action))
             (game-loop))))
        ;; No choices, no prompt — game over or error
        (else nil)))))

(define (start-game room-name)
  "Start the game at the given room."
  (goto room-name)
  (game-loop))
