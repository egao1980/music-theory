;;;; 0.5.1: chromatic lines in a key (music-theory#14), any integer octave in
;;;; text (music-theory#15), MusicXML <kind> functions (music-theory#16).
;;;; Hand-written rows follow the amended rules in src/spell.lisp, src/pitch.lisp
;;;; and src/chord-symbol.lisp. They were computed with independent reference
;;;; implementations of those rules (tests/fixtures/PROVENANCE.md, 0.5.1), which
;;;; also reproduce every MT4 row. The chromatic lines of mt51-chromatic.sexp are
;;;; public-domain passages re-encoded by us with their notated spelling.
;;;; Uses P (mt0), K, PC, CALL and SIGNALS-TYPE (mt2), CP, SAME-CHORD-P,
;;;; SYMBOL-FIXTURE-CASES and *MUSICXML-KINDS* (mt3), SPELLED-NAMES, OPT,
;;;; BASE-ROWS and TRANSPOSED-ROWS (mt4).

(in-package #:music-theory/tests)

(defun chromatic-lines () (fixture "mt51-chromatic.sexp"))

(defun chromatic-rows ()
  "(key names midis) for every line of mt51-chromatic.sexp, as SPELLING-ACCURACY reads."
  (mapcar (lambda (row) (destructuring-bind (id key category names midis) row
                          (declare (ignore id category))
                          (list key names midis)))
          (chromatic-lines)))

;;; music-theory#14: data ---------------------------------------------------------

(deftest spelling-key-note-positions-table
  (ok (equal '((:major -1 0 1 2 3 4 5) (:minor -4 -3 -2 -1 0 1 2 3 5))
             music-theory::+key-note-positions+))
  (ok (= 3/4 music-theory::+interval-rule-ambiguity+))
  (ok (every (lambda (mode)
               (subsetp (rest (assoc mode music-theory::+key-positions+))
                        (rest (assoc mode music-theory::+key-note-positions+))))
             '(:major :minor))
      "K is part of N")
  ;; N is the major scale, or the natural, harmonic and melodic minor scales
  ;; together, for every one of the 30 keys.
  (ok (every (lambda (row)
               (let* ((key (k (first row)))
                      (tonic (pitch-fifths (key-tonic key)))
                      (offsets (rest (assoc (key-mode key) music-theory::+key-note-positions+)))
                      (scales (loop for variant in '(:natural :harmonic :melodic)
                                    append (mapcar #'pitch-fifths (scale-degrees key :variant variant)))))
                 (null (set-exclusive-or (mapcar (lambda (o) (+ tonic o)) offsets)
                                         (remove-duplicates scales)))))
             (fixture "mt2-keys.sexp")))
  (ok (every (lambda (row) (< (- (reduce #'max (rest row)) (reduce #'min (rest row))) 12))
             music-theory::+key-note-positions+)
      "N spans fewer than 12 positions: at most one candidate is in it"))

;;; music-theory#14: rows ---------------------------------------------------------

(deftest-parametrize spell-sequence-chromatic-rows
    ((midis key expected ambiguities)
     ;; The rows of music-theory#14, as notated (S1: the minor forms; S5: the bound).
     ('(55 54 53 52 51 50) "G minor" '("G3" "F#3" "F3" "E3" "Eb3" "D3") '(0 5/6 23/54 9/20 25/33 5/36))
     ('(62 61 60 59 58 57) "D minor" '("D4" "C#4" "C4" "B3" "Bb3" "A3") '(0 5/6 23/54 9/20 25/33 5/36))
     ('(57 58 59 60 61 62) "D minor" '("A3" "Bb3" "B3" "C4" "C#4" "D4") '(1/6 11/16 5/9 1/3 19/22 1/24))
     ('(59 60 61 62 63 64) "E minor" '("B3" "C4" "C#4" "D4" "D#4" "E4") '(1/6 11/16 5/9 1/3 19/22 1/24))
     ('(64 63 62 61 60 59) "E minor" '("E4" "D#4" "D4" "C#4" "C4" "B3") '(0 5/6 23/54 9/20 25/33 5/36))
     ('(62 61 60) "D major" '("D4" "C#4" "C4") '(1/3 13/24 37/54))
     ('(69 70 71) "F major" '("A4" "Bb4" "B4") '(1/3 13/24 37/54))
     ;; More of the same: the ascending melodic minor, lines that go on (S4
     ;; decides, as in 0.5.0), and remote keys.
     ('(50 51 52 53 54 55) "G minor" '("D3" "Eb3" "E3" "F3" "F#3" "G3") '(1/6 11/16 5/9 1/3 19/22 1/24))
     ('(62 61 60 59) "D major" '("D4" "C#4" "C4" "B3") '(1/3 13/24 37/54 13/60))
     ('(69 70 71 72) "F major" '("A4" "Bb4" "B4" "C5") '(1/3 13/24 37/54 13/60))
     ('(51 50 49 48 47 46) "Eb minor" '("Eb3" "D3" "Db3" "C3" "Cb3" "Bb2") '(0 5/6 23/54 9/20 25/33 5/36))
     ('(66 65 64) "F# major" '("F#4" "E#4" "E4") '(1/3 13/24 37/54))
     ('(70 71 72) "F# major" '("A#4" "B4" "B#4") '(1/3 13/24 37/54)))
  (multiple-value-bind (pitches amb) (ignore-errors (spell-sequence midis :key (k key)))
    (ok (equal expected (ignore-errors (spelled-names pitches)))
        (format nil "~A ~S: ~S" key midis (ignore-errors (spelled-names pitches))))
    (ok (equal ambiguities amb) (format nil "~S" amb))))

(deftest-parametrize spell-midi-amended-rows
    ((midi key previous expected ambiguity)
     ;; S1: the natural seventh and the raised sixth of a minor key
     (64 "G minor" nil "E4" 1/2)
     (65 "G minor" nil "F4" 1/3)
     (60 "D minor" nil "C4" 1/3)
     (59 "D minor" nil "B3" 1/2)
     (61 "E minor" nil "C#4" 1/2)
     (62 "E minor" nil "D4" 1/3)
     (66 "A minor" nil "F#4" 1/2)
     (67 "A minor" nil "G4" 1/3)
     (60 "Eb minor" nil "C4" 1/2)
     (61 "Eb minor" nil "Db4" 1/3)
     (60 "D# minor" nil "B#3" 1/2)
     (61 "D# minor" nil "C#4" 1/3)
     ;; S5 below its bound: S6 decides
     (60 "D major" "C#4" "C4" 35/48)
     (71 "F major" "Bb4" "B4" 35/48)
     (66 "C major" "G4" "F#4" 11/16)
     ;; S5 at or above it, as in 0.5.0
     (61 "C major" "C4" "Db4" 7/8)
     (66 "C major" "Eb4" "Gb4" 37/48)
     (68 "C major" "E4" "G#4" 23/24)
     (65 "B minor" "F#4" "E#4" 47/48))
  (multiple-value-bind (pitch amb)
      (ignore-errors (spell-midi midi :key (opt #'k key) :previous (opt #'p previous)))
    (ok (and (spelled-pitch-p pitch) (string= expected (pitch-name pitch)))
        (format nil "~D in ~A after ~A: ~A" midi key previous (and (spelled-pitch-p pitch) (pitch-name pitch))))
    (ok (eql ambiguity amb) (format nil "ambiguity ~S" amb))))

;;; music-theory#14: properties and the corpus ----------------------------------

(deftest spell-sequence-minor-forms-property
  ;; With a minor KEY, every note of the natural, harmonic or melodic scale is
  ;; spelled from them (S1 over N), in every corpus.
  (let ((bad (collect-mismatches (row (remove-if-not (lambda (row) (eq :minor (key-mode (k (first row)))))
                                                     (append (base-rows) (transposed-rows) (chromatic-rows))))
               (destructuring-bind (key-text names midis) row
                 (declare (ignore names))
                 (let* ((key (k key-text))
                        (scale (loop for variant in '(:natural :harmonic :melodic)
                                     append (scale-degrees key :variant variant))))
                   (every (lambda (pitch midi)
                            (let ((member (find (mod midi 12) scale :key #'pitch-class)))
                              (or (null member) (equalp member (pitch-spelling pitch)))))
                          (spell-sequence midis :key key) midis))))))
    (ok (null bad) (report (mapcar #'caar bad)))))

(deftest chromatic-lines-fixture
  (let ((lines (chromatic-lines)))
    (ok (= 57 (length lines)))
    (ok (= 501 (reduce #'+ lines :key (lambda (row) (length (fourth row))))))
    (ok (every (lambda (row)
                 (destructuring-bind (id key category names midis) row
                   (and (stringp id) (k key)
                        (member category '("lament" "minor-ascending" "minor-descending"
                                           "major-ascending" "major-descending" "neighbour")
                                :test #'string=)
                        (equal midis (mapcar (lambda (name) (pitch-midi (p name))) names)))))
               lines)
        "every row: a key, a category, MIDI numbers that match the names")))

(deftest-parametrize spell-sequence-chromatic-accuracy
    ((label use-key threshold)
     ;; The amended rules' reference implementation scores 494/501 = 98.60% with
     ;; the key and 468/501 = 93.41% without; 0.5.0 scores 95.21% and 91.22%,
     ;; music21's speller 94.61% and 94.01% (PROVENANCE.md). Rounded down.
     ("chromatic lines with the key" t 98/100)
     ("chromatic lines without a key" nil 93/100))
  (multiple-value-bind (right total) (spelling-accuracy (chromatic-rows) :use-key use-key)
    (ok (= 501 total))
    (ok (>= (/ right total) threshold)
        (format nil "~A: ~D/~D = ~,2F%" label right total (* 100 (/ right total))))))

;;; music-theory#15: octaves ------------------------------------------------------

(deftest pitch-name-parse-round-trip
  ;; Every SPELLED-PITCH, in both accidental styles, beyond the MIDI range too.
  (let ((bad (loop for letter below 7
                   nconc (loop for alter from -2 to 2
                               nconc (loop for octave in '(-100000000000000000000 -1000 -12 -3 -2 -1 0 4 9 10 11
                                                           99 123456789012345678901234567890)
                                           nconc (loop for style in '(:ascii :unicode)
                                                       for pitch = (make-spelled-pitch :letter letter :alter alter
                                                                                       :octave octave)
                                                       unless (equalp pitch (ignore-errors
                                                                             (parse-pitch (pitch-name pitch :accidentals style))))
                                                         collect (list (pitch-name pitch) style)))))))
    (ok (null bad) (report bad))))

(deftest-parametrize parse-pitch-any-octave
    ((text letter alter octave)
     ("C10" 0 0 10) ("C-2" 0 0 -2) ("B#-2" 6 1 -2) ("G10" 4 0 10) ("F##12" 3 2 12)
     ("A♭-7" 5 -1 -7) ("c999" 0 0 999) (" Ebb-40 " 2 -2 -40))
  (ok (equalp (make-spelled-pitch :letter letter :alter alter :octave octave)
              (ignore-errors (parse-pitch text)))
      text))

(deftest octaves-the-library-builds-read-back
  ;; Values the library returns outside -1..9 print to text it reads back.
  (dolist (pitch (list (spell-midi 0 :key (k "C# major"))
                       (transpose-pitch (p "G9") (parse-interval "P8"))
                       (transpose-pitch (p "C-1") (parse-interval "-M2"))))
    (ok (equalp pitch (ignore-errors (parse-pitch (pitch-name pitch)))) (pitch-name pitch)))
  (ok (string= "B#-2" (pitch-name (spell-midi 0 :key (k "C# major")))))
  (ok (signals-type (lambda () (parse-pitch "C-")) 'invalid-pitch) "a sign alone is still no octave")
  (ok (signals-type (lambda () (parse-pitch "C--1")) 'invalid-pitch)))

;;; music-theory#16: MusicXML <kind> ----------------------------------------------

(defun kind-chord (kind root &key bass degrees)
  "MUSICXML-KIND-CHORD-SYMBOL with ROOT and BASS as strings, and true when it
returned: (values chord t), or (values nil nil) on any error."
  (handler-case (values (musicxml-kind-chord-symbol kind (and root (pc root))
                                                    :bass (and bass (pc bass)) :degrees degrees)
                        t)
    (error () (values nil nil))))

(defun with-root-and-bass (chord root bass)
  "CHORD with ROOT and BASS (PITCH-CLASS-NAMEs or NIL) in place of its own."
  (make-chord-symbol :root root :quality (chord-symbol-quality chord)
                     :extensions (chord-symbol-extensions chord)
                     :alterations (chord-symbol-alterations chord)
                     :suspension (chord-symbol-suspension chord)
                     :added (chord-symbol-added chord) :omitted (chord-symbol-omitted chord)
                     :bass bass))

(defun kind-of (text &optional (dialect :pop))
  "(kind degrees) that CHORD-SYMBOL-MUSICXML-KIND gives for TEXT, or :ERROR."
  (handler-case (multiple-value-list (chord-symbol-musicxml-kind (cp text dialect)))
    (error () :error)))

(deftest musicxml-structural-degrees-table
  (let ((rows music-theory::+musicxml-structural-degrees+))
    (ok (equal '((:diminished-7 :minor-7 ((:alter 5 -1) (:alter 7 -1)))
                 (:minor-major-7 :minor-7 ((:alter 7 1)))
                 (:half-diminished-7 :minor-7 ((:alter 5 -1)))
                 (:augmented-7 :dominant-7 ((:alter 5 1)))
                 (:augmented-major-7 :major-7 ((:alter 5 1))))
               rows))
    ;; A row's single fifth alteration is the parser's fold.
    (ok (every (lambda (row)
                 (destructuring-bind (quality base degrees) row
                   (or (rest degrees)
                       (destructuring-bind (type value alter) (first degrees)
                         (or (/= value 5)
                             (and (eq type :alter)
                                  (member (list base (cons 5 alter) quality)
                                          music-theory::+fifth-alteration-folds+ :test #'equal)))))))
               rows))
    ;; The rows are exactly the seventh qualities that some EXTENSIONS leave
    ;; without a kind of +MUSICXML-KINDS+, and their bases have every kind.
    (let ((named (loop for (kind text) in music-theory::+musicxml-kinds+
                       for c = (and text (cp text))
                       when (and c (not (chord-symbol-no-chord-p c))
                                 (null (chord-symbol-alterations c)) (null (chord-symbol-added c))
                                 (null (chord-symbol-omitted c)) (null (chord-symbol-suspension c)))
                         collect (cons (chord-symbol-quality c) (chord-symbol-extensions c)))))
      (flet ((complete-p (quality)
               (every (lambda (e) (member (cons quality e) named :test #'equal))
                      '(() (9) (9 11) (9 11 13)))))
        (ok (null (set-exclusive-or (mapcar #'first rows)
                                    (remove-if #'complete-p (mapcar #'first music-theory::+chord-seventh-stems+))))
            "the seventh qualities without a kind for every extension")
        (ok (every (lambda (row) (complete-p (second row))) rows))))))

(deftest-parametrize musicxml-kind-to-symbol-on-c
    ((kind expected)
     ("major" "C") ("minor" "Cm") ("augmented" "C+") ("diminished" "Cm(b5)")
     ("dominant" "C7") ("major-seventh" "Cmaj7") ("minor-seventh" "Cm7")
     ("diminished-seventh" "Cdim7") ("augmented-seventh" "C+7") ("half-diminished" "Cm7(b5)")
     ("major-minor" "Cmmaj7") ("major-sixth" "C6") ("minor-sixth" "Cm6")
     ("dominant-ninth" "C9") ("major-ninth" "Cmaj9") ("minor-ninth" "Cm9")
     ("dominant-11th" "C11") ("major-11th" "Cmaj11") ("minor-11th" "Cm11")
     ("dominant-13th" "C13") ("major-13th" "Cmaj13") ("minor-13th" "Cm13")
     ("suspended-second" "Csus2") ("suspended-fourth" "Csus4") ("Neapolitan" "C")
     ("Italian" "C5(add#4,addb6,omit5)") ("French" "C5(add2,add#4,addb6,omit5)")
     ("German" "Cm(add#4,addb6,omit5)") ("pedal" "C5(omit5)") ("power" "C5")
     ("Tristan" "C5(#9,add#4,add#6,omit5)") ("other" nil) ("none" "N.C."))
  (multiple-value-bind (c returned) (kind-chord kind "C")
    (ok (and returned
             (if expected
                 (and (same-chord-p (cp expected) c)
                      (null (chord-symbol-text c)) (null (chord-symbol-dialect c)))
                 (null c)))
        (format nil "~A: ~S" kind (and (chord-symbol-p c) (print-chord-symbol c))))))

(deftest musicxml-every-kind-has-a-row
  (ok (= 33 (length *musicxml-kinds*)))
  (ok (equal *musicxml-kinds* (mapcar #'first music-theory::+musicxml-kinds+))))

(deftest-parametrize musicxml-kind-with-degrees
    ((kind root bass degrees expected)
     ("dominant" "F#" "A#" () "F#7/A#")
     ("minor-seventh" "Bb" nil () "Bbm7")
     ("half-diminished" "B" nil () "Bm7(b5)")
     ("Italian" "A" nil () "A5(add#4,addb6,omit5)")
     ("none" "C" "E" () "N.C.")
     ("major" "C" "E" () "C/E")
     ("dominant" "G" nil '((:add 9 -1)) "G7(b9)")
     ("dominant" "G" nil '((:alter 5 -1)) "G7(b5)")
     ("dominant" "G" nil '((:alter 5 1)) "G+7")
     ("dominant-13th" "G" nil '((:alter 11 1)) "G13(#11)")
     ("dominant-ninth" "G" nil '((:add 11 1)) "G9(#11)")
     ("dominant" "G" nil '((:subtract 3 0) (:add 4 0)) "G7sus4")
     ("dominant" "G" nil '((:add 4 0) (:subtract 3 0)) "G7(add4,omit3)")
     ("major" "C" nil '((:add 9 0)) "C(add9)")
     ("major-sixth" "C" nil '((:add 9 0)) "C6/9")
     ("major-seventh" "C" nil '((:alter 5 1)) "C+maj7")
     ("major-ninth" "Eb" nil '((:alter 5 1)) "Eb+maj9")
     ("minor-ninth" "C" nil '((:alter 5 -1)) "Cm9(b5)")
     ("minor-ninth" "C" nil '((:alter 7 1)) "Cmmaj9")
     ("minor-ninth" "C" nil '((:alter 5 -1) (:alter 7 -1)) "Cdim9")
     ("minor-seventh" "C" nil '((:alter 5 -1) (:alter 5 1)) "Cm7(b5,#5)")
     ("minor-13th" "C" nil '((:alter 7 1) (:alter 5 -1)) "Cmmaj13(b5)")
     ("dominant" "C" nil '((:add 9 -1) (:add 9 1) (:add 11 1) (:add 13 -1) (:subtract 5 0))
      "C7(b9,#9,#11,b13,omit5)")
     ("dominant" "C" nil '((:add 9 0)) "C7(add9)")
     ("suspended-fourth" "C" nil '((:add 9 0)) "Csus4(add9)")
     ("major" "C" nil '((:add 4 0) (:subtract 3 0)) "C(add4,omit3)")
     ("power" "C" nil '((:add 4 1) (:add 6 -1) (:subtract 5 0)) "C5(add#4,addb6,omit5)")
     ("augmented" "C" nil '((:subtract 3 0) (:add 4 0)) "C+sus4")
     ("major-seventh" "C" nil '((:alter 5 1) (:subtract 3 0) (:add 2 0)) "C+maj7sus2")
     ("minor" "D" nil '((:alter 5 -1)) "Dm(b5)")
     ("major" "E" nil '((:alter 5 1)) "E+")
     ("dominant-11th" "C" nil '((:subtract 3 0)) "C11(omit3)")
     ("minor-11th" "A" "G" '((:subtract 9 0)) "Am11(omit9)/G")
     ("dominant-13th" "C" nil '((:alter 9 -1)) "C13(b9)")
     ("other" "C" nil '((:add 3 0) (:add 5 0)) nil))
  (multiple-value-bind (c returned) (kind-chord kind root :bass bass :degrees degrees)
    (ok (and returned (if expected (same-chord-p (cp expected) c) (null c)))
        (format nil "~A ~A ~S: ~S" kind root degrees (and (chord-symbol-p c) (print-chord-symbol c))))))

(deftest-parametrize chord-symbol-to-musicxml-kind
    ((text kind degrees)
     ;; Every kind's own symbol
     ("C" "major" ()) ("Cm" "minor" ()) ("C+" "augmented" ()) ("Cm(b5)" "diminished" ())
     ("C7" "dominant" ()) ("Cmaj7" "major-seventh" ()) ("Cm7" "minor-seventh" ())
     ("Cdim7" "diminished-seventh" ()) ("C+7" "augmented-seventh" ()) ("Cm7(b5)" "half-diminished" ())
     ("Cmmaj7" "major-minor" ()) ("C6" "major-sixth" ()) ("Cm6" "minor-sixth" ())
     ("C9" "dominant-ninth" ()) ("Cmaj9" "major-ninth" ()) ("Cm9" "minor-ninth" ())
     ("C11" "dominant-11th" ()) ("Cmaj11" "major-11th" ()) ("Cm11" "minor-11th" ())
     ("C13" "dominant-13th" ()) ("Cmaj13" "major-13th" ()) ("Cm13" "minor-13th" ())
     ("Csus2" "suspended-second" ()) ("Csus4" "suspended-fourth" ()) ("C5" "power" ())
     ("N.C." "none" ())
     ;; The functional kinds and pedal are written with the plain kinds
     ("C5(add#4,addb6,omit5)" "power" '((:add 4 1) (:add 6 -1) (:subtract 5 0)))
     ("C5(add2,add#4,addb6,omit5)" "power" '((:add 2 0) (:add 4 1) (:add 6 -1) (:subtract 5 0)))
     ("Cm(add#4,addb6,omit5)" "minor" '((:add 4 1) (:add 6 -1) (:subtract 5 0)))
     ("C5(omit5)" "power" '((:subtract 5 0)))
     ("C5(#9,add#4,add#6,omit5)" "power" '((:add 9 1) (:add 4 1) (:add 6 1) (:subtract 5 0)))
     ;; Degrees
     ("C7(b9)" "dominant" '((:add 9 -1)))
     ("C13(#11)" "dominant-13th" '((:alter 11 1)))
     ("C9(#11)" "dominant-ninth" '((:add 11 1)))
     ("C13(b9)" "dominant-13th" '((:alter 9 -1)))
     ("C7(b5)" "dominant" '((:alter 5 -1)))
     ("G7(b9,#9)" "dominant" '((:add 9 -1) (:add 9 1)))
     ("C7alt" "dominant" '((:add 9 -1) (:add 9 1) (:add 11 1) (:add 13 -1) (:subtract 5 0)))
     ("C7sus4" "dominant" '((:subtract 3 0) (:add 4 0)))
     ("C9sus4" "dominant-ninth" '((:subtract 3 0) (:add 4 0)))
     ("C+sus4" "augmented" '((:subtract 3 0) (:add 4 0)))
     ("Csus4(add9)" "suspended-fourth" '((:add 9 0)))
     ("C(add4,omit3)" "major" '((:add 4 0) (:subtract 3 0)))
     ("C6/9" "major-sixth" '((:add 9 0)))
     ("C(add9)" "major" '((:add 9 0)))
     ("C7(add9)" "dominant" '((:add 9 0)))
     ("Cdim7(add9)" "diminished-seventh" '((:add 9 0)))
     ("C11(omit3)" "dominant-11th" '((:subtract 3 0)))
     ("Am11(omit9)/G" "minor-11th" '((:subtract 9 0)))
     ("Cm7(b5,#5)" "minor-seventh" '((:alter 5 -1) (:alter 5 1)))
     ;; Structural degrees
     ("C+maj7" "major-seventh" '((:alter 5 1)))
     ("C+maj9" "major-ninth" '((:alter 5 1)))
     ("C+9" "dominant-ninth" '((:alter 5 1)))
     ("Cm9(b5)" "minor-ninth" '((:alter 5 -1)))
     ("Cmmaj9" "minor-ninth" '((:alter 7 1)))
     ("Cdim9" "minor-ninth" '((:alter 5 -1) (:alter 7 -1)))
     ("Cmmaj13(b5)" "minor-13th" '((:alter 7 1) (:alter 5 -1)))
     ("C+maj7sus2" "major-seventh" '((:alter 5 1) (:subtract 3 0) (:add 2 0)))
     ;; Root and bass are the chord's own
     ("F#7/A#" "dominant" ()) ("Bbm7(b5)" "half-diminished" ()) ("Ebm(maj7)" "major-minor" ()))
  (ok (equal (list kind degrees) (kind-of text)) (format nil "~A: ~S" text (kind-of text))))

(deftest musicxml-kind-round-trips
  ;; Every chord of the MT3 symbol fixture, on several roots and with a bass,
  ;; goes to MusicXML and back unchanged but for TEXT and DIALECT.
  (let ((bad (collect-mismatches (case (symbol-fixture-cases))
               (destructuring-bind ((text &rest more) d) case
                 (declare (ignore more))
                 (let ((c (cp text d)))
                   (every (lambda (moved)
                            (multiple-value-bind (kind degrees) (chord-symbol-musicxml-kind moved)
                              (same-chord-p moved (musicxml-kind-chord-symbol
                                                   kind (chord-symbol-root moved)
                                                   :bass (chord-symbol-bass moved) :degrees degrees))))
                          (if (chord-symbol-no-chord-p c)
                              (list c)
                              (cons c (mapcar (lambda (rb)
                                                (with-root-and-bass c (pc (car rb)) (opt #'pc (cdr rb))))
                                              '(("F#" . nil) ("Bbb" . "Ab") ("E#" . "C##") ("Db" . "Db")))))))))))
    (ok (= 981 (length (symbol-fixture-cases))))
    (ok (null bad) (report (mapcar #'caar bad)))))

(deftest musicxml-named-kinds-come-back
  ;; The 25 kinds rule X2 returns, on every root of the line of fifths.
  (let* ((kinds (remove-if (lambda (kind)
                             (member kind '("Neapolitan" "Italian" "French" "German" "Tristan"
                                            "pedal" "other" "none")
                                     :test #'string=))
                           *musicxml-kinds*))
         (bad (loop for kind in kinds
                    nconc (loop for fifths from -8 to 12
                                for root = (fifths-pitch-class fifths)
                                unless (equal (list kind '())
                                              (ignore-errors
                                               (multiple-value-list
                                                (chord-symbol-musicxml-kind
                                                 (musicxml-kind-chord-symbol kind root)))))
                                  collect (list kind (pitch-class-string root))))))
    (ok (= 25 (length kinds)))
    (ok (null bad) (report bad))))

(deftest musicxml-kind-errors
  (flet ((theory-error-p (thunk)
           (handler-case (progn (funcall thunk) nil)
             (music-theory-error () t)
             (error () nil))))
    (dolist (text '("Major" "dominant-seventh" "" "maj7" " major"))
      (ok (handler-case (progn (musicxml-kind-chord-symbol text (pc "C")) nil)
            (music-theory-error (c) (equal text (music-theory-error-text c)))
            (error () nil))
          (format nil "~S is not a MusicXML 4.0 kind" text)))
    (ok (signals-type (lambda () (call #'musicxml-kind-chord-symbol :major (pc "C"))) 'type-error))
    (ok (signals-type (lambda () (call #'musicxml-kind-chord-symbol "major" "C")) 'type-error))
    (ok (signals-type (lambda () (call #'musicxml-kind-chord-symbol "major" (pc "C") :bass "E")) 'type-error))
    (ok (signals-type (lambda () (call #'musicxml-kind-chord-symbol "major" (pc "C") :degrees '((:add 9)))) 'type-error))
    (ok (signals-type (lambda () (call #'musicxml-kind-chord-symbol "major" (pc "C") :degrees '((:raise 9 0)))) 'type-error))
    (ok (signals-type (lambda () (call #'musicxml-kind-chord-symbol "major" (pc "C") :degrees '((:add 9 0) . x))) 'type-error))
    (loop for (kind degrees) in '(("major" ((:alter 3 1))) ("major" ((:add 7 0))) ("major" ((:add 9 2)))
                                  ("major" ((:subtract 5 1))) ("major" ((:subtract 7 0)))
                                  ("dominant" ((:alter 9 -1))) ("dominant-ninth" ((:add 9 0)))
                                  ("diminished" ((:alter 5 1))) ("major" ((:alter 7 1)))
                                  ("dominant" ((:add 9 -1) (:add 9 -1))) ("none" ((:add 9 0))))
          do (ok (theory-error-p (lambda () (musicxml-kind-chord-symbol kind (pc "C") :degrees degrees)))
                 (format nil "~A ~S" kind degrees)))
    (ok (theory-error-p (lambda () (chord-symbol-musicxml-kind (make-chord-symbol :root (pc "C") :quality :minor
                                                                                  :alterations '((5 . -1))))))
        "a chord that is not well formed")
    (ok (signals-type (lambda () (call #'chord-symbol-musicxml-kind "C7")) 'type-error))))
