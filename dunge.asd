(require 'asdf)

(asdf:defsystem "dunge"
  :depends-on (:trivia)
  :serial t
  :description "A dungeon generation system"
  :components ((:module "src"
                :components ((:file "package")
                             (:file "source")
                             (:file "model")
                             (:file "runtime")))))

(asdf:defsystem "dunge/examples"
  :depends-on ("dunge")
  :serial t
  :description "Examples for Dunge"
  :components ((:module "examples"
                :components ((:file "package")
                             (:static-file "basic.dunge")
                             (:file "basic")
                             (:static-file "control-panel.dunge")
                             (:file "control-panel")))))

(asdf:defsystem "dunge/tests"
  :depends-on ("dunge/examples"
               :fiveam)
  :serial t
  :description "Tests for Dunge"
  :components ((:module "tests"
                :components ((:file "package")
                             (:file "core"))))
  :perform (test-op (op c)
             (uiop:symbol-call :fiveam :run! :dunge-tests)))
