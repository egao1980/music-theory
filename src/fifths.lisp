;;;; MT0 line of fifths. Every spelled pitch class has an integer position:
;;;;   F -1, C 0, G 1, D 2, A 3, E 4, B 5, and each sharp adds 7, each flat
;;;;   subtracts 7 (F# 6, Bb -2, Fbb -15, B## 19).
;;;; Keys, spelling and enharmonic choice in later slices all measure distance
;;;; on this line.

(in-package #:music-theory)

(defparameter +letter-fifths+ #(0 2 4 -1 1 3 5)
  "Line-of-fifths position of each natural letter, in letter order C D E F G A B.")

(defun pitch-fifths (pitch-or-class)
  "Line-of-fifths position of a SPELLED-PITCH or PITCH-CLASS-NAME."
  (multiple-value-bind (letter alter) (%letter-alter pitch-or-class)
    (+ (aref +letter-fifths+ letter) (* 7 alter))))

(defun fifths-pitch-class (fifths)
  "The PITCH-CLASS-NAME at line-of-fifths position FIFTHS. Positions outside
-15..19 need more than two accidentals and signal INVALID-PITCH (TEXT NIL)."
  (check-type fifths integer)
  (unless (<= -15 fifths 19)
    (error 'invalid-pitch :reason "needs more than two accidentals"))
  ;; FIFTHS + 1 = 7 * ALTER + OFFSET, where OFFSET 0..6 runs F C G D A E B,
  ;; i.e. the natural letter's position is OFFSET - 1.
  (multiple-value-bind (alter offset) (floor (1+ fifths) 7)
    (make-pitch-class-name :letter (position (1- offset) +letter-fifths+)
                           :alter alter)))
