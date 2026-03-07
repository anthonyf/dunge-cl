(require :asdf)

(in-package :asdf-user)

(defsystem "dunge"
    :version "0.1.0"
    :author ""
    :license "GPL-3.0"
    :description ""
    :depends-on ("ece")
    :serial t
    :components ((:module "src"
                          :components
                          ((:file "ece-bootstrap")))))
