;;; dice.scm — Dice rolling utilities

(define (roll-die sides)
  "Roll a single die with the given number of sides. Returns 1-sides."
  (+ 1 (random sides)))

(define (roll-dice n sides)
  "Roll n dice with the given number of sides. Returns a list of results."
  (let loop ((i 0) (results '()))
    (if (= i n)
        (reverse results)
        (loop (+ i 1) (cons (roll-die sides) results)))))
