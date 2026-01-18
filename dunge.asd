(require :asdf)

(in-package :asdf-user)


(initialize-source-registry
 '(:source-registry
   (:tree (:here))
   :inherit-configuration))

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
		((:file "dice")
		 (:file "text-layout")
		 (:file "character")
		 (:file "engine")
		 (:file "character-builder")
		 (:file "main"))))
  :in-order-to ((test-op (test-op "dunge/tests"))))

(defsystem "dunge/tests"
  :author ""
  :license ""
  :depends-on ("rove")
  :description "Test system for dunge"
  :components ((:module "tests"
		:components ((:file "main"))))
  :perform (test-op (op c) (symbol-call :rove :run c)))
