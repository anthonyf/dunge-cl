;;; bestiary.scm — Enemy definitions for Dunge

(define-record bestiary-entry name hp armor attack-die str dex wil)

(define *bestiary*
  (list
    ;; Tier 1 — Shallow / Early Dungeon
    (make-bestiary-entry "Goblin"        4  0  6  8 12  8)
    (make-bestiary-entry "Skeleton"      5  1  6  8 13  0)
    (make-bestiary-entry "Zombie"        2  0  6 12  6  3)
    (make-bestiary-entry "Kobold"        3  0  6  8 13  4)
    (make-bestiary-entry "Bandit"        4  1  6 12 12  9)
    (make-bestiary-entry "Viper"         3  0  6  5 12  3)
    (make-bestiary-entry "Cave Locust"   2  0  6  6 12  3)
    (make-bestiary-entry "Acolyte"       4  1  6  8 11 14)
    ;; Tier 2 — Mid Dungeon
    (make-bestiary-entry "Gnoll"         6  1  8 12 14  8)
    (make-bestiary-entry "Hobgoblin"     6  2  8 14  8 11)
    (make-bestiary-entry "Bugbear"       8  1  8 14 12 11)
    (make-bestiary-entry "Ghoul"         6  0  8 14  8  3)
    (make-bestiary-entry "Ogre"          6  1 10 16  8  6)
    (make-bestiary-entry "Werewolf"      8  0  8 15 14  6)
    (make-bestiary-entry "Harpy"         8  0  8  7 12 14)
    (make-bestiary-entry "Rust Monster"  5  0  6 16 13  5)
    ;; Tier 3 — Deep Dungeon
    (make-bestiary-entry "Troll"        14  1 10 14 12  4)
    (make-bestiary-entry "Owlbear"       9  0 10 16 12  5)
    (make-bestiary-entry "Basilisk"     10  1 10 12 13 13)
    (make-bestiary-entry "Wight"        12  3 10 16  8 12)
    (make-bestiary-entry "Gargoyle"      8  3  8 14  4 12)
    (make-bestiary-entry "Minotaur"     12  1 10 16 12  8)
    (make-bestiary-entry "Wyvern"       11  0 10 15 14 13)
    (make-bestiary-entry "Vampire"      12  1 10 14 12 16)
    ;; Bosses
    (make-bestiary-entry "Green Dragon" 12  2 12 14 15 18)
    (make-bestiary-entry "Lich"         14  1  8  8  8 18)
    (make-bestiary-entry "Eye of Terror" 15 0  8  9  8 16)
    (make-bestiary-entry "Hydra"        12  2 12 13  7 12)
    (make-bestiary-entry "Mind Lasher"  12  0  8  8 12 18)
    (make-bestiary-entry "Purple Worm"  18  1 12 18  8  6)
    (make-bestiary-entry "Sphinx"       18  0 10 12 13 18)
    (make-bestiary-entry "Storm Giant"  18  2 12 18 16 18)
    (make-bestiary-entry "Titan"        18  3 12 16 15 18)))

(define (make-enemy-from-bestiary name)
  "Look up an enemy by name in the bestiary and create an enemy record."
  (let loop ((entries *bestiary*))
    (cond
      ((null? entries) (error "Unknown enemy: $name"))
      ((equal? (bestiary-entry-name (car entries)) name)
       (let ((e (car entries)))
         (make-enemy name
                     (bestiary-entry-hp e)
                     (bestiary-entry-hp e)
                     (bestiary-entry-armor e)
                     (bestiary-entry-str e)
                     (bestiary-entry-dex e)
                     (bestiary-entry-wil e)
                     (bestiary-entry-attack-die e))))
      (else (loop (cdr entries))))))
