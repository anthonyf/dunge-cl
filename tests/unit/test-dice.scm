;;; test-dice.scm — Unit tests for dice rolling

(test "roll-die returns value in range 1-6"
  (lambda ()
    (random-seed! 100)
    (let loop ((i 0))
      (when (< i 20)
        (let ((result (roll-die 6)))
          (assert-true (>= result 1))
          (assert-true (<= result 6)))
        (loop (+ i 1))))))

(test "roll-die is deterministic with seed"
  (lambda ()
    (random-seed! 42)
    (let ((a (roll-die 6)))
      (random-seed! 42)
      (let ((b (roll-die 6)))
        (assert-equal a b)))))

(test "roll-dice returns correct count"
  (lambda ()
    (random-seed! 99)
    (let ((results (roll-dice 3 6)))
      (assert-equal (length results) 3))))

(test "roll-dice values all in range"
  (lambda ()
    (random-seed! 77)
    (let ((results (roll-dice 5 8)))
      (for-each (lambda (r)
                  (assert-true (>= r 1))
                  (assert-true (<= r 8)))
                results))))

(test "roll-d20 returns value in range 1-20"
  (lambda ()
    (random-seed! 55)
    (let loop ((i 0))
      (when (< i 20)
        (let ((result (roll-d20)))
          (assert-true (>= result 1))
          (assert-true (<= result 20)))
        (loop (+ i 1))))))
