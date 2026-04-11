;;; test-navigation.scm — Integration tests for room navigation

(define (skip-to-town!)
  "Run through character creation to reach town-square."
  (test-step #f)                         ;; Welcome
  (test-step "1")                        ;; Continue
  (test-step "Navigator")                ;; Name
  (test-step "1")                        ;; Continue
  (test-step "1")                        ;; Soldier
  (test-step "4")                        ;; Keep stats
  (test-step "1")                        ;; Continue (HP)
  (test-step "1")                        ;; Continue (Equipment)
  (test-step "1")                        ;; Continue (Fate)
  (test-step "1"))                       ;; Continue (Summary -> town)

(test "navigation: town square displays correctly"
  (lambda ()
    (with-fresh-state
      (random-seed! 42)
      (let ((out (skip-to-town!)))
        (assert-true (string-contains? out "Town Square"))
        (assert-true (string-contains? out "Adventure Board"))))))

(test "navigation: town to adventure board and back"
  (lambda ()
    (with-fresh-state
      (random-seed! 42)
      (skip-to-town!)
      (let ((out (test-step "1")))
        (assert-true (string-contains? out "Adventure Board")))
      (let ((out (test-step "2")))
        (assert-true (string-contains? out "Town Square"))))))

(test "navigation: town to blacksmith and back"
  (lambda ()
    (with-fresh-state
      (random-seed! 42)
      (skip-to-town!)
      (let ((out (test-step "2")))
        (assert-true (string-contains? out "Blacksmith")))
      (let ((out (test-step "1")))
        (assert-true (string-contains? out "Town Square"))))))
