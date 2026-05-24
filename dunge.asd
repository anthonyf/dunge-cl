(require 'asdf)

(asdf:defsystem "dunge"
  :depends-on (:trivia
               :parenscript
               :cl-who)
  :serial t
  :description "A dungeon generation system"
  :components ((:module "src"
                :components ((:file "package")
                             (:file "html-package")
                             (:file "source")
                             (:file "model")
                             (:file "runtime")
                             (:file "html")))))

(asdf:defsystem "dunge/examples"
  :depends-on ("dunge")
  :serial t
  :description "Examples for Dunge"
  :components ((:module "examples"
                :components ((:file "package")
                             (:static-file "basic.dunge")
                             (:module "basic-rooms"
                              :pathname "basic"
                              :components ((:static-file "entrance.dunge")
                                           (:static-file "hallway.dunge")))
                             (:file "basic")
                             (:static-file "control-panel.dunge")
                             (:module "control-panel-rooms"
                              :pathname "control-panel"
                              :components ((:static-file "hallway.dunge")
                                           (:static-file "hidden-room.dunge")))
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
