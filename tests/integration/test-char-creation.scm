;;; test-char-creation.scm — Integration tests for character creation flow

(define-test "character creation: start screen"
  (with-fresh-state
    (random-seed! 42)
    (let ((out (test-step nil)))
      (assert (string-contains? out "Welcome") "should show Welcome"))))

(define-test "character creation: name prompt"
  (with-fresh-state
    (random-seed! 42)
    (test-step nil)
    (let ((out (test-step "1")))
      (assert (string-contains? out "name") "should ask for name"))))

(define-test "character creation: enter name"
  (with-fresh-state
    (random-seed! 42)
    (test-step nil)
    (test-step "1")
    (let ((out (test-step "TestHero")))
      (assert (string-contains? out "TestHero") "should show entered name")
      (assert (equal? "TestHero" (character-name *player*))
              "player name should be TestHero"))))

(define-test "character creation: choose background"
  (with-fresh-state
    (random-seed! 42)
    (test-step nil)
    (test-step "1")
    (test-step "TestHero")
    (test-step "1")
    (let ((out (test-step "1")))
      (assert (equal? "Soldier" (character-background *player*))
              "background should be Soldier"))))

(define-test "character creation: stats are rolled"
  (with-fresh-state
    (random-seed! 42)
    (test-step nil)
    (test-step "1")
    (test-step "TestHero")
    (test-step "1")
    (test-step "1")
    (let ((out (test-step "4")))
      (assert (number? (character-str *player*)) "STR should be a number")
      (assert (number? (character-dex *player*)) "DEX should be a number")
      (assert (number? (character-wil *player*)) "WIL should be a number"))))

(define-test "character creation: full flow to summary"
  (with-fresh-state
    (random-seed! 42)
    (test-step nil)
    (test-step "1")
    (test-step "TestHero")
    (test-step "1")
    (test-step "1")
    (test-step "4")
    (test-step "1")
    (test-step "1")
    (test-step "1")
    (let ((out (test-step "1")))
      (assert (string-contains? out "Town Square") "output should mention town"))))
