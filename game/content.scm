;;; content.scm — Game content (character creation + town)

;;;
;;; Background data
;;; Each entry: (name description equipment-thunk armor gold)
;;;

(define (base-equipment)
  "Common starting items for all backgrounds."
  (list (make-stackable-item "Rations" 3 10)
        (make-stackable-item "Torch" 2 5)
        (make-item "Waterskin")))

(define *backgrounds*
  (list
    (list "Soldier"  "trained in combat, disciplined"
          (lambda () (list (make-weapon "Sword" 8)
                           (make-item "Gambeson (Armor 1)")
                           (make-item "Helm (+1 Armor)")))
          2 8)
    (list "Scholar"  "educated, curious, physically weak"
          (lambda () (list (make-item "Spellbook")
                           (make-weapon "Dagger" 6)
                           (make-item "Ink & Quill")))
          0 8)
    (list "Criminal" "streetwise, light-fingered, untrustworthy"
          (lambda () (list (make-item "Lockpicks")
                           (make-weapon "Dagger" 6)
                           (make-item "Dark Cloak")
                           (make-item "Grappling Hook")))
          0 8)
    (list "Pilgrim"  "faithful, traveled, poor"
          (lambda () (list (make-weapon "Staff" 6)
                           (make-item "Holy Symbol")
                           (make-healing-herb 3 10)))
          0 8)
    (list "Hunter"   "survivalist, patient, rural"
          (lambda () (list (make-weapon "Bow" 6)
                           (make-item "Arrows")
                           (make-weapon "Knife" 6)
                           (make-item "Snare Kit")
                           (make-item "Furs")))
          0 8)
    (list "Merchant" "wealthy, connected, soft"
          (lambda () (list (make-weapon "Dagger" 6)
                           (make-item "Fine Clothes")))
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
  (gate (character-name *player*)
    ;; then: name already set
    ((text "Welcome " (player-ref 'name) "!")
     (exit "Continue" choose-background))
    ;; else: ask for name
    ((text "Let's gather some information about your character.")
     (prompt "What is your name?"
             non-empty-string?
             (lambda (input)
               (set-character-name! *player* input)
               (goto 'character-info))))))

(define-room choose-background "Choose Your Background"
  (text "Your background determines your starting equipment and skills.")
  (text "")
  (dynamic (lambda ()
    (map (lambda (bg)
           (make-choice
             (string-append (bg-name bg) " - " (bg-description bg))
             (lambda ()
               (set-character-background! *player* (bg-name bg))
               (goto 'roll-stats))))
         *backgrounds*))))

(define-room roll-stats "Roll Ability Scores"
  ;; Roll stats if not already rolled
  (dynamic (lambda ()
    (when (not (character-str *player*))
      (set-character-str! *player* (apply + (roll-dice 3 6)))
      (set-character-dex! *player* (apply + (roll-dice 3 6)))
      (set-character-wil! *player* (apply + (roll-dice 3 6))))
    nil))
  (text "You rolled:")
  (text "  STR: " (player-ref 'str))
  (text "  DEX: " (player-ref 'dex))
  (text "  WIL: " (player-ref 'wil))
  (text "")
  (text "You may swap two ability scores, or keep them as they are.")
  ;; Dynamic swap choices
  (dynamic (lambda ()
    (let ((str (character-str *player*))
          (dex (character-dex *player*))
          (wil (character-wil *player*)))
      (list
        (make-choice
          (fmt "Swap STR (" str ") and DEX (" dex ")")
          (lambda ()
            (set-character-str! *player* dex)
            (set-character-dex! *player* str)
            (goto 'roll-hp)))
        (make-choice
          (fmt "Swap STR (" str ") and WIL (" wil ")")
          (lambda ()
            (set-character-str! *player* wil)
            (set-character-wil! *player* str)
            (goto 'roll-hp)))
        (make-choice
          (fmt "Swap DEX (" dex ") and WIL (" wil ")")
          (lambda ()
            (set-character-dex! *player* wil)
            (set-character-wil! *player* dex)
            (goto 'roll-hp)))
        (make-choice
          "Keep as they are"
          (lambda ()
            (goto 'roll-hp))))))))

(define-room roll-hp "Roll Hit Points"
  (dynamic (lambda ()
    (when (not (character-hp *player*))
      (let ((hp (roll-die 6)))
        (set-character-hp! *player* hp)
        (set-character-hp-max! *player* hp)))
    nil))
  (text "Your hit points: " (player-ref 'hp))
  (exit "Continue" equipment))

(define-room equipment "Equipment"
  (dynamic (lambda ()
    (when (null? (character-inventory *player*))
      (let* ((bg (find-background (character-background *player*)))
             (items (append ((bg-equipment bg))
                            (base-equipment))))
        (set-character-inventory! *player* items)
        (set-character-armor! *player* (bg-armor bg))
        (set-character-gold! *player* (bg-gold bg))))
    nil))
  (text "As a " (player-ref 'background) " you receive:")
  (text "")
  (dynamic (lambda ()
    (for-each (lambda (i)
                (display "  - ")
                (display (item-display-name i))
                (newline))
              (character-inventory *player*))
    nil))
  (text "")
  (dynamic (lambda ()
    (display (fmt "  Armor: " (character-armor *player*)))
    (newline)
    (display (fmt "  Gold:  " (character-gold *player*)))
    (newline)
    nil))
  (text "")
  (exit "Continue" fate-points))

(define-room fate-points "Fate Points"
  (dynamic (lambda ()
    (when (not (character-fate *player*))
      (set-character-fate! *player* 2))
    nil))
  (text "You begin with 2 Fate Points.")
  (text "Fate Points can be spent to narrowly avoid death or reroll a critical save.")
  (text "Use them wisely — they are hard to come by.")
  (exit "Continue" character-summary))

(define-room character-summary "Character Summary"
  (dynamic (lambda ()
    (display (fmt "  Name:       " (character-name *player*)))
    (newline)
    (display (fmt "  Background: " (character-background *player*)))
    (newline)
    (newline)
    (display (fmt "  STR: " (character-str *player*)
                  "   DEX: " (character-dex *player*)
                  "   WIL: " (character-wil *player*)))
    (newline)
    (newline)
    (display (fmt "  HP:    " (character-hp *player*)
                  "/" (character-hp-max *player*)))
    (newline)
    (display (fmt "  Armor: " (character-armor *player*)))
    (newline)
    (display (fmt "  Gold:  " (character-gold *player*)))
    (newline)
    (display (fmt "  Fate:  " (character-fate *player*)))
    (newline)
    (newline)
    (display "  Inventory:")
    (newline)
    (for-each (lambda (i)
                (display (fmt "    - " (item-display-name i)))
                (newline))
              (character-inventory *player*))
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
  (text "The board is covered in bounties and requests from the townsfolk.")
  (exit "Hunt a Goblin (combat test)" test-combat)
  (exit "Back" town-square))

;;;
;;; Test Combat Encounter
;;;

(define-room test-combat "The Forest Path"
  (combat-encounter
    'enemy (list "Goblin")
    'intro (text "A goblin leaps from the shadows, snarling!")
    'victory (exit "Continue" test-combat-victory)
    'death (exit "Continue" test-combat-death)
    'incapacitated (exit "Continue" test-combat-incapacitated)
    'fled (exit "Continue" test-combat-fled)))

(define-room test-combat-victory "Victory!"
  (text "The goblin lies defeated at your feet.")
  (text "You search the body and find a few coins.")
  (exit "Return to town" town-square))

(define-room test-combat-death "You Died"
  (text "Your vision fades as you collapse...")
  (text "But fate intervenes — you awaken back in town, bruised but alive.")
  (exit "Return to town" town-square))

(define-room test-combat-incapacitated "Incapacitated"
  (text "You fall unconscious from your wounds.")
  (text "A passing traveler finds you and drags you back to town.")
  (exit "Return to town" town-square))

(define-room test-combat-fled "Escaped!"
  (text "You flee back to the safety of town, heart pounding.")
  (exit "Return to town" town-square))

(define-room blacksmith "Blacksmith"
  (text "This is the blacksmith.")
  (exit "Return to town square" town-square))
