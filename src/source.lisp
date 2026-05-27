(in-package #:dunge)

;;; Dunge source schema and loader

(defstruct dunge-source-field
  name
  kind
  target
  required-p
  default
  default-p)

(defstruct dunge-source-form
  tag
  builder
  fields)

(defstruct dunge-source-context
  source-name
  base-directory
  frames
  parent)

(defvar *dunge-source-forms* (make-hash-table :test 'eq))
(defvar *dunge-field-types* (make-hash-table :test 'eq))
(defvar *dunge-source-context* nil)

(defun source-context-with-frame (context kind value)
  (make-dunge-source-context
   :source-name (and context (dunge-source-context-source-name context))
   :base-directory (and context (dunge-source-context-base-directory context))
   :frames (append (and context (dunge-source-context-frames context))
                   (list (list kind value)))
   :parent (and context (dunge-source-context-parent context))))

(defun source-frame-description (frame)
  (destructuring-bind (kind value) frame
    (ecase kind
      (:form (format nil "~S" value))
      (:field (format nil "field ~S" value)))))

(defun source-frame-path (frames)
  (format nil "~{~A~^ -> ~}" (mapcar #'source-frame-description frames)))

(defun report-source-context (context stream &key (source-prefix " in "))
  (when (dunge-source-context-source-name context)
    (format stream "~A~A"
            source-prefix
            (dunge-source-context-source-name context)))
  (when (dunge-source-context-frames context)
    (format stream "~%while compiling ~A"
            (source-frame-path (dunge-source-context-frames context)))))

(define-condition dunge-source-error (error)
  ((message :initarg :message :reader dunge-source-error-message)
   (context :initarg :context :reader dunge-source-error-context))
  (:report
   (lambda (condition stream)
     (let ((context (dunge-source-error-context condition)))
       (format stream "Dunge source error")
       (when context
         (report-source-context context stream))
       (format stream ": ~A" (dunge-source-error-message condition))
       (loop for parent = (and context
                               (dunge-source-context-parent context))
               then (dunge-source-context-parent parent)
             while parent
             do (progn
                  (format stream "~%included from")
                  (report-source-context parent stream
                                         :source-prefix " ")))))))

(defmacro with-source-error-wrapping (&body body)
  `(handler-bind
       ((error
          (lambda (condition)
            (unless (typep condition 'dunge-source-error)
              (source-error "~A" condition)))))
     ,@body))

(defun source-error (format-control &rest format-arguments)
  (error 'dunge-source-error
         :message (apply #'format nil format-control format-arguments)
         :context *dunge-source-context*))

(defun parse-field-options (field-name options)
  (unless (evenp (length options))
    (source-error "Field ~S has malformed options ~S." field-name options))
  (loop with required-p = nil
        with default = nil
        with default-p = nil
        with target = field-name
        for (key value) on options by #'cddr
        do (case key
             (:required
              (setf required-p value))
             (:default
              (setf default value
                    default-p t))
             (:to
              (unless (keywordp value)
                (source-error "Field ~S :TO target must be a keyword; got ~S."
                              field-name
                              value))
              (setf target value))
             (otherwise
              (source-error "Unknown field option ~S on field ~S."
                            key
                            field-name)))
        finally (return (values required-p default default-p target))))

(defun parse-dunge-field-spec (spec)
  (destructuring-bind (name kind &rest options) spec
    (unless (keywordp name)
      (source-error "Field names must be keywords; got ~S." name))
    (unless (keywordp kind)
      (source-error "Field ~S type must be a keyword; got ~S." name kind))
    (multiple-value-bind (required-p default default-p target)
        (parse-field-options name options)
      (make-dunge-source-field
       :name name
       :kind kind
       :target target
       :required-p required-p
       :default default
       :default-p default-p))))

(defun register-dunge-source-form (tag builder field-specs)
  (unless (keywordp tag)
    (source-error "Source form tags must be keywords; got ~S." tag))
  (unless (functionp builder)
    (source-error "Source form ~S builder is not a function: ~S." tag builder))
  (setf (gethash tag *dunge-source-forms*)
        (make-dunge-source-form
         :tag tag
         :builder builder
         :fields (mapcar #'parse-dunge-field-spec field-specs)))
  tag)

(defmacro define-dunge-field-type (kind (value context) &body body)
  `(setf (gethash ,kind *dunge-field-types*)
         (lambda (,value ,context)
           ,@body)))

(defun dunge-field-type-compiler (kind)
  (or (gethash kind *dunge-field-types*)
      (source-error "Unknown field type ~S." kind)))

(defun source-plist-value (plist key marker)
  (loop for (field value) on plist by #'cddr
        when (eq field key)
          do (return value)
        finally (return marker)))

(defun private-source-tag-p (tag)
  (let ((name (symbol-name tag)))
    (and (plusp (length name))
         (char= (char name 0) #\%))))

(defun parse-source-plist (tag arguments)
  (unless (evenp (length arguments))
    (source-error "~S expects keyword fields, got ~S." tag arguments))
  (loop with seen = nil
        for (key value) on arguments by #'cddr
        unless (keywordp key)
          do (source-error "~S field name must be a keyword; got ~S."
                           tag
                           key)
        when (member key seen :test #'eq)
          do (source-error "~S field ~S appears more than once." tag key)
        do (push key seen)
        append (list key value)))

(defun global-state-source-form (key)
  `(:state :scope :global :key ,key))

(defun exactly-one-shorthand-argument (tag arguments)
  (unless (= 1 (length arguments))
    (source-error "~S expects exactly one argument; got ~S."
                  tag
                  arguments))
  (first arguments))

(defun expand-choice-source-form (arguments)
  (unless (and (>= (length arguments) 2)
               (stringp (first arguments)))
    (source-error
     ":CHOICE expects (:CHOICE label effect &key id when once); got ~S."
     arguments))
  (unless (evenp (length (cddr arguments)))
    (source-error
     ":CHOICE keyword metadata must contain an even number of entries; got ~S."
     (cddr arguments)))
  `(:%choice
    :label ,(first arguments)
    :do ,(second arguments)
    ,@(cddr arguments)))

(defun expand-once-source-form (arguments)
  (unless (and (= 3 (length arguments))
               (eq (first arguments) :id))
    (source-error
     ":ONCE expects (:ONCE :ID choice-id (:CHOICE ...)); got ~S."
     arguments))
  (let ((choice (third arguments)))
    (unless (and (consp choice)
                 (eq (first choice) :choice))
      (source-error ":ONCE wraps a :CHOICE form; got ~S." choice))
    (append (expand-choice-source-form (rest choice))
            (list :id (second arguments)
                  :once t))))

(defun expand-dunge-source-form (form)
  (let ((tag (first form))
        (arguments (rest form)))
    (case tag
      (:p
       (if (and (= 1 (length arguments))
                (stringp (first arguments)))
           `(:p :text ,(first arguments))
           form))
      (:say
       (if (and (= 1 (length arguments))
                (stringp (first arguments)))
           `(:say :text ,(first arguments))
           form))
      (:go
       `(:%goto :room ,(exactly-one-shorthand-argument tag arguments)))
      (:gosub
       `(:%gosub :room ,(exactly-one-shorthand-argument tag arguments)))
      (:choice
       (expand-choice-source-form arguments))
      (:once
       (expand-once-source-form arguments))
      (:mark
       `(:set
         :target ,(global-state-source-form
                   (exactly-one-shorthand-argument tag arguments))
         :value t))
      (:unmark
       `(:set
         :target ,(global-state-source-form
                   (exactly-one-shorthand-argument tag arguments))
         :value nil))
      (:marked?
       (global-state-source-form
        (exactly-one-shorthand-argument tag arguments)))
      (:not
       (if (and (= 1 (length arguments))
                (not (eq (first arguments) :condition)))
           `(:not :condition ,(first arguments))
           form))
      (:and
       (if (and arguments
                (not (eq (first arguments) :conditions)))
           `(:and :conditions ,arguments)
           form))
      (:or
       (if (and arguments
                (not (eq (first arguments) :conditions)))
           `(:or :conditions ,arguments)
           form))
      (:when
       (unless (>= (length arguments) 2)
         (source-error ":WHEN expects a condition and at least one body form; got ~S."
                       arguments))
       `(:branch :when ,(first arguments) :then ,(rest arguments)))
      (otherwise
       form))))

(defun compile-field-value (field value context)
  (let ((*dunge-source-context* (or context *dunge-source-context*)))
    (with-source-error-wrapping
      (funcall (dunge-field-type-compiler (dunge-source-field-kind field))
               value
               (or context *dunge-source-context*)))))

(defun compile-source-fields (descriptor arguments context)
  (let* ((context (or context *dunge-source-context*))
         (tag (dunge-source-form-tag descriptor))
         (fields (dunge-source-form-fields descriptor))
         (plist (parse-source-plist tag arguments))
         (field-names (mapcar #'dunge-source-field-name fields))
         (missing '#:missing)
         (initargs nil))
    (loop for (key value) on plist by #'cddr
          unless (member key field-names :test #'eq)
            do (source-error "~S does not allow field ~S." tag key))
    (dolist (field fields)
      (let* ((name (dunge-source-field-name field))
             (raw-value (source-plist-value plist name missing))
             (field-context (source-context-with-frame context :field name)))
        (let ((*dunge-source-context* field-context))
          (cond
            ((eq raw-value missing)
             (cond
               ((dunge-source-field-required-p field)
                (source-error "~S requires field ~S." tag name))
               ((dunge-source-field-default-p field)
                (setf initargs
                      (append initargs
                              (list (dunge-source-field-target field)
                                    (compile-field-value
                                     field
                                     (dunge-source-field-default field)
                                     field-context)))))))
            (t
             (setf initargs
                   (append initargs
                           (list (dunge-source-field-target field)
                                 (compile-field-value
                                  field
                                  raw-value
                                  field-context)))))))))
    initargs))

(defun compile-dunge-source-form (form &optional context)
  (let ((context (or context *dunge-source-context*)))
    (let ((*dunge-source-context* context))
      (unless (and (consp form) (keywordp (first form)))
        (source-error "Expected a source form beginning with a keyword, got ~S."
                      form))
      (let* ((source-tag (first form))
             (form-context (source-context-with-frame context :form source-tag))
             (*dunge-source-context* form-context)
             (form (expand-dunge-source-form form))
             (tag (first form))
             (descriptor (gethash tag *dunge-source-forms*)))
        (when (private-source-tag-p source-tag)
          (source-error "Unknown source form ~S." source-tag))
        (unless descriptor
          (source-error "Unknown source form ~S." tag))
        (let ((*dunge-source-context* form-context))
          (with-source-error-wrapping
            (let ((node (apply (dunge-source-form-builder descriptor)
                               (compile-source-fields descriptor
                                                      (rest form)
                                                      form-context))))
              (cond
                ((typep node 'game)
                 (validate-game node))
                ((typep node 'room)
                 (validate-room node)))
              node)))))))

(defun source-literal-p (value)
  (or (stringp value)
      (keywordp value)
      (numberp value)
      (eq value t)
      (null value)))

(defun compile-dunge-expression (value context)
  (cond
    ((source-literal-p value)
     value)
    ((consp value)
     (let ((node (compile-dunge-source-form value context)))
       (unless (typep node 'state-ref)
         (source-error "Expressions may only contain literals or state references; got ~S."
                       value))
       node))
    (t
     (source-error "Unsupported expression value ~S." value))))

(defun compile-dunge-condition (value context)
  (let ((node (compile-dunge-source-form value context)))
    (unless (or (typep node 'state-ref)
                (typep node 'condition-eq)
                (typep node 'condition-not)
                (typep node 'condition-and)
                (typep node 'condition-or))
      (source-error "Expected a condition form, got ~S." value))
    node))

(defun compile-dunge-effect (value context)
  (let ((node (compile-dunge-source-form value context)))
    (unless (typep node 'effect-node)
      (source-error "Expected an effect/control form, got ~S." value))
    node))

(defun compile-dunge-state-reference (value context)
  (let ((node (compile-dunge-source-form value context)))
    (unless (typep node 'state-ref)
      (source-error "Expected a state reference form, got ~S." value))
    node))

(defun ensure-source-list (kind value)
  (unless (listp value)
    (source-error "~S fields must be lists; got ~S." kind value))
  value)

(define-dunge-field-type :literal (value context)
  (declare (ignore context))
  value)

(define-dunge-field-type :string (value context)
  (declare (ignore context))
  (unless (stringp value)
    (source-error "Expected a string, got ~S." value))
  value)

(define-dunge-field-type :boolean (value context)
  (declare (ignore context))
  (unless (or (eq value t) (null value))
    (source-error "Expected a boolean, got ~S." value))
  value)

(define-dunge-field-type :keyword (value context)
  (declare (ignore context))
  (unless (keywordp value)
    (source-error "Expected a keyword, got ~S." value))
  value)

(define-dunge-field-type :node (value context)
  (compile-dunge-source-form value context))

(define-dunge-field-type :node-list (value context)
  (mapcar (lambda (form)
            (compile-dunge-source-form form context))
          (ensure-source-list :node-list value)))

(defun read-one-dunge-form (stream source-name)
  (let ((*read-eval* nil)
        (*readtable* (copy-readtable nil))
        (eof '#:eof))
    (let ((form (read stream nil eof)))
      (when (eq form eof)
        (source-error "~A is empty." source-name))
      (let ((extra (read stream nil eof)))
        (unless (eq extra eof)
          (source-error "~A must contain exactly one top-level form."
                        source-name)))
      form)))

(defun absolute-source-pathname-p (pathname)
  (let ((directory (pathname-directory pathname)))
    (and (consp directory)
         (eq (first directory) :absolute))))

(defun resolve-source-pathname (path context)
  (let ((pathname (pathname path)))
    (if (or (absolute-source-pathname-p pathname)
            (null context)
            (null (dunge-source-context-base-directory context)))
        pathname
        (merge-pathnames pathname
                         (dunge-source-context-base-directory context)))))

(defun source-file-context (path &optional parent)
  (let ((truename (truename path)))
    (make-dunge-source-context
     :source-name (namestring truename)
     :parent parent
     :base-directory (uiop:pathname-directory-pathname truename))))

(defun load-dunge-file-with-context (path context)
  (let ((resolved-path (resolve-source-pathname path context)))
    (let ((*dunge-source-context* context))
      (with-source-error-wrapping
        (with-open-file (stream resolved-path :direction :input)
          (let* ((file-context (source-file-context resolved-path context))
                 (*dunge-source-context* file-context))
            (compile-dunge-source-form
             (read-one-dunge-form stream (namestring resolved-path))
             file-context)))))))

(defun compile-dunge-room-source (value context)
  (cond
    ((stringp value)
     (let ((node (load-dunge-file-with-context value context)))
       (unless (typep node 'room)
         (source-error "Expected a room source file, got ~S." value))
       node))
    ((consp value)
     (let ((node (compile-dunge-source-form value context)))
       (unless (typep node 'room)
         (source-error "Expected a room source form, got ~S." value))
       node))
    (t
     (source-error
      "Room entries must be room source forms or string file paths; got ~S."
      value))))

(define-dunge-field-type :room-list (value context)
  (mapcar (lambda (form)
            (compile-dunge-room-source form context))
          (ensure-source-list :room-list value)))

(define-dunge-field-type :condition (value context)
  (compile-dunge-condition value context))

(define-dunge-field-type :condition-list (value context)
  (mapcar (lambda (form)
            (compile-dunge-condition form context))
          (ensure-source-list :condition-list value)))

(define-dunge-field-type :effect (value context)
  (compile-dunge-effect value context))

(define-dunge-field-type :effect-list (value context)
  (mapcar (lambda (form)
            (compile-dunge-effect form context))
          (ensure-source-list :effect-list value)))

(define-dunge-field-type :effect-block (value context)
  (%make-sequence :effects
                  (mapcar (lambda (form)
                            (compile-dunge-effect form context))
                          (ensure-source-list :effect-block value))))

(define-dunge-field-type :effect-or-block (value context)
  (if (and (consp value)
           (keywordp (first value)))
      (compile-dunge-effect value context)
      (%make-sequence :effects
                      (mapcar (lambda (form)
                                (compile-dunge-effect form context))
                              (ensure-source-list :effect-block value)))))

(define-dunge-field-type :expression (value context)
  (compile-dunge-expression value context))

(define-dunge-field-type :state-reference (value context)
  (compile-dunge-state-reference value context))

(defun compile-dunge-source (form)
  (compile-dunge-source-form form))

(defun load-dunge-string (string &key (source-name "string") base-directory)
  (let ((context (make-dunge-source-context
                  :source-name source-name
                  :base-directory (and base-directory
                                       (uiop:ensure-directory-pathname
                                        base-directory)))))
    (let ((*dunge-source-context* context))
      (with-source-error-wrapping
        (with-input-from-string (stream string)
          (compile-dunge-source-form
           (read-one-dunge-form stream source-name)
           context))))))

(defun load-dunge-file (path)
  (load-dunge-file-with-context path nil))

(defmacro define-dunge-node (name superclasses slots &body options)
  "Define an internal CLOS AST node and optional public .dunge source schema."
  (labels ((method-option-form (option generic-function)
             (destructuring-bind (keyword lambda-list &body body) option
               (declare (ignore keyword))
               (unless (and (listp lambda-list)
                            (= 1 (length lambda-list))
                            (symbolp (first lambda-list)))
                 (source-error
                  "DEFINE-DUNGE-NODE method option for ~S needs one variable; got ~S."
                  name
                  lambda-list))
               `(defmethod ,generic-function ((,(first lambda-list) ,name))
                  ,@body))))
    (let ((builder-name (intern (format nil "%MAKE-~A" name) *package*))
          id
          children
          source)
      (dolist (option options)
        (unless (consp option)
          (source-error "Malformed DEFINE-DUNGE-NODE option ~S." option))
        (case (first option)
          (:id
           (when id
             (source-error "Duplicate :ID option for ~S." name))
           (setf id option))
          (:children
           (when children
             (source-error "Duplicate :CHILDREN option for ~S." name))
           (setf children option))
          (:source
           (when source
             (source-error "Duplicate :SOURCE option for ~S." name))
           (setf source option))
          (otherwise
           (source-error "Unknown DEFINE-DUNGE-NODE option ~S for ~S."
                         (first option)
                         name))))
      `(progn
         (defclass ,name ,superclasses
           ,slots)
         (defun ,builder-name (&rest initargs)
           (apply #'make-instance ',name initargs))
         ,@(when id
             `(,(method-option-form id 'node-id)))
         ,@(when children
             `(,(method-option-form children 'node-children)))
         ,@(when source
             (destructuring-bind (keyword tag &body source-options) source
               (declare (ignore keyword))
               (let (fields)
                 (dolist (source-option source-options)
                   (unless (consp source-option)
                     (source-error "Malformed :SOURCE option ~S for ~S."
                                   source-option
                                   name))
                   (case (first source-option)
                     (:fields
                      (setf fields (rest source-option)))
                     (otherwise
                      (source-error "Unknown :SOURCE option ~S for ~S."
                                    (first source-option)
                                    name))))
                 `((register-dunge-source-form ,tag #',builder-name ',fields)))))))))
