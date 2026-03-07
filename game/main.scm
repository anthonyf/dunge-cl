;;; main.scm — Dunge game bootstrap
;;; Load with: (ece:evaluate '(load "game/main.scm"))

(load "game/engine.scm")
(load "game/dice.scm")
(load "game/content.scm")

(start-game 'start)
