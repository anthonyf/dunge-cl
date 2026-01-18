(uiop:define-package #:dunge/text-layout
  (:use #:cl)
  (:export #:column-layout
	   #:lines
	   #:columns))

(in-package :dunge/text-layout)


(defun columns-to-grid (column-strs)
  (apply #'mapcar (lambda (&rest line-strs)
                    line-strs)
         (mapcan (lambda (column-str)
                   (list (uiop:split-string column-str :separator (list #\newline))))
                 column-strs)))

#+nil
(columns-to-grid '("Name: Aragorn
Class: Fighter
Level: 1"
		 "Str: 16 (+3)
Int: 12 (+1)
Wis: 14 (+2)"
		 "Dex: 13 (+1)
Con: 15 (+2)
Cha: 10 (0"))

(defun col-widths (grid)
  "calculate column widths, which is longest string in the column"
  (reduce (lambda (acc cols)
	    (mapcar (lambda (a b)
		      (max (if (typep a 'string)
			       (length a)
			       a)
			 (length b)))
		    acc cols))
	  grid))

#+nil
(col-widths '(("a" "b" "c")
	      ("a" "b" "cc")
	      ("aaa" "b" "c")))

(defun spaces (n)
  (make-string n :initial-element #\Space))


(defun column-layout (column-strs &key (padding 1))
  (let* ((grid (columns-to-grid column-strs))
	 (col-widths (col-widths grid)))
    (loop for row in grid
	  do (loop for col in row
		   for col-width in col-widths
		   do (format t "~a~a~a" col (spaces padding) (spaces (- col-width (length col)))))
	  do (terpri))))

#+nil
(multiple-value-list
 (column-layout '("Name: Aragorn
Class: Fighter
Level: 1"
		  "Str: 16 (+3)
Int: 12 (+1)
Wis: 14 (+2)"
		  "Dex: 13 (+1)
Con: 15 (+2)
Cha: 10 (0)")))

#+nil
(multiple-value-list
 (column-layout '("a
b
c"
		  "a
b
cc"
		  "aaa
b
c")))

(defmacro lines (&rest lines)
  ""
  `(with-output-to-string (out)
     ,@(loop for line in lines
	     collect `(format out "~a~%"
			      ,(cond ((typep line 'string)
				     line)
				    ((listp line)
				     `(apply #'format nil `(,,@line)))
				    (t (write-to-string line)))))))

(defmacro columns (&rest cols)
  `(column-layout (list ,@cols)))

#+nil
(lines "a" "b" ("~a" (length "bob")))
