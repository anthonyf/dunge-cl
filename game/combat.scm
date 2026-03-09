;;; combat.scm — Cairn combat system for Dunge
;;; Provides enemy/encounter records, attack resolution, saves, healing, fleeing,
;;; combat log formatting, encounter state machine, and combat choices.

;;;
;;; Ability Saves
;;;

(define (str-save target)
  "STR save: roll d20 <= target's STR to pass."
  (<= (roll-d20) (hash-ref target 'str)))

(define (dex-save target)
  "DEX save: roll d20 <= target's DEX to pass."
  (<= (roll-d20) (hash-ref target 'dex)))

(define (wil-save target)
  "WIL save: roll d20 <= target's WIL to pass."
  (<= (roll-d20) (hash-ref target 'wil)))

;;;
;;; Enemy and Encounter Records
;;;

(define-record enemy name hp hp-max armor str dex wil attack-die)

(define-record encounter enemy first-round log state)

;;;
;;; Global Encounter State
;;;

(define *current-encounter* nil)

(define (setup-encounter enemy-record)
  "Set up a new combat encounter with the given enemy record."
  (set *current-encounter*
       (make-encounter enemy-record t nil 'active)))

(define (clear-encounter)
  "Clear the current encounter."
  (set *current-encounter* nil))

;;;
;;; Attack Resolution
;;;

(define (resolve-attack attacker-die target)
  "Resolve an attack against TARGET. Roll damage die, subtract armor, apply to HP,
   spillover to STR. Returns hash table with damage/str-damage/critical-save/dead."
  (let* ((roll (roll-die attacker-die))
         (armor (hash-ref target 'armor))
         (damage (max 0 (- roll armor)))
         (hp (hash-ref target 'hp))
         (hp-damage (min damage hp))
         (remainder (- damage hp-damage))
         (str-damage 0)
         (critical-save 'none)
         (dead nil))
    ;; Apply HP damage
    (hash-set! target 'hp (- hp hp-damage))
    ;; Spillover to STR
    (when (> remainder 0)
      (set str-damage remainder)
      (let ((new-str (max 0 (- (hash-ref target 'str) remainder))))
        (hash-set! target 'str new-str)
        (if (= new-str 0)
            (set dead t)
            (set critical-save (str-save target)))))
    (hash-table 'damage hp-damage
                'str-damage str-damage
                'critical-save critical-save
                'dead dead)))

(define (resolve-player-attack damage-die)
  "Resolve player attack against current encounter enemy."
  (resolve-attack damage-die (encounter-enemy *current-encounter*)))

(define (resolve-enemy-attack)
  "Resolve enemy attack against player."
  (resolve-attack (enemy-attack-die (encounter-enemy *current-encounter*)) *player*))

;;;
;;; Heal and Flee
;;;

(define (resolve-heal)
  "Restore player HP to max. Returns hash table with healed/old-hp/new-hp."
  (let ((old-hp (character-hp *player*))
        (max-hp (character-hp-max *player*)))
    (set-character-hp! *player* max-hp)
    (hash-table 'healed (- max-hp old-hp)
                'old-hp old-hp
                'new-hp max-hp)))

(define (resolve-flee)
  "Attempt to flee. DEX save; on fail, enemy gets a parting blow.
   Returns hash table with success and enemy-result."
  (if (dex-save *player*)
      (hash-table 'success t 'enemy-result nil)
      (hash-table 'success nil 'enemy-result (resolve-enemy-attack))))

;;;
;;; Combat Log Formatting
;;;

(define (format-attack-lines result glance-msg damage-prefix damage-suffix
                             critical-prefix critical-suffix
                             dead-msg fail-msg endure-msg)
  "Return a list of strings describing an attack from result hash table."
  (let ((lines '())
        (dmg (hash-ref result 'damage))
        (str-dmg (hash-ref result 'str-damage))
        (crit (hash-ref result 'critical-save))
        (dead (hash-ref result 'dead)))
    (if (and (= dmg 0) (= str-dmg 0))
        (list glance-msg)
        (begin
          (when (> dmg 0)
            (set lines (cons (fmt damage-prefix dmg damage-suffix) lines)))
          (when (> str-dmg 0)
            (set lines (cons (fmt critical-prefix str-dmg critical-suffix) lines))
            (cond
              (dead (set lines (cons dead-msg lines)))
              ((eq? crit nil) (set lines (cons fail-msg lines)))
              ((eq? crit t) (set lines (cons endure-msg lines)))))
          (reverse lines)))))

(define (format-player-attack-lines result)
  "Return a list of strings describing the player's attack."
  (format-attack-lines result
    "Your attack glances off harmlessly."
    "You deal " " damage."
    "A critical blow! " " STR damage!"
    "The enemy collapses, dead!"
    "The enemy fails its STR save and is slain!"
    "The enemy endures the wound."))

(define (format-enemy-attack-lines result)
  "Return a list of strings describing the enemy's attack."
  (format-attack-lines result
    "The enemy's attack glances off harmlessly."
    "The enemy deals " " damage."
    "A devastating hit! " " STR damage!"
    "You collapse. Your wounds are fatal."
    "You fail your STR save and fall unconscious!"
    "You grit your teeth and endure."))

(define (join-lines lines)
  "Join a list of strings with spaces."
  (if (null? lines)
      ""
      (let loop ((rest (cdr lines)) (acc (car lines)))
        (if (null? rest)
            acc
            (loop (cdr rest) (fmt acc " " (car rest)))))))

(define (format-combat-log player-result enemy-result)
  "Build a combat log string from attack result hash tables."
  (join-lines (append (format-player-attack-lines player-result)
                      (format-enemy-attack-lines enemy-result))))

(define (format-heal-log heal-result enemy-result)
  "Build a log string for a heal + enemy attack round."
  (let ((healed (hash-ref heal-result 'healed))
        (hp (hash-ref heal-result 'new-hp))
        (enemy-lines (format-enemy-attack-lines enemy-result)))
    (join-lines (cons "You use Healing Herbs and restore $healed HP. ($hp/$hp)"
                      enemy-lines))))

(define (format-flee-log flee-result)
  "Build a log string for a flee attempt."
  (if (hash-ref flee-result 'success)
      "You turn and flee! You escape cleanly."
      (join-lines
        (cons "You try to flee but the enemy lands a parting blow!"
              (format-enemy-attack-lines
                (hash-ref flee-result 'enemy-result))))))

;;;
;;; Encounter State Machine
;;;

(define (update-encounter-state enc player-attack-result enemy-attack-result fled)
  "Determine and set encounter state from round results.
   Priority: victory > death > incapacitated > fled > active."
  (set-encounter-state! enc
    (cond
      ;; Enemy killed (STR=0 or failed STR save)
      ((and player-attack-result
            (or (hash-ref player-attack-result 'dead)
                (and (not (eq? (hash-ref player-attack-result 'critical-save) 'none))
                     (not (hash-ref player-attack-result 'critical-save)))))
       'victory)
      ;; Player dead (STR=0)
      ((and enemy-attack-result (hash-ref enemy-attack-result 'dead))
       'death)
      ;; Player incapacitated (failed STR save)
      ((and enemy-attack-result
            (not (hash-ref enemy-attack-result 'dead))
            (not (eq? (hash-ref enemy-attack-result 'critical-save) 'none))
            (not (hash-ref enemy-attack-result 'critical-save)))
       'incapacitated)
      ;; Fled
      (fled 'fled)
      ;; Still fighting
      (else 'active))))

(define (combat-choices)
  "Build combat choices from *player* inventory. Returns a list of choices."
  (let ((choices '())
        (has-weapon nil))
    ;; Scan inventory for usable items
    (for-each
      (lambda (it)
        (when (usable? it)
          (cond
            ;; Weapon -> attack
            ((weapon? it)
             (set has-weapon t)
             (set choices
               (cons (make-choice
                       (item-use-label it)
                       (lambda ()
                         (let* ((enc *current-encounter*)
                                (player-result (resolve-player-attack (weapon-damage-die it)))
                                (enemy-result (resolve-enemy-attack)))
                           (update-encounter-state enc player-result enemy-result nil)
                           (set-encounter-log! enc
                             (format-combat-log player-result enemy-result)))))
                     choices)))
            ;; Healing herb -> consume + enemy attacks
            ((healing-herb? it)
             (set choices
               (cons (make-choice
                       (item-use-label it)
                       (lambda ()
                         (let* ((enc *current-encounter*)
                                (heal-result (resolve-heal))
                                (enemy-result (resolve-enemy-attack)))
                           (set-character-inventory! *player*
                             (consume-item it (character-inventory *player*)))
                           (update-encounter-state enc nil enemy-result nil)
                           (set-encounter-log! enc
                             (format-heal-log heal-result enemy-result))))
                       ;; Guard: only show if HP < max
                       (lambda ()
                         (< (character-hp *player*) (character-hp-max *player*))))
                     choices))))))
      (character-inventory *player*))
    ;; Unarmed fallback
    (when (not has-weapon)
      (set choices
        (cons (make-choice
                "Unarmed Attack (d4)"
                (lambda ()
                  (let* ((enc *current-encounter*)
                         (player-result (resolve-player-attack 4))
                         (enemy-result (resolve-enemy-attack)))
                    (update-encounter-state enc player-result enemy-result nil)
                    (set-encounter-log! enc
                      (format-combat-log player-result enemy-result)))))
              choices)))
    ;; Flee (always available)
    (set choices
      (cons (make-choice
              "Flee"
              (lambda ()
                (let* ((enc *current-encounter*)
                       (flee-result (resolve-flee)))
                  (update-encounter-state enc nil
                    (hash-ref flee-result 'enemy-result) t)
                  (set-encounter-log! enc
                    (format-flee-log flee-result)))))
            choices))
    (reverse choices)))

(define (cleanup-combat state)
  "Reset player stats after combat ends if needed."
  (when (or (eq? state 'death) (eq? state 'incapacitated))
    (set-character-hp! *player* (character-hp-max *player*))
    (set-character-str! *player* 10))
  (clear-encounter))

;;;
;;; Run Combat — self-contained encounter loop
;;;

(define (run-combat name intro-fn)
  "Run a complete combat encounter. Returns the outcome state symbol
   (victory, death, incapacitated, or fled)."
  (setup-encounter (make-enemy-from-bestiary name))
  (when intro-fn (intro-fn))
  ;; First-round DEX save
  (let ((enc *current-encounter*))
    (set-encounter-first-round! enc nil)
    (if (dex-save *player*)
        (begin (display "You react quickly!") (newline))
        (let* ((enemy-result (resolve-enemy-attack))
               (lines (cons "Caught off guard! The enemy strikes first."
                            (format-enemy-attack-lines enemy-result))))
          (display (join-lines lines))
          (newline)
          (update-encounter-state enc nil enemy-result nil))))
  ;; Combat loop
  (let loop ()
    (let* ((enc *current-encounter*)
           (state (encounter-state enc)))
      ;; Drain combat log
      (when (encounter-log enc)
        (display (encounter-log enc))
        (newline)
        (set-encounter-log! enc nil))
      (if (eq? state 'active)
          ;; Show stats + combat menu
          (let ((e (encounter-enemy enc)))
            (display (lines
              "  $(enemy-name e) HP: $(enemy-hp e)/$(enemy-hp-max e)  STR: $(enemy-str e)"
              "  Your HP: $(character-hp *player*)/$(character-hp-max *player*)  STR: $(character-str *player*)"
              ""))
            (let ((choices (filter choice-visible? (combat-choices))))
              (display-choices choices)
              (let ((chosen (read-choice choices)))
                ((hash-ref chosen 'action))))
            (loop))
          ;; Terminal state
          (begin
            (cleanup-combat state)
            state)))))
