;;; test-navigation.scm — Integration tests for room navigation

(define (skip-to-town!)
  "Run through character creation to reach town-square."
  (test-step nil)                        ;; Welcome
  (test-step "1")                        ;; Continue
  (test-step "Navigator")                ;; Name
  (test-step "1")                        ;; Continue
  (test-step "1")                        ;; Soldier
  (test-step "4")                        ;; Keep stats
  (test-step "1")                        ;; Continue (HP)
  (test-step "1")                        ;; Continue (Equipment)
  (test-step "1")                        ;; Continue (Fate)
  (test-step "1"))                       ;; Continue (Summary -> town)

(define-test "navigation: town square displays correctly"
  (with-fresh-state
    (random-seed! 42)
    (let ((out (skip-to-town!)))
      (assert (string-contains? out "Town Square") "should show Town Square")
      (assert (string-contains? out "Adventure Board") "should show Adventure Board"))))

(define-test "navigation: town to adventure board and back"
  (with-fresh-state
    (random-seed! 42)
    (skip-to-town!)
    (let ((out (test-step "1")))
      (assert (string-contains? out "Adventure Board") "should show Adventure Board"))
    (let ((out (test-step "2")))
      (assert (string-contains? out "Town Square") "should show Town Square"))))

(define-test "navigation: town to blacksmith and back"
  (with-fresh-state
    (random-seed! 42)
    (skip-to-town!)
    (let ((out (test-step "2")))
      (assert (string-contains? out "Blacksmith") "should show Blacksmith"))
    (let ((out (test-step "1")))
      (assert (string-contains? out "Town Square") "should show Town Square"))))
