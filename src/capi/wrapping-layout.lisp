(uiop:define-package #:dunge/capi/wrapping-layout
  (:use #:cl)
  (:export #:wrapping-layout))

(in-package #:dunge/capi/wrapping-layout)

(defmethod element-descent ((self t))
  0)

(defmethod element-ascent ((self t))
  (capi:with-geometry self
    (- (or capi:%height% capi:%min-height%) (element-descent self))))


(defclass wrapping-layout (capi:x-y-adjustable-layout)
  ((x-gap :initform 3 :initarg :x-gap)
   (y-gap :initform 3 :initarg :y-gap)))

(defmethod capi:interpret-description ((layout wrapping-layout)
                                       description interface)
  (loop for item in description
	collect (capi:parse-layout-descriptor item interface layout)))

(defun position-to-split-line (self elements width)
  (with-slots (x-gap) self
    (loop for (element . remaining-elements) = elements then remaining-elements
          for position from 0
          for element-width  = (capi:with-geometry element
                              (or capi:%width% capi:%min-width%))
          for element-height = (capi:with-geometry element
                              (or capi:%height% capi:%min-height%))
          for old-end-width = 0 then end-width
          for element-descent = (element-descent element)
          for element-ascent =  (- element-height element-descent)
          for end-width = (+ element-width x-gap) then (+ end-width x-gap element-width)
          for max-descent = element-descent then (max max-descent element-descent)
          for max-ascent  = element-ascent  then (max max-ascent  element-ascent)
          when (and (not (eq position 0))
		    (> end-width width))
          return (values position max-ascent max-descent old-end-width)
          when (null remaining-elements)
          return (values (1+ position) max-ascent max-descent end-width))))

(defun generate-next-line (self elements x y width)
  (with-slots (x-gap) self
    (multiple-value-bind
          (position ascent descent total-width)
        (position-to-split-line self elements width)
      (let* ((height (+ ascent descent))
             (x-adjust (capi:layout-x-adjust self))
             (x-offset
               (case x-adjust
		 (:justified x)
		 (t
		  (+ (capi:pane-adjusted-offset self
						(capi:layout-x-adjust self)
						width total-width)
		     x))))
             (justified-x-gap
               (+ x-gap
                  (or (when (and (eq x-adjust :justified)
                                 (> position 1))
			(let ((extra
				(floor (- width total-width) (1- position))))
			  (when (< extra 10)
			    extra)))
                      0))))
        (loop for count below position
              for element in elements
              for element-width  = (capi:with-geometry element
                                     (or capi:%width% capi:%min-width%))
              for element-height = (capi:with-geometry element
                                     (or capi:%height% capi:%min-height%))
              for new-x = x-offset then (+ x-offset end-width)
              for end-width = (+ element-width justified-x-gap)
                then (+ end-width  justified-x-gap element-width)
              do
		 (capi:with-geometry element
	           (setf capi:%x% new-x
			 capi:%y% (case (capi:layout-y-adjust self)
                                    (:fonts
                                     (+ y height
					(- descent (element-ascent element))))
                                    (t
                                     (+ y (capi:pane-adjusted-offset
                                           self (capi:layout-y-adjust self)
                                           height element-height))))
			 capi:%width%  element-width
			 capi:%height% element-height)))
        (values (nthcdr position elements) height)))))

(defmethod capi:calculate-constraints ((self wrapping-layout))
    (let ((constrained-min-width 5))
      (capi:map-pane-children 
       self
       #'(lambda (element)
           (capi:with-geometry element
             (when capi:%min-width%
               (when (> capi:%min-width% constrained-min-width)
                 (setq constrained-min-width capi:%min-width%))))))
      (capi:with-geometry self
        (setq capi:%min-width% constrained-min-width
              capi:%min-height% nil
              capi:%max-width% nil
              capi:%max-height% nil))))

(defmethod capi:calculate-layout ((self wrapping-layout) x y width height)
  (declare (ignore height))
  (with-slots (y-gap) self
    (let (elements 
          (new-y y))
      (capi:map-pane-children self #'(lambda (child) (push child elements)))
      (setq elements (nreverse elements))
      (when elements
	(loop do
	  (multiple-value-bind
		(remaining-elements max-height)
	      (generate-next-line self elements x new-y width)
	    (setq elements remaining-elements)
	    (incf new-y (+ max-height y-gap)))
	      while elements)))))
