(in-package #:dunge)

(make-room 'character-sheet "Character"
  (lambda (ctx)
    (print-character-sheet ctx)
    nil)
  (return-choice "Back"))
