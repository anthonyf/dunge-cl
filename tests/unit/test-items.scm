;;; test-items.scm — Unit tests for item system

(define-test "make-item creates basic item"
  (let ((i (make-item "Shield")))
    (assert (item? i) "should be an item")
    (assert (equal? "Shield" (item-name i)) "name should be Shield")))

(define-test "make-weapon creates weapon with damage die"
  (let ((w (make-weapon "Sword" 8)))
    (assert (weapon? w) "should be a weapon")
    (assert (equal? "Sword" (weapon-name w)) "name should be Sword")
    (assert (equal? 8 (weapon-damage-die w)) "damage die should be 8")))

(define-test "item-display-name for basic item"
  (let ((i (make-item "Rope")))
    (assert (equal? "Rope" (item-display-name i)) "display name should be Rope")))

(define-test "item-display-name for weapon"
  (let ((w (make-weapon "Bow" 6)))
    (assert (equal? "Bow (d6)" (item-display-name w)) "display name should be Bow (d6)")))

(define-test "item-display-name for stackable item quantity 1"
  (let ((s (make-stackable-item "Rations" 1 10)))
    (assert (equal? "Rations" (item-display-name s)) "quantity 1 should show just name")))

(define-test "item-display-name for stackable item quantity > 1"
  (let ((s (make-stackable-item "Rations" 3 10)))
    (assert (equal? "Rations x3" (item-display-name s)) "quantity 3 should show xN")))

(define-test "item-display-name for healing herb quantity 1"
  (let ((h (make-healing-herb 1 10)))
    (assert (equal? "Healing Herbs" (item-display-name h)) "quantity 1 herbs")))

(define-test "item-display-name for healing herb quantity > 1"
  (let ((h (make-healing-herb 3 10)))
    (assert (equal? "Healing Herbs x3" (item-display-name h)) "quantity 3 herbs")))

(define-test "consume-item decrements stackable quantity"
  (let* ((s (make-stackable-item "Torch" 3 5))
         (inv (list s))
         (new-inv (consume-item s inv)))
    (assert (equal? 2 (stackable-item-quantity s)) "quantity should be 2")
    (assert (equal? 1 (length new-inv)) "inventory should have 1 item")))

(define-test "consume-item removes stackable at zero"
  (let* ((s (make-stackable-item "Torch" 1 5))
         (inv (list s))
         (new-inv (consume-item s inv)))
    (assert (equal? 0 (length new-inv)) "inventory should be empty")))

(define-test "consume-item removes basic item"
  (let* ((i (make-item "Key"))
         (inv (list i))
         (new-inv (consume-item i inv)))
    (assert (equal? 0 (length new-inv)) "inventory should be empty")))

(define-test "usable? returns true for weapons and herbs"
  (assert (usable? (make-weapon "Sword" 8)) "weapon should be usable")
  (assert (usable? (make-healing-herb 1 10)) "herb should be usable")
  (assert (not (usable? (make-item "Rope"))) "rope should not be usable"))
