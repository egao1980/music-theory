;;;; MT0: spelled pitches, line of fifths, intervals.
;;;; Fixture vectors come from music21 10.5.2 (tests/fixtures/PROVENANCE.md).

(in-package #:music-theory/tests)

(defun p (s) (parse-pitch s))
(defun i (s) (parse-interval s))

;;; Pitches ------------------------------------------------------------------

(deftest pitch-fixtures
  (let* ((rows (fixture "mt0-pitches.sexp"))
         (bad (collect-mismatches (row rows)
                (destructuring-bind (name midi fifths pc) row
                  (declare (ignore fifths pc))
                  (= midi (pitch-midi (p name))))
                (destructuring-bind (name midi fifths pc) row
                  (declare (ignore midi pc))
                  (= fifths (pitch-fifths (p name))))
                (destructuring-bind (name midi fifths pc) row
                  (declare (ignore midi fifths))
                  (= pc (pitch-class (p name))))
                (string= (first row) (pitch-name (p (first row)))))))
    (ok (= 315 (length rows)))
    (ok (null bad) (report bad))))

(deftest-parametrize parse-pitch-accepts
    ((text letter alter octave)
     ("F#4" 3 1 4) ("f#4" 3 1 4) ("Eb4" 2 -1 4) ("E♭4" 2 -1 4) ("C♯4" 0 1 4)
     ("Cx5" 0 2 5) ("C𝄪5" 0 2 5) ("C##5" 0 2 5) ("C♯♯5" 0 2 5)
     ("Bbb3" 6 -2 3) ("B𝄫3" 6 -2 3) ("B♭♭3" 6 -2 3)
     ("C-1" 0 0 -1) ("B-1" 6 0 -1) ("Cb-1" 0 -1 -1) ("G9" 4 0 9) ("  A4 " 5 0 4))
  (ok (equalp (make-spelled-pitch :letter letter :alter alter :octave octave)
              (parse-pitch text))))

(deftest-parametrize parse-pitch-rejects
    ((text)
     ("") ("H4") ("C") ("C#") ("Cbbb4") ("C#b4") ("4") ("C4x") ("C10") ("C-2")
     ("Cmaj7") ("C 4") ("#C4"))
  (ok (signals-with-text (lambda () (parse-pitch text)) 'invalid-pitch text)))

(deftest pitch-parse-error-is-not-a-chord-error
  (ok (eq :pitch
          (handler-case (parse-pitch "Cmaj7")
            (chord-symbol-parse-error () :chord)
            (invalid-pitch () :pitch)))))

(deftest parse-pitch-use-value-restart
  (let ((fallback (make-spelled-pitch :letter 0 :alter 0 :octave 4)))
    (ok (equalp fallback
                (handler-bind ((invalid-pitch (lambda (c) (use-value fallback c))))
                  (parse-pitch "H4"))))
    (ok (equalp (make-pitch-class-name :letter 0)
                (handler-bind ((invalid-pitch
                                 (lambda (c) (use-value (make-pitch-class-name :letter 0) c))))
                  (parse-pitch-class "H"))))))

(deftest-parametrize pitch-name-unicode
    ((text expected)
     ("F#4" "F♯4") ("Bbb3" "B𝄫3") ("C##5" "C𝄪5") ("Eb4" "E♭4") ("A4" "A4"))
  (ok (string= expected (pitch-name (p text) :accidentals :unicode))))

(deftest enharmonics-are-not-equal
  (ok (not (equalp (p "F#4") (p "Gb4"))))
  (ok (pitch-enharmonic-p (p "F#4") (p "Gb4")))
  (ok (pitch-enharmonic-p (p "B#3") (p "C4")))
  (ok (= 60 (pitch-midi (p "B#3")) (pitch-midi (p "C4"))))
  (ok (= 59 (pitch-midi (p "Cb4"))))
  (ok (= 11 (pitch-class (p "Cb4"))))
  (ok (not (pitch-enharmonic-p (p "E#4") (p "E4"))))
  (ok (pitch-enharmonic-p (parse-pitch-class "E#") (parse-pitch-class "F")))
  (ok (not (pitch-enharmonic-p (p "C4") (p "C5")))))

(deftest pitch-classes
  (ok (= 6 (pitch-fifths (parse-pitch-class "F#"))))
  (ok (= -2 (pitch-fifths (parse-pitch-class "Bb"))))
  (ok (= 10 (pitch-class (parse-pitch-class "Bb"))))
  (ok (equalp (parse-pitch-class "F#") (pitch-spelling (p "F#4"))))
  (ok (string= "Bb" (pitch-class-string (parse-pitch-class "B♭"))))
  (ok (string= "F♯" (pitch-class-string (parse-pitch-class "F#") :accidentals :unicode)))
  (ok (= 28 (pitch-diatonic-index (p "C4"))))
  (ok (= 27 (pitch-diatonic-index (p "B#3"))))
  (ok (signals-with-text (lambda () (parse-pitch-class "C4")) 'invalid-pitch "C4")))

(deftest-parametrize fifths-positions
    ((fifths name)
     (0 "C") (1 "G") (-1 "F") (6 "F#") (-2 "Bb") (7 "C#") (-7 "Cb")
     (13 "B#") (19 "B##") (-15 "Fbb") (14 "F##") (-8 "Fb"))
  (ok (equalp (parse-pitch-class name) (fifths-pitch-class fifths))))

(deftest fifths-round-trip-and-range
  (ok (loop for f from -15 to 19 always (= f (pitch-fifths (fifths-pitch-class f)))))
  (ok (typep (handler-case (fifths-pitch-class 20) (condition (c) c)) 'invalid-pitch))
  (ok (typep (handler-case (fifths-pitch-class -16) (condition (c) c)) 'invalid-pitch)))

(deftest values-are-immutable-and-readable
  (ok (not (fboundp '(setf spelled-pitch-letter))))
  (ok (not (fboundp '(setf interval-steps))))
  (ok (not (fboundp '(setf pitch-class-name-alter))))
  (let ((*package* (find-package '#:music-theory/tests)))
    (dolist (x (list (p "F#4") (parse-pitch-class "Bb") (i "-m3")))
      (ok (equalp x (read-from-string (prin1-to-string x)))))))

;;; Intervals -----------------------------------------------------------------

(deftest interval-fixtures
  (let* ((rows (fixture "mt0-intervals.sexp"))
         (bad (collect-mismatches (row rows)
                (destructuring-bind (from to steps semis name) row
                  (declare (ignore name))
                  (equalp (make-interval :steps steps :semitones semis)
                          (interval-between (p from) (p to))))
                (destructuring-bind (from to steps semis name) row
                  (declare (ignore steps semis))
                  (string= name (interval-name (interval-between (p from) (p to)))))
                (destructuring-bind (from to steps semis name) row
                  (declare (ignore from to))
                  (equalp (make-interval :steps steps :semitones semis) (i name)))
                (destructuring-bind (from to steps semis name) row
                  (declare (ignore steps semis))
                  (equalp (p to) (transpose-pitch (p from) (i name))))
                (destructuring-bind (from to steps semis name) row
                  (declare (ignore steps semis))
                  (equalp (p from) (transpose-pitch (p to) (reverse-interval (i name))))))))
    (ok (= 2955 (length rows)))
    (ok (null bad) (report bad))))

(deftest out-of-range-intervals-transpose-but-have-no-name
  (let* ((rows (fixture "mt0-intervals-out-of-range.sexp"))
         (bad (collect-mismatches (row rows)
                (destructuring-bind (from to steps semis m21) row
                  (declare (ignore m21))
                  (equalp (make-interval :steps steps :semitones semis)
                          (interval-between (p from) (p to))))
                (destructuring-bind (from to steps semis m21) row
                  (declare (ignore m21))
                  (equalp (p to) (transpose-pitch (p from)
                                                  (make-interval :steps steps :semitones semis))))
                (destructuring-bind (from to steps semis m21) row
                  (declare (ignore from to m21))
                  (typep (handler-case
                             (interval-name (make-interval :steps steps :semitones semis))
                           (condition (c) c))
                         'invalid-interval))
                (destructuring-bind (from to steps semis m21) row
                  (declare (ignore from to m21))
                  (typep (handler-case
                             (interval-quality (make-interval :steps steps :semitones semis))
                           (condition (c) c))
                         'invalid-interval)))))
    (ok (= 720 (length rows)))
    (ok (null bad) (report bad))))

(deftest-parametrize parse-interval-sizes
    ((name steps semitones)
     ("P1" 0 0) ("d1" 0 -1) ("A1" 0 1) ("m2" 1 1) ("M2" 1 2) ("A2" 1 3)
     ("d3" 2 2) ("m3" 2 3) ("M3" 2 4) ("P4" 3 5) ("A4" 3 6) ("AA4" 3 7)
     ("d5" 4 6) ("P5" 4 7) ("m6" 5 8) ("M6" 5 9) ("dd7" 6 8) ("m7" 6 10)
     ("M7" 6 11) ("d8" 7 11) ("P8" 7 12) ("m9" 8 13) ("M10" 9 16) ("P11" 10 17)
     ("P12" 11 19) ("M13" 12 21) ("P15" 14 24)
     ("-m2" -1 -1) ("-M2" -1 -2) ("-m3" -2 -3) ("-P5" -4 -7) ("-P8" -7 -12) ("-M9" -8 -14))
  (ok (equalp (make-interval :steps steps :semitones semitones) (parse-interval name)))
  (ok (string= name (interval-name (make-interval :steps steps :semitones semitones)))))

(deftest-parametrize parse-interval-rejects
    ((text)
     ("") ("M4") ("P3") ("m5") ("X3") ("m0") ("3") ("M") ("-P1") ("-d1")
     ("AAA4") ("P-5") ("M 3") ("mm3"))
  (ok (signals-with-text (lambda () (parse-interval text)) 'invalid-interval text)))

(deftest parse-interval-use-value-restart
  (let ((fallback (make-interval :steps 2 :semitones 4)))
    (ok (equalp fallback
                (handler-bind ((invalid-interval (lambda (c) (use-value fallback c))))
                  (parse-interval "M4"))))))

(deftest-parametrize interval-qualities
    ((name quality)
     ("P1" :perfect) ("d1" :diminished) ("A1" :augmented) ("m2" :minor)
     ("M3" :major) ("AA4" :doubly-augmented) ("dd7" :doubly-diminished)
     ("d5" :diminished) ("-m6" :minor) ("P12" :perfect) ("M10" :major) ("-A4" :augmented))
  (ok (eq quality (interval-quality (i name)))))

(deftest interval-shape
  (ok (= 1 (interval-number (i "P1"))))
  (ok (= 3 (interval-number (i "-m3"))))
  (ok (= 12 (interval-number (i "P12"))))
  (ok (= 1 (interval-direction (i "M3"))))
  (ok (= -1 (interval-direction (i "-M3"))))
  (ok (= 0 (interval-direction (i "A1"))))
  (ok (= 0 (interval-direction (i "d1"))))
  (ok (interval-compound-p (i "M9")))
  (ok (not (interval-compound-p (i "P8"))))
  (ok (interval-compound-p (i "-P12"))))

(deftest-parametrize simple-intervals
    ((name expected)
     ("P12" "P5") ("M10" "M3") ("P8" "P8") ("P15" "P8") ("-M9" "-M2")
     ("M3" "M3") ("m17" "m3") ("-P15" "-P8") ("A1" "A1"))
  (ok (equalp (i expected) (simple-interval (i name)))))

(deftest-parametrize inversions
    ((name expected)
     ("M3" "m6") ("m3" "M6") ("P4" "P5") ("A4" "d5") ("d5" "A4") ("P1" "P8")
     ("P8" "P1") ("M2" "m7") ("M10" "m6") ("-M3" "-m6") ("A1" "d8") ("M7" "m2"))
  (ok (equalp (i expected) (invert-interval (i name)))))

(deftest-parametrize reversals
    ((name expected)
     ("M3" "-M3") ("A1" "d1") ("d1" "A1") ("-P5" "P5") ("P1" "P1") ("P12" "-P12"))
  (ok (equalp (i expected) (reverse-interval (i name)))))

(deftest-parametrize transpositions
    ((from interval to)
     ("F#4" "M2" "G#4") ("B3" "m2" "C4") ("C4" "-m2" "B3") ("E4" "A4" "A#4")
     ("Bb4" "P12" "F6") ("C4" "d2" "Dbb4") ("C4" "A1" "C#4") ("C4" "d1" "Cb4")
     ("G4" "-P15" "G2") ("D#5" "-M3" "B4") ("Eb4" "A4" "A4"))
  (ok (equalp (p to) (transpose-pitch (p from) (i interval)))))

(deftest-parametrize transposition-beyond-two-accidentals
    ((from interval)
     ("B##4" "A1") ("Fbb4" "d1") ("C##4" "A2") ("Cbb4" "-A2"))
  (ok (typep (handler-case (transpose-pitch (p from) (i interval)) (condition (c) c))
             'invalid-pitch)))

;;; Conditions ----------------------------------------------------------------

(deftest condition-hierarchy
  (ok (subtypep 'invalid-pitch 'music-theory-error))
  (ok (subtypep 'invalid-interval 'music-theory-error))
  (ok (subtypep 'invalid-meter 'music-theory-error))
  (ok (subtypep 'invalid-key 'music-theory-error))
  (ok (subtypep 'chord-symbol-parse-error 'music-theory-error))
  (ok (subtypep 'music-theory-error 'error))
  (ok (subtypep 'unknown-chord-quality 'music-theory-warning))
  (ok (subtypep 'ambiguous-spelling 'music-theory-warning))
  (ok (subtypep 'music-theory-warning 'warning))
  (let ((c (make-condition 'chord-symbol-parse-error :text "C#x" :position 2 :expected "quality")))
    (ok (= 2 (chord-symbol-parse-error-position c)))
    (ok (string= "quality" (chord-symbol-parse-error-expected c)))
    (ok (search "C#x" (princ-to-string c)))))
