(in-package #:dunge-tests)

(in-suite :dunge-tests)

;;; Expression language: arithmetic, comparisons, interpolation, formatting.

(defun expression-game ()
  (source-node
   '(:game
     :start "room"
     :state ((:hp 5) (:gold nil) (:mood :calm))
     :rooms
     ((:room
       :id "room"
       :body
       ((:entity :name "chest" :id "chest" :state ((:coins 4)))))))))

(defun expression-context (game)
  (let* ((room (first (game-rooms game)))
         (chest (first (entities room))))
    (test-context game :scene room :self chest)))

(defun evaluate-source-expression (form context)
  (evaluate-expression (dunge::compile-dunge-expression form nil) context))

(test expression-shorthands-expand-to-canonical-forms
  (flet ((expands (shorthand canonical)
           (is (equal canonical (dunge::expand-dunge-source-form shorthand)))))
    (expands '(:add 1 2 3) '(:add :operands (1 2 3)))
    (expands '(:sub (:self :hp) 1) '(:sub :operands ((:self :hp) 1)))
    (expands '(:mul 2 3) '(:mul :operands (2 3)))
    (expands '(:min 1 2) '(:min :operands (1 2)))
    (expands '(:max 1 2) '(:max :operands (1 2)))
    (expands '(:concat "a" (:self :hp)) '(:concat :parts ("a" (:self :hp))))
    (expands '(:eq (:self :switch) :on)
             '(:eq :left (:self :switch) :right :on))
    ;; A positional form may start with a keyword value.
    (expands '(:eq :on (:self :switch))
             '(:eq :left :on :right (:self :switch)))
    (expands '(:say :open) '(:say :text :open))
    (expands '(:lt 1 2) '(:lt :left 1 :right 2))
    (expands '(:lte 1 2) '(:lte :left 1 :right 2))
    (expands '(:gt 1 2) '(:gt :left 1 :right 2))
    (expands '(:gte 1 2) '(:gte :left 1 :right 2))
    (dolist (form '((:add :operands (1 2))
                    (:concat :parts ("a"))
                    (:eq :left 1 :right 2)
                    (:lt :right 2 :left 1)))
      (expands form form)))
  (signals dunge-source-error (source-node '(:lt 1)))
  (signals dunge-source-error (source-node '(:eq 1 2 3))))

(test interpolated-strings-compile-to-concat
  (let ((node (dunge::compile-dunge-expression "HP {self:hp}/{global:max-hp}!" nil)))
    (is (typep node 'concat))
    (destructuring-bind (prefix hp slash max-hp suffix) (dunge::concat-parts node)
      (is (equal "HP " prefix))
      (is (eq :self (dunge::state-ref-scope hp)))
      (is (eq :hp (dunge::state-ref-key hp)))
      (is (equal "/" slash))
      (is (eq :global (dunge::state-ref-scope max-hp)))
      (is (eq :max-hp (dunge::state-ref-key max-hp)))
      (is (equal "!" suffix))))
  (let ((reference (first (dunge::concat-parts
                           (dunge::compile-dunge-expression "{ref:door:open}" nil)))))
    (is (eq :ref (dunge::state-ref-scope reference)))
    (is (eq :door (dunge::state-ref-role reference)))
    (is (eq :open (dunge::state-ref-key reference))))
  ;; Strings without placeholders stay strings; doubled braces are literal.
  (is (equal "plain" (dunge::compile-dunge-expression "plain" nil)))
  (is (equal "{x} and }" (dunge::compile-dunge-expression "{{x}} and }}" nil)))
  (dolist (bad '("{self:hp" "a } b" "{player:hp}" "{self}" "{self:}"
                 "{ref:door}" "{self:h p}"))
    (signals dunge-source-error (dunge::compile-dunge-expression bad nil))))

(test values-format-the-same-way-in-both-runtimes
  (is (equal "text" (dunge::format-dunge-value "text")))
  (is (equal "-12" (dunge::format-dunge-value -12)))
  (is (equal "open" (dunge::format-dunge-value :open)))
  (is (equal "true" (dunge::format-dunge-value t)))
  (is (equal "" (dunge::format-dunge-value nil))))

(test arithmetic-and-comparisons-evaluate-over-state
  (let* ((game (expression-game))
         (context (expression-context game)))
    (flet ((value (form)
             (evaluate-source-expression form context))
           (holds (form)
             (evaluate-condition (source-node form) context)))
      (is (= 10 (value '(:add 1 (:global :hp) (:self :coins)))))
      (is (= -2 (value '(:sub 5 3 4))))
      (is (= 40 (value '(:mul 2 (:global :hp) (:self :coins)))))
      (is (= 4 (value '(:min (:global :hp) 9 (:self :coins)))))
      (is (= 9 (value '(:max (:global :hp) 9 (:self :coins)))))
      (is (= 7 (value '(:add 7))))
      ;; Unset state counts as 0.
      (is (= 3 (value '(:add 3 (:global :gold)))))
      (is (equal "5 coins: 4, mood calm, gold "
                 (value "{global:hp} coins: {self:coins}, mood {global:mood}, gold {global:gold}")))
      (is (equal "54" (value '(:concat (:global :hp) (:self :coins)))))
      (is (holds '(:lt (:self :coins) (:global :hp))))
      (is (not (holds '(:lt (:global :hp) (:global :hp)))))
      (is (holds '(:lte (:global :hp) 5)))
      (is (holds '(:gt (:add (:self :coins) 2) (:global :hp))))
      (is (holds '(:gte (:global :hp) 5)))
      (is (not (holds '(:gte (:global :gold) 1))))
      (is (holds '(:eq (:global :mood) :calm)))
      (is (holds '(:eq (:add 2 3) (:global :hp)))))))

(test arithmetic-errors-on-non-integers-and-overflow
  (let* ((game (expression-game))
         (context (expression-context game)))
    (flet ((message (form)
             (error-message-from
              (lambda () (evaluate-source-expression form context)))))
      (is (equal "Arithmetic needs integer values; got \"calm\"."
                 (message '(:add 1 (:global :mood)))))
      (is (equal "Arithmetic result is outside the supported integer range."
                 (message '(:add 9007199254740991 1))))
      (is (equal "Arithmetic result is outside the supported integer range."
                 (message '(:sub -9007199254740991 1))))
      (is (= 9007199254740991 (evaluate-source-expression
                               '(:sub 9007199254740991 0) context))))
    (is (contains-substring-p
         "Arithmetic needs integer values"
         (error-message-from
          (lambda ()
            (evaluate-condition (source-node '(:gt (:global :mood) 1)) context)))))
    (dunge::set-state-reference-value (source-node '(:global :gold))
                                      9007199254740991
                                      context)
    (is (equal "Arithmetic result is outside the supported integer range."
               (error-message-from
                (lambda ()
                  (execute-effect (source-node '(:inc :target (:global :gold)))
                                  context)))))))

(test validator-rejects-malformed-expressions
  (flet ((rejects (form)
           (is (not (null (error-message-from
                           (lambda () (source-game-with-body form))))))))
    (rejects '(:choice "Bad" (:say (:add))))
    (rejects '(:choice "Bad" (:say (:sub 1))))
    (rejects '(:choice "Bad" (:say (:add "one" 1))))
    (rejects '(:choice "Bad" (:say (:mul :two 1))))
    (rejects '(:choice "Bad" (:say (:add (:concat "1") 1))))
    (rejects '(:choice "Bad" (:say (:add 9007199254740992 0))))
    (rejects '(:choice "Bad" (:say 1/2)))
    (rejects '(:choice "Bad" (:quit) :when (:lt t 1)))
    (rejects '(:choice "Bad" (:inc :target (:global :x) :amount "one")))
    (rejects '(:choice "Bad" (:quit) :when (:add 1 2)))
    (rejects '(:choice "Bad" (:say (:eq 1 2)))))
  (is (typep (source-game-with-body
              '(:choice "Fine"
                ((:set :target (:global :x) :value (:max 0 (:sub (:global :x) 1)))
                 (:say "x is {global:x}"))
                :when (:and (:gte (:global :x) 1) (:eq (:global :x) (:add 1 0)))))
             'game)))

(test html-compiler-lowers-expressions
  (let ((script (dunge-html:compile-game-script
                 (source-game-with-body
                  '(:choice "Count"
                    ((:set :target (:global :x) :value (:add (:global :x) 2))
                     (:say "x is {global:x}"))
                    :when (:lt (:global :x) 10))))))
    (is (contains-substring-p "\"type\":\"arithmetic\",\"operator\":\"add\"" script))
    (is (contains-substring-p "\"type\":\"concat\"" script))
    (is (contains-substring-p "\"type\":\"compare\",\"operator\":\"lt\"" script)))
  (signals error
    (dunge-html::compile-runtime-number 9007199254740992)))
