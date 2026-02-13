(uiop:define-package #:dunge/serialize
  (:use #:cl)
  (:export #:serialize
	   #:deserialize))

(in-package #:dunge/serialize)

(defgeneric serialize (object)
  (:documentation "Serialize OBJECT to a type-tagged plist."))

(defgeneric deserialize (type plist)
  (:documentation "Reconstruct an object from TYPE keyword and PLIST data."))
