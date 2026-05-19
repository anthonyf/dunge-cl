(require 'asdf)

(asdf:defsystem "dunge"
  :depends-on ()
  :serial t
  :description "A dungeon generation system"
  :components ((:module "src"
		:components ((:file "package")
			     (:file "main")))))

