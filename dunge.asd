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
