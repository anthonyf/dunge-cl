(in-package #:dunge)

(make-room 'inventory-view "Inventory"
  (lambda (ctx)
    (let ((items (char-inventory *player*)))
      (if items
          (dolist (i items)
            (out ctx (format nil "  - ~a~%" (item-display-name i))))
          (out ctx (format nil "  (empty)~%"))))
    nil)
  (return-choice "Back"))
