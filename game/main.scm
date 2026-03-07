;;; main.scm — Dunge game bootstrap
;;; Load with: (ece:evaluate '(load "game/main.scm"))

(load "game/engine.scm")
(load "game/dice.scm")
(load "game/items.scm")
(load "game/combat.scm")
(load "game/bestiary.scm")
(load "game/content.scm")

(init-player!)
(start-game 'start)
