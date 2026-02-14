(require :asdf)

(in-package :asdf-user)

(defsystem "dunge"
  :version "0.1.0"
  :author ""
  :license "GPL-3.0"
  :description ""
  :depends-on ("alexandria")
  :serial t
  :components ((:module "src"
		:components
		((:file "packages")
		 (:file "utils")
		 (:file "data-store")
		 (:file "dice")
		 (:file "serialize")
		 (:file "text-layout")
		 (:file "engine")
		 (:file "room")
		 (:file "item")
		 (:file "character")
		 (:file "character-creation")
		 (:file "combat")
		 (:file "bestiary")
		 (:file "container")
		 (:file "main"))))
  :in-order-to ((test-op (test-op "dunge/tests"))))

(defsystem "dunge/tests"
  :author ""
  :license "GPL-3.0"
  :depends-on ("dunge" "rove")
  :description "Test system for dunge"
  :components ((:module "tests"
		:components ((:file "main")
			     (:file "data-store")
			     (:file "item"))))
  :perform (test-op (op c) (symbol-call :rove :run c)))
