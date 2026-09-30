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

;;; Shorthand forms
;;;
;;; Every node has one canonical keyword-field spelling, checked by its source
;;; schema, such as (:go :room "hall"). Shorthands are registered rewrites
;;; into those canonical forms, such as (:go "hall"). A shorthand tag may be
;;; shorthand-only, like :MARK, or share its tag with a node, like :GO; the
;;; latter rewrite only their positional spelling and leave the keyword-field
;;; spelling to the schema. Expansion happens once, before schema compilation.

(defvar *dunge-shorthands* (make-hash-table :test 'eq))

(defmacro define-dunge-shorthand (tag (arguments) &body body)
  "Register a shorthand for source forms beginning with TAG.
BODY is evaluated with ARGUMENTS bound to the form's arguments, and returns the
canonical source form to compile instead, or NIL to compile the form as
written."
  `(progn
     (setf (gethash ,tag *dunge-shorthands*)
           (lambda (,arguments)
             ,@body))
     ,tag))

(defun expand-dunge-source-form (form)
  (let ((expander (gethash (first form) *dunge-shorthands*)))
    (or (and expander
             (funcall expander (rest form)))
        form)))

(defun positional-arguments-p (arguments)
  "True when ARGUMENTS start with a value rather than a keyword field name."
  (and arguments
       (not (keywordp (first arguments)))))

(defun exactly-one-shorthand-argument (tag arguments)
  (unless (= 1 (length arguments))
    (source-error "~S expects exactly one argument; got ~S."
                  tag
                  arguments))
  (first arguments))

(defun state-source-form (scope key &optional role)
  `(:state :scope ,scope ,@(when role (list :role role)) :key ,key))

(defun field-arguments-p (arguments fields)
  "True when ARGUMENTS start with one of the keyword field names FIELDS.
Unlike POSITIONAL-ARGUMENTS-P, this lets a positional form start with a
keyword value, as in (:say :open) or (:eq :open (:self :status))."
  (and arguments
       (member (first arguments) fields :test #'eq)))

(defmacro define-single-field-shorthand (tag field)
  "Let (TAG VALUE) stand for (TAG FIELD VALUE)."
  `(define-dunge-shorthand ,tag (arguments)
     (unless (field-arguments-p arguments '(,field))
       (list ,tag ,field (exactly-one-shorthand-argument ,tag arguments)))))

(defmacro define-binary-shorthand (tag)
  "Let (TAG LEFT RIGHT) stand for (TAG :LEFT LEFT :RIGHT RIGHT)."
  `(define-dunge-shorthand ,tag (arguments)
     (unless (field-arguments-p arguments '(:left :right))
       (unless (= 2 (length arguments))
         (source-error "~S expects two operands; got ~S." ,tag arguments))
       (list ,tag :left (first arguments) :right (second arguments)))))

(defmacro define-list-field-shorthand (tag field)
  "Let (TAG VALUE ...) stand for (TAG FIELD (VALUE ...))."
  `(define-dunge-shorthand ,tag (arguments)
     (unless (field-arguments-p arguments '(,field))
       (list ,tag ,field arguments))))

(define-single-field-shorthand :p :text)
(define-single-field-shorthand :say :text)
(define-single-field-shorthand :go :room)
(define-single-field-shorthand :gosub :room)
(define-single-field-shorthand :not :condition)

;;; Expressions: (:add 1 (:self :hp)) stands for (:add :operands (...)), and
;;; (:lt a b) for (:lt :left a :right b).

(define-binary-shorthand :eq)
(define-binary-shorthand :lt)
(define-binary-shorthand :lte)
(define-binary-shorthand :gt)
(define-binary-shorthand :gte)

(define-list-field-shorthand :add :operands)
(define-list-field-shorthand :sub :operands)
(define-list-field-shorthand :mul :operands)
(define-list-field-shorthand :min :operands)
(define-list-field-shorthand :max :operands)
(define-list-field-shorthand :concat :parts)

(define-dunge-shorthand :roll (arguments)
  (unless (field-arguments-p arguments '(:dice :label))
    `(:roll :dice ,(first arguments) ,@(rest arguments))))

(define-dunge-shorthand :and (arguments)
  (when (positional-arguments-p arguments)
    `(:and :conditions ,arguments)))

(define-dunge-shorthand :or (arguments)
  (when (positional-arguments-p arguments)
    `(:or :conditions ,arguments)))

(define-dunge-shorthand :choice (arguments)
  (when (positional-arguments-p arguments)
    (unless (and (>= (length arguments) 2)
                 (stringp (first arguments)))
      (source-error
       ":CHOICE expects (:CHOICE label effect &key id when once); got ~S."
       arguments))
    (unless (evenp (length (cddr arguments)))
      (source-error
       ":CHOICE keyword metadata must contain an even number of entries; got ~S."
       (cddr arguments)))
    `(:choice
      :label ,(first arguments)
      :do ,(second arguments)
      ,@(cddr arguments))))

(define-dunge-shorthand :once (arguments)
  (unless (and (= 3 (length arguments))
               (eq (first arguments) :id))
    (source-error
     ":ONCE expects (:ONCE :ID choice-id (:CHOICE ...)); got ~S."
     arguments))
  (let ((choice (third arguments)))
    (unless (and (consp choice)
                 (eq (first choice) :choice))
      (source-error ":ONCE wraps a :CHOICE form; got ~S." choice))
    (append (expand-dunge-source-form choice)
            (list :id (second arguments)
                  :once t))))

(define-dunge-shorthand :when (arguments)
  (unless (>= (length arguments) 2)
    (source-error ":WHEN expects a condition and at least one body form; got ~S."
                  arguments))
  `(:branch :when ,(first arguments) :then ,(rest arguments)))

;;; State references: (:global key), (:self key), (:player key), and
;;; (:ref role key) stand for (:state :scope SCOPE [:role ROLE] :key KEY).

(define-dunge-shorthand :global (arguments)
  (state-source-form :global (exactly-one-shorthand-argument :global arguments)))

(define-dunge-shorthand :player (arguments)
  (state-source-form :player (exactly-one-shorthand-argument :player arguments)))

(define-dunge-shorthand :self (arguments)
  (state-source-form :self (exactly-one-shorthand-argument :self arguments)))

(define-dunge-shorthand :ref (arguments)
  (unless (= 2 (length arguments))
    (source-error ":REF expects a role and a key, as in (:REF :door :open); got ~S."
                  arguments))
  (state-source-form :ref (second arguments) (first arguments)))

;;; Story flags are global booleans.

(define-dunge-shorthand :marked? (arguments)
  (state-source-form :global (exactly-one-shorthand-argument :marked? arguments)))

(define-dunge-shorthand :mark (arguments)
  `(:set :target ,(state-source-form
                   :global
                   (exactly-one-shorthand-argument :mark arguments))
         :value t))

(define-dunge-shorthand :unmark (arguments)
  `(:set :target ,(state-source-form
                   :global
                   (exactly-one-shorthand-argument :unmark arguments))
         :value nil))

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

(defun interpolation-placeholder-form (placeholder)
  "Return the state reference source form for the text of a {...} PLACEHOLDER."
  (flet ((key (name)
           (when (or (zerop (length name))
                     (find-if (lambda (char)
                                (member char '(#\Space #\Tab #\Newline #\{)))
                              name))
             (source-error "Malformed interpolation key ~S in {~A}."
                           name
                           placeholder))
           (intern (string-upcase name) :keyword)))
    (let ((parts (uiop:split-string placeholder :separator ":")))
      (cond
        ((and (= 2 (length parts))
              (member (first parts) '("self" "global" "player") :test #'string=))
         (state-source-form (intern (string-upcase (first parts)) :keyword)
                            (key (second parts))))
        ((and (= 3 (length parts))
              (string= (first parts) "ref"))
         (state-source-form :ref (key (third parts)) (key (second parts))))
        (t
         (source-error "Unknown interpolation {~A}; expected {self:key}, ~
                        {global:key}, {player:key}, or {ref:role:key}."
                       placeholder))))))

(defun parse-interpolated-string (string)
  "Split STRING into a list of literal strings and state reference source forms.
{scope:key} marks a reference; {{ and }} stand for literal braces."
  (let ((parts nil)
        (literal (make-string-output-stream))
        (index 0)
        (length (length string)))
    (flet ((flush-literal ()
             (let ((text (get-output-stream-string literal)))
               (when (plusp (length text))
                 (push text parts)))))
      (loop while (< index length)
            do (let ((char (char string index))
                     (next (and (< (1+ index) length)
                                (char string (1+ index)))))
                 (cond
                   ((and (member char '(#\{ #\}))
                         (eql next char))
                    (write-char char literal)
                    (incf index 2))
                   ((char= char #\})
                    (source-error "Unmatched } in ~S; write }} for a literal brace."
                                  string))
                   ((char= char #\{)
                    (let ((close (position #\} string :start index)))
                      (unless close
                        (source-error "Unclosed { in ~S; write {{ for a literal brace."
                                      string))
                      (flush-literal)
                      (push (interpolation-placeholder-form
                             (subseq string (1+ index) close))
                            parts)
                      (setf index (1+ close))))
                   (t
                    (write-char char literal)
                    (incf index)))))
      (flush-literal))
    (nreverse parts)))

(defun compile-dunge-string-expression (string context)
  "Compile STRING, which may contain {scope:key} interpolations, to either a
plain string or a CONCAT node."
  (let ((parts (parse-interpolated-string string)))
    (if (every #'stringp parts)
        (apply #'concatenate 'string parts)
        (%make-concat
         :parts (mapcar (lambda (part)
                          (if (stringp part)
                              part
                              (compile-dunge-source-form part context)))
                        parts)))))

(defun compile-dunge-expression (value context)
  (cond
    ((stringp value)
     (compile-dunge-string-expression value context))
    ((source-literal-p value)
     value)
    ((consp value)
     (let ((node (compile-dunge-source-form value context)))
       (unless (typep node 'expression-node)
         (source-error "Expected an expression form, got ~S." value))
       node))
    (t
     (source-error "Unsupported expression value ~S." value))))

(defun compile-dunge-condition (value context)
  (let ((node (compile-dunge-source-form value context)))
    (unless (typep node 'condition-node)
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
