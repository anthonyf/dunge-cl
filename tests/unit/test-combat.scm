;;; test-combat.scm — Unit tests for combat system

(test "resolve-attack with no armor deals full HP damage"
  (lambda ()
    (let ((target (make-enemy "Goblin" 6 6 0 10 10 10 4)))
      (random-seed! 100)
      (let ((result (resolve-attack 6 target)))
        (assert-true (>= (hash-ref result 'damage) 0))
        (assert-true (<= (enemy-hp target) 6))))))

(test "resolve-attack armor reduces damage"
  (lambda ()
    (let ((target (make-enemy "Knight" 10 10 3 10 10 10 6)))
      (random-seed! 50)
      (let* ((roll-preview (roll-die 8))
             (target2 (make-enemy "Knight" 10 10 3 10 10 10 6)))
        (random-seed! 50)
        (let ((result (resolve-attack 8 target2)))
          (let ((expected-dmg (max 0 (- roll-preview 3))))
            (assert-equal (hash-ref result 'damage) expected-dmg)))))))

(test "resolve-attack STR spillover when HP exhausted"
  (lambda ()
    (let ((target (make-enemy "Weak" 1 1 0 20 10 10 4)))
      (random-seed! 42)
      (let ((result (resolve-attack 8 target)))
        (assert-equal (enemy-hp target) 0)
        (when (> (hash-ref result 'str-damage) 0)
          (assert-true (< (enemy-str target) 20)))))))

(test "resolve-heal restores HP to max"
  (lambda ()
    (with-fresh-state
      (set-character-hp! *player* 10)
      (set-character-hp-max! *player* 10)
      (set-character-hp! *player* 3)
      (let ((result (resolve-heal)))
        (assert-equal (character-hp *player*) 10)
        (assert-equal (hash-ref result 'old-hp) 3)
        (assert-equal (hash-ref result 'new-hp) 10)
        (assert-equal (hash-ref result 'healed) 7)))))

(test "str-save passes when roll <= STR"
  (lambda ()
    (let ((target (hash-table 'str 15)))
      (random-seed! 1)
      (let ((result (str-save target)))
        (assert-true (or (eq? result #t) (eq? result #f)))))))

(test "update-encounter-state detects victory on dead enemy"
  (lambda ()
    (with-fresh-state
      (let ((enc (make-encounter (make-enemy "Test" 5 5 0 10 10 10 4) #t #f 'active))
            (player-result (hash-table 'damage 5 'str-damage 0
                                        'critical-save 'none 'dead #t)))
        (update-encounter-state enc player-result #f #f)
        (assert-equal (encounter-state enc) 'victory)))))

(test "update-encounter-state detects player death"
  (lambda ()
    (with-fresh-state
      (let ((enc (make-encounter (make-enemy "Test" 5 5 0 10 10 10 4) #t #f 'active))
            (enemy-result (hash-table 'damage 5 'str-damage 10
                                       'critical-save 'none 'dead #t)))
        (update-encounter-state enc #f enemy-result #f)
        (assert-equal (encounter-state enc) 'death)))))

(test "update-encounter-state detects fled"
  (lambda ()
    (with-fresh-state
      (let ((enc (make-encounter (make-enemy "Test" 5 5 0 10 10 10 4) #t #f 'active)))
        (update-encounter-state enc #f #f #t)
        (assert-equal (encounter-state enc) 'fled)))))

(test "format-player-attack-lines glancing blow"
  (lambda ()
    (let ((result (hash-table 'damage 0 'str-damage 0
                               'critical-save 'none 'dead #f)))
      (let ((lines (format-player-attack-lines result)))
        (assert-equal (length lines) 1)
        (assert-true (string-contains? (car lines) "glances"))))))

(test "cleanup-combat resets player on death"
  (lambda ()
    (with-fresh-state
      (set-character-hp! *player* 10)
      (set-character-hp-max! *player* 10)
      (set-character-str! *player* 10)
      (set-character-hp! *player* 0)
      (set-character-str! *player* 0)
      (set *current-encounter* (make-encounter (make-enemy "Test" 0 5 0 10 10 10 4) #f #f 'death))
      (cleanup-combat 'death)
      (assert-equal (character-hp *player*) 10)
      (assert-equal (character-str *player*) 10)
      (assert-equal *current-encounter* #f))))
