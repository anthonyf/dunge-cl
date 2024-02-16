(defsystem "dunge"
  :version "0.1.0"
  :author ""
  :license ""
  :depends-on (:parenscript
	       "trivia"
	       "alexandria"
	       "serapeum"
	       "uiop"
	       #:cl-who)
  :components ((:module "src"
                :components
                ((:file "package")
		 (:file "main"))))
  :description ""
  :in-order-to ((test-op (test-op "dunge/tests"))))

(defsystem "dunge/tests"
  :author ""
  :license ""
  :depends-on ("dunge"
               "rove")
  :components ((:module "tests"
                :components
                ((:file "main"))))
  :description "Test system for dunge"
  :perform (test-op (op c) (symbol-call :rove :run c)))
