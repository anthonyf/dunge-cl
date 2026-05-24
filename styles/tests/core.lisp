(in-package #:dunge-styles-tests)

(def-suite :dunge-styles-tests)
(in-suite :dunge-styles-tests)

(defun contains-substring-p (needle haystack)
  (not (null (search needle haystack :test #'char=))))

(defun run-styles-script (input)
  (let ((game (load-styles-game)))
    (with-output-to-string (output)
      (let ((*input* (make-string-input-stream input))
            (*output* output))
        (evaluate game)))))

(defun run-styles-launcher-script (input)
  (with-output-to-string (output)
    (let ((*input* (make-string-input-stream input))
          (*output* output))
      (play-styles))))

(defun lines (&rest choices)
  (with-output-to-string (stream)
    (dolist (choice choices)
      (format stream "~A~%" choice))))

(defparameter *styles-shared-investigation-script*
  (lines
   ;; Station.
   1 1 1 1
   ;; Road to Styles: Emily, Alfred, arrive.
   1 1 1
   ;; Tea table: Evelyn, Cynthia, Mary, retire.
   1 1 1 1
   ;; Night crisis: force door, bell, Cynthia, bedroom.
   1 1 1 1
   ;; Bedroom: collect five clues, then servants.
   1 1 1 1 1 1
   ;; Servants: collect three testimony clues, then Poirot.
   1 1 1 1
   ;; Poirot to chemist.
   2
   ;; Chemist: sale, time, description, return.
   1 1 1 1
   ;; Poirot to dispensary.
   3
   ;; Dispensary: bromides, taste, final-dose, return.
   1 1 1 1))

(test styles-game-loads-with-room-catalog
  (let ((game (load-styles-game)))
    (is (typep game 'game))
    (is (equal "station" (game-start game)))
    (is (equal '("station"
                 "village-road"
                 "tea-table"
                 "night-crisis"
                 "bedroom"
                 "servants-hall"
                 "poirot"
                 "suspect-board"
                 "chemist"
                 "dispensary"
                 "final-drawing-room"
                 "ending-player-led"
                 "ending-poirot-led"
                 "ending-wrong-accusation")
               (mapcar #'name (game-rooms game))))))

(test styles-wrong-accusation-ending-is-playable
  (let ((output
          (run-styles-script
           (lines
            ;; Station, road, then skip tea interviews and retire.
            4 3 4
            ;; Force door, enter bedroom, take evidence to Poirot.
            1 3 7
            ;; Begin final reconstruction, accuse John.
            4 1))))
    (is (contains-substring-p "Wrong Accusation" output))
    (is (contains-substring-p "Rank: Misled." output))))

(test styles-launcher-pauses-after-say
  (let ((output
          (run-styles-launcher-script
           (lines
            ;; Station, road, Evelyn, continue, then retire.
            4 3 1 "" 3))))
    (is (contains-substring-p "Press Enter to continue." output))))

(test styles-poirot-led-ending-is-playable
  (let ((output
          (run-styles-script
           (concatenate
            'string
            *styles-shared-investigation-script*
            (lines
             ;; Deduce medicine, deduce staged purchase, final, ask Poirot.
             4 4 5 1)))))
    (is (contains-substring-p "Poirot-Led Solution" output))
    (is (contains-substring-p "Rank: Assisted." output))))

(test styles-player-led-ending-is-playable
  (let ((output
          (run-styles-script
           (concatenate
            'string
            *styles-shared-investigation-script*
            (lines
             ;; Deduce medicine, staged purchase, Alfred trap, Evelyn link,
             ;; final, accuse both culprits.
             4 4 4 4 4 1)))))
    (is (contains-substring-p "Player-Led Solution" output))
    (is (contains-substring-p "Rank: Brilliant." output))))
