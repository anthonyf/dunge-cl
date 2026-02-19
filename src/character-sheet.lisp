(in-package #:dunge)

(make-room 'character-sheet "Character"
  (lambda (ctx)
    (out ctx (format nil "  Name:       ~a~%" (char-name *player*)))
    (out ctx (format nil "  Background: ~a~%" (char-background *player*)))
    (out ctx (format nil "~%"))
    (out ctx (format nil "  STR: ~a   DEX: ~a   WIL: ~a~%"
                     (combatant-str *player*)
                     (combatant-dex *player*)
                     (combatant-wil *player*)))
    (out ctx (format nil "~%"))
    (out ctx (format nil "  HP:    ~a/~a~%"
                     (combatant-hp *player*)
                     (combatant-hp-max *player*)))
    (out ctx (format nil "  Armor: ~a~%" (combatant-armor *player*)))
    (out ctx (format nil "  Gold:  ~a~%" (char-gold *player*)))
    (out ctx (format nil "  Fate:  ~a~%" (char-fate *player*)))
    nil)
  (return-choice "Back"))

(push (gosub-choice "Character" (room 'character-sheet)) *overflow-choices*)
