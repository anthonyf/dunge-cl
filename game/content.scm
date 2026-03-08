;;; content.scm — Game content (character creation + town)

;;;
;;; Background data
;;;

(define-record background name description equipment-thunk armor gold)

(define (base-equipment)
  "Common starting items for all backgrounds."
  (list (make-stackable-item "Rations" 3 10)
        (make-stackable-item "Torch" 2 5)
        (make-item "Waterskin")))

(define *backgrounds*
  (list
    (make-background "Soldier" "trained in combat, disciplined"
          (lambda () (list (make-weapon "Sword" 8)
                           (make-item "Gambeson (Armor 1)")
                           (make-item "Helm (+1 Armor)")))
          2 8)
    (make-background "Scholar" "educated, curious, physically weak"
          (lambda () (list (make-item "Spellbook")
                           (make-weapon "Dagger" 6)
                           (make-item "Ink & Quill")))
          0 8)
    (make-background "Criminal" "streetwise, light-fingered, untrustworthy"
          (lambda () (list (make-item "Lockpicks")
                           (make-weapon "Dagger" 6)
                           (make-item "Dark Cloak")
                           (make-item "Grappling Hook")))
          0 8)
    (make-background "Pilgrim" "faithful, traveled, poor"
          (lambda () (list (make-weapon "Staff" 6)
                           (make-item "Holy Symbol")
                           (make-healing-herb 3 10)))
          0 8)
    (make-background "Hunter" "survivalist, patient, rural"
          (lambda () (list (make-weapon "Bow" 6)
                           (make-item "Arrows")
                           (make-weapon "Knife" 6)
                           (make-item "Snare Kit")
                           (make-item "Furs")))
          0 8)
    (make-background "Merchant" "wealthy, connected, soft"
          (lambda () (list (make-weapon "Dagger" 6)
                           (make-item "Fine Clothes")))
          0 38)))

(define (find-background name)
  (let loop ((bgs *backgrounds*))
    (cond
      ((null? bgs) nil)
      ((equal? (background-name (car bgs)) name) (car bgs))
      (else (loop (cdr bgs))))))

;;;
;;; Character Creation
;;;

(define (start)
  (text "Welcome to Dunge!")
  (choose ("Continue" (character-info))))

(define (character-info)
  (p "Character Creation")
  (if (character-name *player*)
      (begin
        (text "Welcome " (character-name *player*) "!")
        (choose ("Continue" (choose-background))))
      (begin
        (text "Let's gather some information about your character.")
        (ask "What is your name?"
             non-empty-string?
             (lambda (input)
               (set-character-name! *player* input)
               (character-info))))))

(define (choose-background)
  (p "Choose Your Background")
  (p "Your background determines your starting equipment and skills.")
  (let ((choices (map (lambda (bg)
                        (make-choice
                          (string-append (background-name bg) " - " (background-description bg))
                          (lambda ()
                            (set-character-background! *player* (background-name bg))
                            (roll-stats))))
                      *backgrounds*)))
    (newline)
    (display-choices choices)
    (let ((chosen (read-choice choices)))
      ((hash-ref chosen 'action)))))

(define (roll-stats)
  (p "Roll Ability Scores")
  (when (not (character-str *player*))
    (set-character-str! *player* (apply + (roll-dice 3 6)))
    (set-character-dex! *player* (apply + (roll-dice 3 6)))
    (set-character-wil! *player* (apply + (roll-dice 3 6))))
  (text "You rolled:")
  (text "  STR: " (character-str *player*))
  (text "  DEX: " (character-dex *player*))
  (p "  WIL: " (character-wil *player*))
  (text "You may swap two ability scores, or keep them as they are.")
  (let ((str (character-str *player*))
        (dex (character-dex *player*))
        (wil (character-wil *player*)))
    (choose
      ((fmt "Swap STR (" str ") and DEX (" dex ")")
       (begin (set-character-str! *player* dex)
              (set-character-dex! *player* str)
              (roll-hp)))
      ((fmt "Swap STR (" str ") and WIL (" wil ")")
       (begin (set-character-str! *player* wil)
              (set-character-wil! *player* str)
              (roll-hp)))
      ((fmt "Swap DEX (" dex ") and WIL (" wil ")")
       (begin (set-character-dex! *player* wil)
              (set-character-wil! *player* dex)
              (roll-hp)))
      ("Keep as they are" (roll-hp)))))

(define (roll-hp)
  (p "Roll Hit Points")
  (when (not (character-hp *player*))
    (let ((hp (roll-die 6)))
      (set-character-hp! *player* hp)
      (set-character-hp-max! *player* hp)))
  (text "Your hit points: " (character-hp *player*))
  (choose ("Continue" (equipment))))

(define (equipment)
  (p "Equipment")
  (when (null? (character-inventory *player*))
    (let* ((bg (find-background (character-background *player*)))
           (items (append ((background-equipment-thunk bg)) (base-equipment))))
      (set-character-inventory! *player* items)
      (set-character-armor! *player* (background-armor bg))
      (set-character-gold! *player* (background-gold bg))))
  (p "As a " (character-background *player*) " you receive:")
  (for-each (lambda (i)
              (display "  - ")
              (display (item-display-name i))
              (newline))
            (character-inventory *player*))
  (text "")
  (display (fmt "  Armor: " (character-armor *player*)))
  (newline)
  (display (fmt "  Gold:  " (character-gold *player*)))
  (newline)
  (text "")
  (choose ("Continue" (fate-points))))

(define (fate-points)
  (p "Fate Points")
  (when (not (character-fate *player*))
    (set-character-fate! *player* 2))
  (text "You begin with 2 Fate Points.")
  (text "Fate Points can be spent to narrowly avoid death or reroll a critical save.")
  (text "Use them wisely — they are hard to come by.")
  (choose ("Continue" (character-summary))))

(define (character-summary)
  (p "Character Summary")
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
  (text "")
  (choose ("Begin your adventure!" (town-square))))

;;;
;;; Town
;;;

(define (town-square)
  (p "Town Square")
  (text "This is the town square, the central hub of this very small, unnamed town.")
  (text "You see an adventure board here where the townsfolk have posted their bounties.")
  (text "Perfect for an adventurer like yourself.")
  (text "To the east you see smoke from the forge of the town blacksmith.")
  (choose
    ("Look at the Adventure Board" (adventure-board))
    ("Go to the blacksmith" (blacksmith))))

(define (adventure-board)
  (p "Adventure Board")
  (text "The board is covered in bounties and requests from the townsfolk.")
  (choose
    ("Hunt a Goblin (combat test)" (test-combat))
    ("Back" (town-square))))

;;;
;;; Test Combat Encounter
;;;

(define (test-combat)
  (p "The Forest Path")
  (let ((outcome (run-combat "Goblin"
                   (lambda () (text "A goblin leaps from the shadows, snarling!")))))
    (case outcome
      (victory (test-combat-victory))
      (death (test-combat-death))
      (incapacitated (test-combat-incapacitated))
      (fled (test-combat-fled)))))

(define (test-combat-victory)
  (p "Victory!")
  (text "The goblin lies defeated at your feet.")
  (text "You search the body and find a few coins.")
  (choose ("Return to town" (town-square))))

(define (test-combat-death)
  (p "You Died")
  (text "Your vision fades as you collapse...")
  (text "But fate intervenes — you awaken back in town, bruised but alive.")
  (choose ("Return to town" (town-square))))

(define (test-combat-incapacitated)
  (p "Incapacitated")
  (text "You fall unconscious from your wounds.")
  (text "A passing traveler finds you and drags you back to town.")
  (choose ("Return to town" (town-square))))

(define (test-combat-fled)
  (p "Escaped!")
  (text "You flee back to the safety of town, heart pounding.")
  (choose ("Return to town" (town-square))))

(define (blacksmith)
  (p "Blacksmith")
  (text "This is the blacksmith.")
  (choose ("Return to town square" (town-square))))
