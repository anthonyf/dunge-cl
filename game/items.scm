;;; items.scm — Item system for Dunge
;;; Defines item records, display formatting, combat usage, and consumption.

;;;
;;; Item Records
;;;

(define-record item name)
(define-record weapon name damage-die)
(define-record stackable-item name quantity stack-limit)
(define-record healing-herb quantity stack-limit)

;;;
;;; Display Names
;;;

(define (item-display-name i)
  "Return a human-readable display string for an item."
  (cond
    ((weapon? i)
     (fmt (weapon-name i) " (d" (weapon-damage-die i) ")"))
    ((healing-herb? i)
     (if (> (healing-herb-quantity i) 1)
         (fmt "Healing Herbs x" (healing-herb-quantity i))
         "Healing Herbs"))
    ((stackable-item? i)
     (if (> (stackable-item-quantity i) 1)
         (fmt (stackable-item-name i) " x" (stackable-item-quantity i))
         (stackable-item-name i)))
    ((item? i)
     (item-name i))
    (else "???")))

;;;
;;; Combat Usage
;;;

(define (usable? i)
  "Can this item be used in combat?"
  (or (weapon? i) (healing-herb? i)))

(define (item-use-label i)
  "Choice text for using this item in combat."
  (cond
    ((weapon? i)
     (fmt "Attack with " (item-display-name i)))
    ((healing-herb? i)
     (fmt "Use " (item-display-name i)))
    (else #f)))

;;;
;;; Consumption
;;;

(define (consume-item i inventory)
  "Consume one of item from inventory. Decrements stackable quantity,
   removes from inventory when exhausted. Returns the new inventory list."
  (cond
    ((healing-herb? i)
     (set-healing-herb-quantity! i (- (healing-herb-quantity i) 1))
     (if (<= (healing-herb-quantity i) 0)
         (filter (lambda (x) (not (eq? x i))) inventory)
         inventory))
    ((stackable-item? i)
     (set-stackable-item-quantity! i (- (stackable-item-quantity i) 1))
     (if (<= (stackable-item-quantity i) 0)
         (filter (lambda (x) (not (eq? x i))) inventory)
         inventory))
    (else
     (filter (lambda (x) (not (eq? x i))) inventory))))
