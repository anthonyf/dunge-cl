;;; test-dice.scm — Unit tests for dice rolling

(define-test "roll-die returns value in range 1-6"
  (random-seed! 100)
  (let loop ((i 0))
    (when (< i 20)
      (let ((result (roll-die 6)))
        (assert (>= result 1) "roll-die result < 1")
        (assert (<= result 6) "roll-die result > 6"))
      (loop (+ i 1)))))

(define-test "roll-die is deterministic with seed"
  (random-seed! 42)
  (let ((a (roll-die 6)))
    (random-seed! 42)
    (let ((b (roll-die 6)))
      (assert (equal? a b) "same seed should produce same roll"))))

(define-test "roll-dice returns correct count"
  (random-seed! 99)
  (let ((results (roll-dice 3 6)))
    (assert (equal? 3 (length results)) "roll-dice should return 3 results")))

(define-test "roll-dice values all in range"
  (random-seed! 77)
  (let ((results (roll-dice 5 8)))
    (for-each (lambda (r)
                (assert (>= r 1) "roll-dice value < 1")
                (assert (<= r 8) "roll-dice value > 8"))
              results)))

(define-test "roll-d20 returns value in range 1-20"
  (random-seed! 55)
  (let loop ((i 0))
    (when (< i 20)
      (let ((result (roll-d20)))
        (assert (>= result 1) "roll-d20 result < 1")
        (assert (<= result 20) "roll-d20 result > 20"))
      (loop (+ i 1)))))
