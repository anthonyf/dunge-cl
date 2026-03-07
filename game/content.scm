;;; content.scm — Game content (character creation + town)

;;;
;;; Background data
;;; Each entry: (name description equipment-list armor gold)
;;;

(define *backgrounds*
  (list
    (list "Soldier"  "trained in combat, disciplined"
          (list "Sword (d8)" "Gambeson (Armor 1)" "Helm (+1 Armor)")
          2 8)
    (list "Scholar"  "educated, curious, physically weak"
          (list "Spellbook" "Dagger (d6)" "Ink & Quill")
          0 8)
    (list "Criminal" "streetwise, light-fingered, untrustworthy"
          (list "Lockpicks" "Dagger (d6)" "Dark Cloak" "Grappling Hook")
          0 8)
    (list "Pilgrim"  "faithful, traveled, poor"
          (list "Staff (d6)" "Holy Symbol" "Healing Herbs x3")
          0 8)
    (list "Hunter"   "survivalist, patient, rural"
          (list "Bow (d6)" "Arrows" "Knife (d6)" "Snare Kit" "Furs")
          0 8)
    (list "Merchant" "wealthy, connected, soft"
          (list "Dagger (d6)" "Fine Clothes")
          0 38)))

(define (bg-name bg) (car bg))
(define (bg-description bg) (cadr bg))
(define (bg-equipment bg) (caddr bg))
(define (bg-armor bg) (car (cddr (cdr bg))))
(define (bg-gold bg) (car (cddr (cddr bg))))

(define (find-background name)
  (let loop ((bgs *backgrounds*))
    (cond
      ((null? bgs) nil)
      ((equal? (bg-name (car bgs)) name) (car bgs))
      (else (loop (cdr bgs))))))

;;;
;;; Character Creation Rooms
;;;

(define-room start "Welcome to Dunge!"
  (exit "Continue" character-info))

(define-room character-info "Character Creation"
  (gate (state-get 'character 'name)
    ;; then: name already set
    ((text "Welcome " (state-ref 'character 'name) "!")
     (exit "Continue" choose-background))
    ;; else: ask for name
    ((text "Let's gather some information about your character.")
     (prompt "What is your name?"
             non-empty-string?
             (lambda (input)
               (state-set! 'character 'name input)
               (goto 'character-info))))))

(define-room choose-background "Choose Your Background"
  (text "Your background determines your starting equipment and skills.")
  (text "")
  (dynamic (lambda ()
    (map (lambda (bg)
           (make-choice
             (string-append (bg-name bg) " - " (bg-description bg))
             (lambda ()
               (state-set! 'character 'background (bg-name bg))
               (goto 'roll-stats))))
         *backgrounds*))))

(define-room roll-stats "Roll Ability Scores"
  ;; Roll stats if not already rolled
  (dynamic (lambda ()
    (when (not (state-get 'character 'stats-rolled))
      (state-set! 'character 'str (apply + (roll-dice 3 6)))
      (state-set! 'character 'dex (apply + (roll-dice 3 6)))
      (state-set! 'character 'wil (apply + (roll-dice 3 6)))
      (state-set! 'character 'stats-rolled t))
    nil))
  (text "You rolled:")
  (text "  STR: " (state-ref 'character 'str))
  (text "  DEX: " (state-ref 'character 'dex))
  (text "  WIL: " (state-ref 'character 'wil))
  (text "")
  (text "You may swap two ability scores, or keep them as they are.")
  ;; Dynamic swap choices
  (dynamic (lambda ()
    (let ((str (state-get 'character 'str))
          (dex (state-get 'character 'dex))
          (wil (state-get 'character 'wil)))
      (list
        (make-choice
          (fmt "Swap STR (" str ") and DEX (" dex ")")
          (lambda ()
            (state-set! 'character 'str dex)
            (state-set! 'character 'dex str)
            (goto 'roll-hp)))
        (make-choice
          (fmt "Swap STR (" str ") and WIL (" wil ")")
          (lambda ()
            (state-set! 'character 'str wil)
            (state-set! 'character 'wil str)
            (goto 'roll-hp)))
        (make-choice
          (fmt "Swap DEX (" dex ") and WIL (" wil ")")
          (lambda ()
            (state-set! 'character 'dex wil)
            (state-set! 'character 'wil dex)
            (goto 'roll-hp)))
        (make-choice
          "Keep as they are"
          (lambda ()
            (goto 'roll-hp))))))))

(define-room roll-hp "Roll Hit Points"
  (dynamic (lambda ()
    (when (not (state-get 'character 'hp-rolled))
      (let ((hp (roll-die 6)))
        (state-set! 'character 'hp hp)
        (state-set! 'character 'hp-max hp)
        (state-set! 'character 'hp-rolled t)))
    nil))
  (text "Your hit points: " (state-ref 'character 'hp))
  (exit "Continue" equipment))

(define-room equipment "Equipment"
  (dynamic (lambda ()
    (when (not (state-get 'character 'equipped))
      (let* ((bg (find-background (state-get 'character 'background)))
             (items (append (bg-equipment bg)
                            (list "Rations x3" "Torch x2" "Waterskin"))))
        (state-set! 'character 'inventory items)
        (state-set! 'character 'armor (bg-armor bg))
        (state-set! 'character 'gold (bg-gold bg))
        (state-set! 'character 'equipped t)))
    nil))
  (text "As a " (state-ref 'character 'background) " you receive:")
  (text "")
  (dynamic (lambda ()
    (for-each (lambda (item)
                (display "  - ")
                (display item)
                (newline))
              (state-get 'character 'inventory))
    nil))
  (text "")
  (dynamic (lambda ()
    (display (fmt "  Armor: " (state-get 'character 'armor)))
    (newline)
    (display (fmt "  Gold:  " (state-get 'character 'gold)))
    (newline)
    nil))
  (text "")
  (exit "Continue" fate-points))

(define-room fate-points "Fate Points"
  (dynamic (lambda ()
    (when (not (state-get 'character 'fate))
      (state-set! 'character 'fate 2))
    nil))
  (text "You begin with 2 Fate Points.")
  (text "Fate Points can be spent to narrowly avoid death or reroll a critical save.")
  (text "Use them wisely — they are hard to come by.")
  (exit "Continue" character-summary))

(define-room character-summary "Character Summary"
  (dynamic (lambda ()
    (display (fmt "  Name:       " (state-get 'character 'name)))
    (newline)
    (display (fmt "  Background: " (state-get 'character 'background)))
    (newline)
    (newline)
    (display (fmt "  STR: " (state-get 'character 'str)
                  "   DEX: " (state-get 'character 'dex)
                  "   WIL: " (state-get 'character 'wil)))
    (newline)
    (newline)
    (display (fmt "  HP:    " (state-get 'character 'hp)
                  "/" (state-get 'character 'hp-max)))
    (newline)
    (display (fmt "  Armor: " (state-get 'character 'armor)))
    (newline)
    (display (fmt "  Gold:  " (state-get 'character 'gold)))
    (newline)
    (display (fmt "  Fate:  " (state-get 'character 'fate)))
    (newline)
    (newline)
    (display "  Inventory:")
    (newline)
    (for-each (lambda (item)
                (display (fmt "    - " item))
                (newline))
              (state-get 'character 'inventory))
    nil))
  (text "")
  (exit "Begin your adventure!" town-square))

;;;
;;; Town Rooms
;;;

(define-room town-square "Town Square"
  (text "This is the town square, the central hub of this very small, unnamed town.")
  (text "You see an adventure board here where the townsfolk have posted their bounties.")
  (text "Perfect for an adventurer like yourself.")
  (text "To the east you see smoke from the forge of the town blacksmith.")
  (exit "Look at the Adventure Board" adventure-board)
  (exit "Go to the blacksmith" blacksmith))

(define-room adventure-board "Adventure Board"
  (text "Todo random adventures will be generated and posted here.")
  (exit "Back" town-square))

(define-room blacksmith "Blacksmith"
  (text "This is the blacksmith.")
  (exit "Return to town square" town-square))
