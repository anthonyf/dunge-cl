(require 'asdf)

(asdf:defsystem "dunge"
  :depends-on (:trivia
	       :alexandria)
  :serial t
  :description "A dungeon generation system"
  :components ((:module "src"
		:components ((:file "package")
			     (:file "model")
			     (:file "runtime")))))

(asdf:defsystem "dunge/examples"
  :depends-on ("dunge")
  :serial t
  :description "Examples for Dunge"
  :components ((:module "examples"
		:components ((:file "package")
			     (:file "basic")))))
