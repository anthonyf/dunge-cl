(defsystem "dunge"
  :version "0.1.0"
  :author ""
  :license ""
  :description ""
  :depends-on ()
  :serial t
  :components ((:module "src"
		:components
		((:file "generics")
		 (:module "capi"
		  :components ((:file "wrapping-layout")
			       (:file "interface")))
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
