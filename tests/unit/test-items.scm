;;; test-items.scm — Unit tests for item system

(test "make-item creates basic item"
  (lambda ()
    (let ((i (make-item "Shield")))
      (assert-true (item? i))
      (assert-equal (item-name i) "Shield"))))

(test "make-weapon creates weapon with damage die"
  (lambda ()
    (let ((w (make-weapon "Sword" 8)))
      (assert-true (weapon? w))
      (assert-equal (weapon-name w) "Sword")
      (assert-equal (weapon-damage-die w) 8))))

(test "item-display-name for basic item"
  (lambda ()
    (let ((i (make-item "Rope")))
      (assert-equal (item-display-name i) "Rope"))))

(test "item-display-name for weapon"
  (lambda ()
    (let ((w (make-weapon "Bow" 6)))
      (assert-equal (item-display-name w) "Bow (d6)"))))

(test "item-display-name for stackable item quantity 1"
  (lambda ()
    (let ((s (make-stackable-item "Rations" 1 10)))
      (assert-equal (item-display-name s) "Rations"))))

(test "item-display-name for stackable item quantity > 1"
  (lambda ()
    (let ((s (make-stackable-item "Rations" 3 10)))
      (assert-equal (item-display-name s) "Rations x3"))))

(test "item-display-name for healing herb quantity 1"
  (lambda ()
    (let ((h (make-healing-herb 1 10)))
      (assert-equal (item-display-name h) "Healing Herbs"))))

(test "item-display-name for healing herb quantity > 1"
  (lambda ()
    (let ((h (make-healing-herb 3 10)))
      (assert-equal (item-display-name h) "Healing Herbs x3"))))

(test "consume-item decrements stackable quantity"
  (lambda ()
    (let* ((s (make-stackable-item "Torch" 3 5))
           (inv (list s))
           (new-inv (consume-item s inv)))
      (assert-equal (stackable-item-quantity s) 2)
      (assert-equal (length new-inv) 1))))

(test "consume-item removes stackable at zero"
  (lambda ()
    (let* ((s (make-stackable-item "Torch" 1 5))
           (inv (list s))
           (new-inv (consume-item s inv)))
      (assert-equal (length new-inv) 0))))

(test "consume-item removes basic item"
  (lambda ()
    (let* ((i (make-item "Key"))
           (inv (list i))
           (new-inv (consume-item i inv)))
      (assert-equal (length new-inv) 0))))

(test "usable? returns true for weapons and herbs"
  (lambda ()
    (assert-true (usable? (make-weapon "Sword" 8)))
    (assert-true (usable? (make-healing-herb 1 10)))
    (assert-false (usable? (make-item "Rope")))))
