(in-package #:dunge-styles)

(defun styles-game-path ()
  (asdf:system-relative-pathname "dunge-styles" "styles/game.dunge"))

(defun load-styles-game ()
  (load-dunge-file (styles-game-path)))

(defun play-styles ()
  (let ((dunge:*pause-after-say* t))
    (evaluate (load-styles-game))))
