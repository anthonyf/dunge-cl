;;; bestiary.scm — Enemy definitions for Dunge
;;; Each entry: (name hp armor attack-die str dex wil)

(define *bestiary*
  (list
    ;; Tier 1 — Shallow / Early Dungeon
    (list "Goblin"        4  0  6  8 12  8)
    (list "Skeleton"      5  1  6  8 13  0)
    (list "Zombie"        2  0  6 12  6  3)
    (list "Kobold"        3  0  6  8 13  4)
    (list "Bandit"        4  1  6 12 12  9)
    (list "Viper"         3  0  6  5 12  3)
    (list "Cave Locust"   2  0  6  6 12  3)
    (list "Acolyte"       4  1  6  8 11 14)
    ;; Tier 2 — Mid Dungeon
    (list "Gnoll"         6  1  8 12 14  8)
    (list "Hobgoblin"     6  2  8 14  8 11)
    (list "Bugbear"       8  1  8 14 12 11)
    (list "Ghoul"         6  0  8 14  8  3)
    (list "Ogre"          6  1 10 16  8  6)
    (list "Werewolf"      8  0  8 15 14  6)
    (list "Harpy"         8  0  8  7 12 14)
    (list "Rust Monster"  5  0  6 16 13  5)
    ;; Tier 3 — Deep Dungeon
    (list "Troll"        14  1 10 14 12  4)
    (list "Owlbear"       9  0 10 16 12  5)
    (list "Basilisk"     10  1 10 12 13 13)
    (list "Wight"        12  3 10 16  8 12)
    (list "Gargoyle"      8  3  8 14  4 12)
    (list "Minotaur"     12  1 10 16 12  8)
    (list "Wyvern"       11  0 10 15 14 13)
    (list "Vampire"      12  1 10 14 12 16)
    ;; Bosses
    (list "Green Dragon" 12  2 12 14 15 18)
    (list "Lich"         14  1  8  8  8 18)
    (list "Eye of Terror" 15 0  8  9  8 16)
    (list "Hydra"        12  2 12 13  7 12)
    (list "Mind Lasher"  12  0  8  8 12 18)
    (list "Purple Worm"  18  1 12 18  8  6)
    (list "Sphinx"       18  0 10 12 13 18)
    (list "Storm Giant"  18  2 12 18 16 18)
    (list "Titan"        18  3 12 16 15 18)))

(define (make-enemy-from-bestiary name)
  "Look up an enemy by name in the bestiary and create an enemy record."
  (let loop ((entries *bestiary*))
    (cond
      ((null? entries) (error (fmt "Unknown enemy: " name)))
      ((equal? (car (car entries)) name)
       (let ((e (car entries)))
         ;; (name hp armor attack-die str dex wil)
         (let ((hp (cadr e))
               (armor (caddr e))
               (attack-die (car (cddr (cdr e))))
               (str (car (cddr (cddr e))))
               (dex (car (cddr (cddr (cdr e)))))
               (wil (car (cddr (cddr (cddr e))))))
           (make-enemy name hp hp armor str dex wil attack-die))))
      (else (loop (cdr entries))))))
