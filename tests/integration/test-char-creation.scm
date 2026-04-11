;;; test-char-creation.scm — Integration tests for character creation flow

(test "character creation: start screen"
  (lambda ()
    (with-fresh-state
      (random-seed! 42)
      (let ((out (test-step #f)))
        (assert-true (string-contains? out "Welcome"))))))

(test "character creation: name prompt"
  (lambda ()
    (with-fresh-state
      (random-seed! 42)
      (test-step #f)
      (let ((out (test-step "1")))
        (assert-true (string-contains? out "name"))))))

(test "character creation: enter name"
  (lambda ()
    (with-fresh-state
      (random-seed! 42)
      (test-step #f)
      (test-step "1")
      (let ((out (test-step "TestHero")))
        (assert-true (string-contains? out "TestHero"))
        (assert-equal (character-name *player*) "TestHero")))))

(test "character creation: choose background"
  (lambda ()
    (with-fresh-state
      (random-seed! 42)
      (test-step #f)
      (test-step "1")
      (test-step "TestHero")
      (test-step "1")
      (let ((out (test-step "1")))
        (assert-equal (character-background *player*) "Soldier")))))

(test "character creation: stats are rolled"
  (lambda ()
    (with-fresh-state
      (random-seed! 42)
      (test-step #f)
      (test-step "1")
      (test-step "TestHero")
      (test-step "1")
      (test-step "1")
      (let ((out (test-step "4")))
        (assert-true (number? (character-str *player*)))
        (assert-true (number? (character-dex *player*)))
        (assert-true (number? (character-wil *player*)))))))

(test "character creation: full flow to summary"
  (lambda ()
    (with-fresh-state
      (random-seed! 42)
      (test-step #f)
      (test-step "1")
      (test-step "TestHero")
      (test-step "1")
      (test-step "1")
      (test-step "4")
      (test-step "1")
      (test-step "1")
      (test-step "1")
      (let ((out (test-step "1")))
        (assert-true (string-contains? out "Town Square"))))))
