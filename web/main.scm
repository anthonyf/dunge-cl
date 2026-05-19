;;; main.scm — Dunge browser-dev entrypoint for ece-serve.
;;;
;;; Run from this directory with:
;;;   ../vendor/ece/bin/ece-serve main.scm --port 8080
;;;
;;; Or open this file in Emacs and run:
;;;   M-x geiser-ece-dev-jack-in
;;;
;;; The Makefile wraps that as:
;;;   make serve

(load "../game/engine.scm")
(load "../game/dice.scm")
(load "../game/items.scm")
(load "../game/combat.scm")
(load "../game/bestiary.scm")
(load "../game/content.scm")
(load "../browser-boot.scm")
