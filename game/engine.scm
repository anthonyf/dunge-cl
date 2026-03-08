;;; engine.scm — Dunge IF engine
;;; Rooms are plain functions that call each other directly.

;;;
;;; Player Record
;;;

(define-record character
  name background str dex wil hp hp-max armor gold fate inventory)

(define *player* nil)

(define (init-player!)
  "Initialize *player* with a blank character record."
  (set *player* (make-character nil nil nil nil nil nil nil nil nil nil '())))

;;;
;;; Display Helpers
;;;

(define (text . args)
  "Display formatted text followed by a newline."
  (display (apply fmt args))
  (newline))

(define (p . args)
  "Display formatted text followed by a blank line (paragraph break)."
  (display (apply fmt args))
  (newline)
  (newline))

(define (non-empty-string? s)
  (and (string? s) (> (string-length s) 0)))

;;;
;;; Choice System
;;;

(define (make-choice label action . rest)
  "Create a choice. Optional guard function as third argument."
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
;;; choose macro: static menu for rooms
;;;

(define-macro (choose . options)
  "Display a numbered menu and execute the selected option's action.
   Each option is (label-expr action-expr)."
  `(begin
     (newline)
     (let ((choices (list ,@(map (lambda (opt)
                                   `(make-choice ,(car opt) (lambda () ,(cadr opt))))
                                 options))))
       (display-choices choices)
       (let ((chosen (read-choice choices)))
         ((hash-ref chosen 'action))))))

;;;
;;; ask: text prompt with validation
;;;

(define (ask question validate-fn action-fn)
  "Display a prompt, read input, validate, retry or call action."
  (display question)
  (display " > ")
  (let ((input (read-line)))
    (if (validate-fn input)
        (action-fn input)
        (begin
          (display "Invalid input. Try again.")
          (newline)
          (ask question validate-fn action-fn)))))
