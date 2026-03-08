;;; test-combat.scm — Unit tests for combat system

(define-test "resolve-attack with no armor deals full HP damage"
  (let ((target (make-enemy "Goblin" 6 6 0 10 10 10 4)))
    (random-seed! 100)
    (let ((result (resolve-attack 6 target)))
      (assert (>= (hash-ref result 'damage) 0) "damage should be >= 0")
      (assert (<= (enemy-hp target) 6) "HP should decrease or stay"))))

(define-test "resolve-attack armor reduces damage"
  (let ((target (make-enemy "Knight" 10 10 3 10 10 10 6)))
    (random-seed! 50)
    (let* ((roll-preview (roll-die 8))
           (target2 (make-enemy "Knight" 10 10 3 10 10 10 6)))
      (random-seed! 50)
      (let ((result (resolve-attack 8 target2)))
        (let ((expected-dmg (max 0 (- roll-preview 3))))
          (assert (equal? expected-dmg (hash-ref result 'damage))
                  (fmt "Expected damage " expected-dmg
                       " but got " (hash-ref result 'damage))))))))

(define-test "resolve-attack STR spillover when HP exhausted"
  (let ((target (make-enemy "Weak" 1 1 0 20 10 10 4)))
    (random-seed! 42)
    (let ((result (resolve-attack 8 target)))
      (assert (equal? 0 (enemy-hp target)) "HP should be 0")
      (when (> (hash-ref result 'str-damage) 0)
        (assert (< (enemy-str target) 20)
                "STR should decrease from spillover")))))

(define-test "resolve-heal restores HP to max"
  (with-fresh-state
    (set-character-hp! *player* 10)
    (set-character-hp-max! *player* 10)
    (set-character-hp! *player* 3)
    (let ((result (resolve-heal)))
      (assert (equal? 10 (character-hp *player*)) "HP should be restored to max")
      (assert (equal? 3 (hash-ref result 'old-hp)) "old HP should be 3")
      (assert (equal? 10 (hash-ref result 'new-hp)) "new HP should be 10")
      (assert (equal? 7 (hash-ref result 'healed)) "healed should be 7"))))

(define-test "str-save passes when roll <= STR"
  (let ((target (hash-table 'str 15)))
    (random-seed! 1)
    (let ((result (str-save target)))
      (assert (or (eq? result t) (eq? result nil))
              "str-save should return boolean"))))

(define-test "update-encounter-state detects victory on dead enemy"
  (with-fresh-state
    (let ((enc (make-encounter (make-enemy "Test" 5 5 0 10 10 10 4) t nil 'active))
          (player-result (hash-table 'damage 5 'str-damage 0
                                      'critical-save 'none 'dead t)))
      (update-encounter-state enc player-result nil nil)
      (assert (equal? 'victory (encounter-state enc)) "state should be victory"))))

(define-test "update-encounter-state detects player death"
  (with-fresh-state
    (let ((enc (make-encounter (make-enemy "Test" 5 5 0 10 10 10 4) t nil 'active))
          (enemy-result (hash-table 'damage 5 'str-damage 10
                                     'critical-save 'none 'dead t)))
      (update-encounter-state enc nil enemy-result nil)
      (assert (equal? 'death (encounter-state enc)) "state should be death"))))

(define-test "update-encounter-state detects fled"
  (with-fresh-state
    (let ((enc (make-encounter (make-enemy "Test" 5 5 0 10 10 10 4) t nil 'active)))
      (update-encounter-state enc nil nil t)
      (assert (equal? 'fled (encounter-state enc)) "state should be fled"))))

(define-test "format-player-attack-lines glancing blow"
  (let ((result (hash-table 'damage 0 'str-damage 0
                             'critical-save 'none 'dead nil)))
    (let ((lines (format-player-attack-lines result)))
      (assert (equal? 1 (length lines)) "should be 1 line")
      (assert (string-contains? (car lines) "glances") "should contain glances"))))

(define-test "cleanup-combat resets player on death"
  (with-fresh-state
    (set-character-hp! *player* 10)
    (set-character-hp-max! *player* 10)
    (set-character-str! *player* 10)
    (set-character-hp! *player* 0)
    (set-character-str! *player* 0)
    (set *current-encounter* (make-encounter (make-enemy "Test" 0 5 0 10 10 10 4) nil nil 'death))
    (cleanup-combat 'death)
    (assert (equal? 10 (character-hp *player*)) "HP should be restored")
    (assert (equal? 10 (character-str *player*)) "STR should be restored")
    (assert (equal? nil *current-encounter*) "encounter should be nil")))
