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
                             (:file "control-panel")
                             (:static-file "adaptation.dunge")
                             (:module "adaptation-rooms"
                              :pathname "adaptation"
                              :components ((:static-file "camp.dunge")
                                           (:static-file "threshold.dunge")
                                           (:static-file "placeholder-room.dunge")
                                           (:static-file "README.md")
                                           (:static-file "PROVENANCE.md")))
                             (:file "adaptation")))))

(asdf:defsystem "dunge/pages"
  :depends-on ("dunge"
               "dunge/examples"
               "dunge-styles")
  :serial t
  :description "Builds the GitHub Pages site for Dunge"
  :components ((:module "site"
                :components ((:static-file "index.html")
                             (:static-file "check.sh")
                             (:file "build")))))

(asdf:defsystem "dunge/parity"
  :depends-on ("dunge"
               :fiveam)
  :serial t
  :description "Console/browser runtime parity harness for Dunge tests"
  :components ((:module "parity"
                :pathname "tests/parity"
                :components ((:static-file "harness.js")
                             (:file "support")))))

(asdf:defsystem "dunge/tests"
  :depends-on ("dunge/examples"
               "dunge/parity"
               :fiveam)
  :serial t
  :description "Tests for Dunge"
  :components ((:module "tests"
                :components ((:file "package")
                             (:file "core")
                             (:file "expressions")
                             (:file "runtime-parity"))))
  :perform (test-op (op c)
             ;; FiveAM's RUN! only returns NIL on failure; signal so that
             ;; `sbcl --non-interactive` (and CI) exits non-zero.
             (unless (uiop:symbol-call :fiveam :run! :dunge-tests)
               (error "Dunge tests failed."))))
