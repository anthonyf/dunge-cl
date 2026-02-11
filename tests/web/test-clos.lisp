;;; test-clos.lisp — CLOS accessor round-trip tests for JSCL
;;;
;;; Exercises the setf paths that required workarounds in JSCL.

(in-package #:dunge/web-tests)

;;; --- player-character ---

(define-web-test test-char-str-setf
  (let ((pc (make-instance 'dunge/character:player-character)))
    (setf (dunge/character:char-str pc) 14)
    (web-assert (= (dunge/character:char-str pc) 14)
                "char-str round-trip failed")))

(define-web-test test-char-dex-setf
  (let ((pc (make-instance 'dunge/character:player-character)))
    (setf (dunge/character:char-dex pc) 10)
    (web-assert (= (dunge/character:char-dex pc) 10)
                "char-dex round-trip failed")))

(define-web-test test-char-wil-setf
  (let ((pc (make-instance 'dunge/character:player-character)))
    (setf (dunge/character:char-wil pc) 8)
    (web-assert (= (dunge/character:char-wil pc) 8)
                "char-wil round-trip failed")))

(define-web-test test-char-gold-setf
  (let ((pc (make-instance 'dunge/character:player-character)))
    (setf (dunge/character:char-gold pc) 50)
    (web-assert (= (dunge/character:char-gold pc) 50)
                "char-gold round-trip failed")))

(define-web-test test-char-fate-setf
  (let ((pc (make-instance 'dunge/character:player-character)))
    (setf (dunge/character:char-fate pc) 3)
    (web-assert (= (dunge/character:char-fate pc) 3)
                "char-fate round-trip failed")))

(define-web-test test-char-name-setf
  (let ((pc (make-instance 'dunge/character:player-character)))
    (setf (dunge/character:char-name pc) "Hero")
    (web-assert (string= (dunge/character:char-name pc) "Hero")
                "char-name round-trip failed")))

(define-web-test test-char-background-setf
  (let ((pc (make-instance 'dunge/character:player-character)))
    (setf (dunge/character:char-background pc) "Knight")
    (web-assert (string= (dunge/character:char-background pc) "Knight")
                "char-background round-trip failed")))

(define-web-test test-char-inventory-setf
  (let ((pc (make-instance 'dunge/character:player-character)))
    (setf (dunge/character:char-inventory pc) '("sword" "shield"))
    (web-assert (equal (dunge/character:char-inventory pc) '("sword" "shield"))
                "char-inventory round-trip failed")))

(define-web-test test-combatant-hp-setf
  (let ((pc (make-instance 'dunge/character:player-character)))
    (setf (dunge/character:combatant-hp pc) 20)
    (web-assert (= (dunge/character:combatant-hp pc) 20)
                "combatant-hp round-trip failed")))

(define-web-test test-combatant-hp-max-setf
  (let ((pc (make-instance 'dunge/character:player-character)))
    (setf (dunge/character:combatant-hp-max pc) 20)
    (web-assert (= (dunge/character:combatant-hp-max pc) 20)
                "combatant-hp-max round-trip failed")))

(define-web-test test-combatant-armor-setf
  (let ((pc (make-instance 'dunge/character:player-character)))
    (setf (dunge/character:combatant-armor pc) 2)
    (web-assert (= (dunge/character:combatant-armor pc) 2)
                "combatant-armor round-trip failed")))

;;; --- enemy ---

(define-web-test test-enemy-hp-setf
  (let ((e (make-instance 'dunge/combat:enemy
                          :name "Goblin" :hp 5 :hp-max 5
                          :armor 0 :attack-die "d4")))
    (setf (dunge/character:combatant-hp e) 3)
    (web-assert (= (dunge/character:combatant-hp e) 3)
                "enemy combatant-hp round-trip failed")))

;;; --- encounter ---

(define-web-test test-encounter-active-p-setf
  (let ((enc (make-instance 'dunge/combat:encounter
                            :enemy nil :active-p t)))
    (setf (dunge/combat:encounter-active-p enc) nil)
    (web-assert (null (dunge/combat:encounter-active-p enc))
                "encounter-active-p round-trip failed")))

(define-web-test test-encounter-log-setf
  (let ((enc (make-instance 'dunge/combat:encounter
                            :enemy nil)))
    (setf (dunge/combat:encounter-log enc) '("hit" "miss"))
    (web-assert (equal (dunge/combat:encounter-log enc) '("hit" "miss"))
                "encounter-log round-trip failed")))
