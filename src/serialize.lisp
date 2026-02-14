(in-package #:dunge)

(defgeneric serialize (object)
  (:documentation "Serialize OBJECT to a type-tagged plist."))

;;; Deserialize uses hash-table dispatch rather than EQL-specialized methods
;;; because JSCL cannot handle EQL specializers across compilation units.

(defvar *deserializers* (make-hash-table :test 'eq))

(defmacro define-deserializer (type-key args &body body)
  "Register a deserializer for TYPE-KEY (a keyword).
Example: (define-deserializer :weapon (plist) (weapon (getf plist :name)))"
  `(setf (gethash ,type-key *deserializers*) (lambda ,args ,@body)))

(defun deserialize (type plist)
  "Reconstruct an object from TYPE keyword and PLIST data."
  (let ((fn (gethash type *deserializers*)))
    (unless fn
      (error "No deserializer registered for type ~S" type))
    (funcall fn plist)))
