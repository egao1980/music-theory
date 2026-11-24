;;;; MT4 transposition between keys, and the choice between enharmonic keys.
;;;;
;;;; TRANSPOSE-TO-KEY pitch from-key to-key → PITCH moved from FROM-KEY to TO-KEY,
;;;; spelled for TO-KEY: its scale degree and alteration are kept (F#4 in C major
;;;; is G#4 in D major, G4 in Db major, F##4 in C# major).
;;;;   PITCH     a SPELLED-PITCH, or a PITCH-CLASS-NAME (the result is then a
;;;;             PITCH-CLASS-NAME); FROM-KEY and TO-KEY any two KEYs. Anything
;;;;             else is a TYPE-ERROR.
;;;;   Interval  the one from FROM's tonic, placed in octave 4, to TO's tonic
;;;;             placed so the letter moves at most three steps up or down
;;;;             (INTERVAL-STEPS -3..3). C to G is a perfect fourth down, C to F
;;;;             a perfect fourth up, C to F# an augmented fourth up, C to Gb an
;;;;             augmented fourth down, C# to Db a diminished second up (the
;;;;             same MIDI number), D to Db one semitone down on the same letter
;;;;             (steps 0, semitones -1). The result is
;;;;             (TRANSPOSE-PITCH pitch interval); for a PITCH-CLASS-NAME, its
;;;;             class: the line-of-fifths position moves by
;;;;             (- (pitch-fifths to-tonic) (pitch-fifths from-tonic)).
;;;;   The modes play no part, as in TRANSPOSE-CHORD-SYMBOL with two keys: only
;;;;   the tonics move the pitch, so E4 from C major to A minor is C#4.
;;;;   Because the letter moves at most three steps either way, the move back is
;;;;   its exact inverse: (transpose-to-key (transpose-to-key p a b) b a) is
;;;;   EQUALP to p. A result beyond two accidentals signals INVALID-PITCH (TEXT
;;;;   NIL), as TRANSPOSE-PITCH does.
;;;;   For every chord symbol C and keys A and B, the root and bass of
;;;;   (transpose-chord-symbol c (list a b)) are those of TRANSPOSE-TO-KEY:
;;;;   chord symbols transpose and respell the same way as notes.
;;;;
;;;; CHOOSE-ENHARMONIC-KEY key &key (max-accidentals 6) prefer → one of the 30
;;;; keys that sounds like KEY, written with at most MAX-ACCIDENTALS sharps or
;;;; flats when it can be.
;;;;   KEY             any KEY, also one beyond seven sharps or flats (G# major).
;;;;   MAX-ACCIDENTALS an integer 0..7; else TYPE-ERROR.
;;;;   PREFER          NIL, :SHARPS or :FLATS; else TYPE-ERROR.
;;;; The equivalents E of KEY are KEY itself and the keys of its mode whose
;;;; tonic's line-of-fifths position differs from KEY's by a multiple of 12 and
;;;; whose KEY-SIGNATURE (unchecked: tonic + mode offset) lies in -7..7: C#
;;;; major and Db major; F# major and Gb major; G# major and Ab major; D major
;;;; alone. The choice:
;;;;   1. C is the members of E with at most MAX-ACCIDENTALS accidentals (the
;;;;      absolute value of the signature) or, when there are none, the members
;;;;      with the fewest accidentals.
;;;;   2. One member: that key. Two: :SHARPS takes the one with the larger
;;;;      signature, :FLATS the smaller; with PREFER NIL, KEY if it is one of
;;;;      them, else the one whose signature is nearer KEY's.
;;;; So, with the defaults: C# major → Db major, Cb major → B major, A# minor →
;;;; Bb minor, Ab minor → G# minor, G# major → Ab major; F# and Gb major, D# and
;;;; Eb minor and every key with at most six accidentals are returned as given.
;;;; With :MAX-ACCIDENTALS 7, C# major stays; with :PREFER :FLATS, F# major is
;;;; Gb major; with :MAX-ACCIDENTALS 4, B major stays (Cb major has seven). E
;;;; always holds one of the 30 keys, so the result is always one of them.

(in-package #:music-theory)

(defun %tonic-interval (from-tonic to-tonic)
  "The interval from FROM-TONIC (a PITCH-CLASS-NAME) placed in octave 4 to TO-TONIC
placed so the letter moves -3..3 steps (the file header)."
  (let* ((start (make-spelled-pitch :letter (pitch-class-name-letter from-tonic)
                                    :alter (pitch-class-name-alter from-tonic)
                                    :octave 4))
         ;; (l_to - l_from) mod 7, with 4 5 6 mapped to -3 -2 -1.
         (steps (- (mod (+ 3 (- (pitch-class-name-letter to-tonic)
                                (pitch-class-name-letter from-tonic)))
                        7)
                   3)))
    (multiple-value-bind (octave letter) (floor (+ (pitch-diatonic-index start) steps) 7)
      (interval-between start (make-spelled-pitch :letter letter
                                                  :alter (pitch-class-name-alter to-tonic)
                                                  :octave octave)))))

(defun transpose-to-key (pitch from-key to-key)
  "PITCH moved from FROM-KEY's tonic to TO-KEY's, the letter moving at most three
steps (see the file header)."
  (check-type pitch (or spelled-pitch pitch-class-name))
  (check-type from-key key)
  (check-type to-key key)
  (etypecase pitch
    (spelled-pitch
     (transpose-pitch pitch (%tonic-interval (key-tonic from-key) (key-tonic to-key))))
    (pitch-class-name
     ;; The shift TRANSPOSE-CHORD-SYMBOL uses for two keys, so roots and basses agree.
     (fifths-pitch-class (+ (pitch-fifths pitch)
                            (%transposition-shift (list from-key to-key)))))))

(defun choose-enharmonic-key (key &key (max-accidentals 6) prefer)
  "The enharmonic equivalent of KEY written with at most MAX-ACCIDENTALS sharps or
flats, PREFER (:SHARPS, :FLATS or NIL) breaking a tie (see the file header). KEY
itself is returned when it is the choice."
  (check-type key key)
  (check-type max-accidentals (integer 0 7))
  (check-type prefer (member nil :sharps :flats))
  ;; The members of E as signatures. KEY's own, SIGNATURE, may lie beyond -7..7; then
  ;; it never enters C, since E's in-range members have fewer accidentals. So C is
  ;; drawn from the in-range signatures congruent to SIGNATURE mod 12 (one or two,
  ;; ascending), which include SIGNATURE when it is in range.
  (let* ((signature (%signature-fifths key))
         (low (- (mod (+ signature 7) 12) 7)) ; -7..4
         (in-range (if (<= (+ low 12) 7) (list low (+ low 12)) (list low)))
         (fewest (reduce #'min in-range :key #'abs))
         ;; Step 1.
         (c (or (remove-if (lambda (s) (> (abs s) max-accidentals)) in-range)
                (remove-if (lambda (s) (/= (abs s) fewest)) in-range)))
         ;; Step 2.
         (choice (cond ((null (rest c)) (first c))
                       ((eq prefer :sharps) (second c))
                       ((eq prefer :flats) (first c))
                       ((member signature c) signature)
                       ((< (abs (- (first c) signature)) (abs (- (second c) signature)))
                        (first c))
                       (t (second c)))))
    (if (= choice signature)
        key
        (make-key :tonic (fifths-pitch-class (+ (pitch-fifths (key-tonic key))
                                                (- choice signature)))
                  :mode (key-mode key)))))
