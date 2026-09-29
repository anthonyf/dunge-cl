(uiop:define-package #:dunge-pages
  (:use #:cl)
  (:export
   #:build-site))

(in-package #:dunge-pages)

;;; Builds the GitHub Pages site. The game pages are build output: CI builds
;;; the site on every push, checks that the build is reproducible (see
;;; site/check.sh), and deploys it. None of the generated HTML is committed.

(defparameter *landing-page*
  (asdf:system-relative-pathname "dunge/pages" "site/index.html"))

(defparameter *styles-title* "The Mysterious Affair at Styles")

(defun site-file (root relative-path)
  (let ((pathname (merge-pathnames relative-path root)))
    (ensure-directories-exist pathname)
    pathname))

(defun build-site (directory)
  "Write the GitHub Pages site into DIRECTORY and return its pathname."
  (let ((root (uiop:merge-pathnames* (uiop:ensure-directory-pathname directory)
                                     (uiop:getcwd))))
    (uiop:copy-file *landing-page* (site-file root "index.html"))
    (dunge-html:write-index-html (dunge-styles:load-styles-game)
                                 (site-file root "styles/index.html")
                                 :title *styles-title*)
    (dunge-examples:write-adaptation-browser-demo
     :pathname (site-file root "examples/adaptation/index.html"))
    ;; Serve files as-is rather than through Jekyll.
    (with-open-file (stream (site-file root ".nojekyll")
                            :direction :output
                            :if-exists :supersede)
      (declare (ignorable stream)))
    root))
