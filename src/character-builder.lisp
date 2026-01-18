(uiop:define-package #:dunge/character-builder
  (:use #:cl)
  (:shadow #:character)
  (:mix #:dunge/character
	#:dunge/text-layout
	#:dunge/engine))

(in-package #:dunge/character-builder)
