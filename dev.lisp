(ql:quickload :qlot)
(uiop:chdir #P"~/git/dunge")
(qlot:init (uiop:getcwd))

(asdf:initialize-source-registry
 `(:source-registry (:tree ,(uiop:getcwd))
   :ignore-inherited-configuration))

(asdf:load-system "dunge")
