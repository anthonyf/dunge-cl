(in-package #:dunge)

;;; Tier 1 — Shallow / Early Dungeon

(defun make-goblin ()
  (list "Goblin" 4 0 6 :str 8 :dex 12 :wil 8))

(defun make-skeleton ()
  (list "Skeleton" 5 1 6 :str 8 :dex 13 :wil 0))

(defun make-zombie ()
  (list "Zombie" 2 0 6 :str 12 :dex 6 :wil 3))

(defun make-kobold ()
  (list "Kobold" 3 0 6 :str 8 :dex 13 :wil 4))

(defun make-bandit ()
  (list "Bandit" 4 1 6 :str 12 :dex 12 :wil 9))

(defun make-viper ()
  (list "Viper" 3 0 6 :str 5 :dex 12 :wil 3))

(defun make-cave-locust ()
  (list "Cave Locust" 2 0 6 :str 6 :dex 12 :wil 3))

(defun make-acolyte ()
  (list "Acolyte" 4 1 6 :str 8 :dex 11 :wil 14))

;;; Tier 2 — Mid Dungeon

(defun make-gnoll ()
  (list "Gnoll" 6 1 8 :str 12 :dex 14 :wil 8))

(defun make-hobgoblin ()
  (list "Hobgoblin" 6 2 8 :str 14 :dex 8 :wil 11))

(defun make-bugbear ()
  (list "Bugbear" 8 1 8 :str 14 :dex 12 :wil 11))

(defun make-ghoul ()
  (list "Ghoul" 6 0 8 :str 14 :dex 8 :wil 3))

(defun make-ogre ()
  (list "Ogre" 6 1 10 :str 16 :dex 8 :wil 6))

(defun make-werewolf ()
  (list "Werewolf" 8 0 8 :str 15 :dex 14 :wil 6))

(defun make-harpy ()
  (list "Harpy" 8 0 8 :str 7 :dex 12 :wil 14))

(defun make-rust-monster ()
  (list "Rust Monster" 5 0 6 :str 16 :dex 13 :wil 5))

;;; Tier 3 — Deep Dungeon

(defun make-troll ()
  (list "Troll" 14 1 10 :str 14 :dex 12 :wil 4))

(defun make-owlbear ()
  (list "Owlbear" 9 0 10 :str 16 :dex 12 :wil 5))

(defun make-basilisk ()
  (list "Basilisk" 10 1 10 :str 12 :dex 13 :wil 13))

(defun make-wight ()
  (list "Wight" 12 3 10 :str 16 :dex 8 :wil 12))

(defun make-gargoyle ()
  (list "Gargoyle" 8 3 8 :str 14 :dex 4 :wil 12))

(defun make-minotaur ()
  (list "Minotaur" 12 1 10 :str 16 :dex 12 :wil 8))

(defun make-wyvern ()
  (list "Wyvern" 11 0 10 :str 15 :dex 14 :wil 13))

(defun make-vampire ()
  (list "Vampire" 12 1 10 :str 14 :dex 12 :wil 16))

;;; Bosses

(defun make-green-dragon ()
  (list "Green Dragon" 12 2 12 :str 14 :dex 15 :wil 18))

(defun make-lich ()
  (list "Lich" 14 1 8 :str 8 :dex 8 :wil 18))

(defun make-eye-of-terror ()
  (list "Eye of Terror" 15 0 8 :str 9 :dex 8 :wil 16))

(defun make-hydra ()
  (list "Hydra" 12 2 12 :str 13 :dex 7 :wil 12))

(defun make-mind-lasher ()
  (list "Mind Lasher" 12 0 8 :str 8 :dex 12 :wil 18))

(defun make-purple-worm ()
  (list "Purple Worm" 18 1 12 :str 18 :dex 8 :wil 6))

(defun make-sphinx ()
  (list "Sphinx" 18 0 10 :str 12 :dex 13 :wil 18))

(defun make-storm-giant ()
  (list "Storm Giant" 18 2 12 :str 18 :dex 16 :wil 18))

(defun make-titan ()
  (list "Titan" 18 3 12 :str 16 :dex 15 :wil 18))
