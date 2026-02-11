(require :asdf)

(in-package :asdf-user)

(defsystem "dunge"
  :version "0.1.0"
  :author ""
  :license ""
  :description ""
  :depends-on ("uiop"
	       "alexandria")
  :serial t
  :components ((:module "src"
		:components
		((:file "utils")
		 (:file "data-store")
		 (:file "dice")
		 (:file "text-layout")
		 (:file "engine")
		 (:file "room")
		 (:file "item")
		 (:file "character-creation")
		 (:file "main"))))
  :in-order-to ((test-op (test-op "dunge/tests"))))

(defsystem "dunge/tests"
  :author ""
  :license ""
  :depends-on ("dunge" "rove")
  :description "Test system for dunge"
  :components ((:module "tests"
		:components ((:file "main")
			     (:file "data-store")
			     (:file "item"))))
  :perform (test-op (op c) (symbol-call :rove :run c)))
