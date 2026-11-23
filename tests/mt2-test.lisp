;;;; MT2: keys, scales, scale degrees, Roman numerals, and the chord-symbol value.
;;;; Fixture vectors come from music21 10.5.2 (tests/fixtures/PROVENANCE.md).
;;;; Hand-written rows follow the rules in src/key.lisp and src/roman.lisp. They
;;;; were cross-checked against an independent reference implementation of those
;;;; rules (no mismatches), and, where music21 can express them, against music21.

(in-package #:music-theory/tests)

(defun k (s) (parse-key s))
(defun r (s) (parse-roman s))
(defun pc (s) (parse-pitch-class s))
(defun names (classes) (mapcar #'pitch-class-string classes))

(defun cs (root quality &optional bass)
  "A CHORD-SYMBOL with ROOT, QUALITY and BASS (strings, BASS optional)."
  (make-chord-symbol :root (pc root) :quality quality :bass (and bass (pc bass))))

(defun rn (degree alteration quality &optional (inversion 0) target)
  "A ROMAN-NUMERAL; TARGET is NIL or (degree alteration quality)."
  (make-roman-numeral :degree degree :alteration alteration :quality quality
                      :inversion inversion
                      :applied-to (and target (apply #'rn target))))

(defun call (function &rest args)
  "APPLY FUNCTION to ARGS at run time, so that a deliberately ill-typed
argument reaches the type check instead of a compile-time warning."
  (apply function args))

(defun signals-type (thunk type)
  "True when THUNK signals a condition of TYPE."
  (handler-case (progn (funcall thunk) nil)
    (condition (c) (typep c type))))

(defun roman-fixture-chord (row)
  "The CHORD-SYMBOL of a mt2-roman.sexp row: BASS only when inverted."
  (destructuring-bind (kname text literal root bass inversion quality &rest more) row
    (declare (ignore kname text literal more))
    (cs root quality (and (plusp inversion) bass))))

;;; Keys --------------------------------------------------------------------

(deftest key-fixtures
  (let* ((rows (fixture "mt2-keys.sexp"))
         (bad (collect-mismatches (row rows)
                (destructuring-bind (name sig tonic mode &rest scales) row
                  (declare (ignore sig scales))
                  (equalp (make-key :tonic (pc tonic) :mode mode) (k name)))
                (string= (first row) (key-name (k (first row))))
                (= (second row) (key-signature (k (first row))))
                (destructuring-bind (name sig tonic mode natural harmonic melodic) row
                  (declare (ignore sig tonic mode))
                  (and (equal natural (names (scale-degrees (k name))))
                       (equal natural (names (scale-degrees (k name) :variant :natural)))
                       (equal harmonic (names (scale-degrees (k name) :variant :harmonic)))
                       (equal melodic (names (scale-degrees (k name) :variant :melodic))))))))
    (ok (= 30 (length rows)))
    (ok (null bad) (report bad))))

(deftest key-tables-match-music21
  ;; Data only (+SCALES+, +MODE-VARIANTS+, +MODE-SIGNATURES+), checked with MT0
  ;; arithmetic, so these pass before the MT2 functions exist.
  (let* ((rows (fixture "mt2-keys.sexp"))
         (bad (collect-mismatches (row rows)
                (destructuring-bind (name sig tonic mode &rest scales) row
                  (declare (ignore name scales))
                  (= sig (+ (pitch-fifths (pc tonic))
                            (cdr (assoc mode music-theory::+mode-signatures+)))))
                (destructuring-bind (name sig tonic mode natural harmonic melodic) row
                  (declare (ignore name sig))
                  (loop with start = (parse-pitch (format nil "~A4" tonic))
                        for (variant expected) in (list (list :natural natural)
                                                        (list :harmonic harmonic)
                                                        (list :melodic melodic))
                        for scale = (cdr (assoc (cdr (assoc variant
                                                            (cdr (assoc mode music-theory::+mode-variants+))))
                                                music-theory::+scales+))
                        always (equal expected
                                      (loop for d below 7
                                            collect (pitch-class-string
                                                     (pitch-spelling
                                                      (transpose-pitch
                                                       start (make-interval :steps d
                                                                            :semitones (aref scale d))))))))))))
    (ok (null bad) (report bad))
    (ok (equal (loop for f from -7 to 7 collect f)
               (sort (mapcar #'second (remove :minor rows :key #'fourth)) #'<)))
    (ok (equal (loop for f from -7 to 7 collect f)
               (sort (mapcar #'second (remove :major rows :key #'fourth)) #'<)))))

(deftest-parametrize parse-key-accepts
    ((text tonic mode)
     ("G" "G" :major)
     ("g" "G" :minor)
     ("Gm" "G" :minor)
     ("gm" "G" :minor)
     ("F#m" "F#" :minor)
     ("f#" "F#" :minor)
     ("F♯m" "F#" :minor)
     ("Eb major" "Eb" :major)
     ("eb major" "Eb" :major)
     ("E♭ major" "Eb" :major)
     ("f# minor" "F#" :minor)
     ("F# MINOR" "F#" :minor)
     ("C Major" "C" :major)
     ("  D major " "D" :major)
     ("A   minor" "A" :minor)
     ("Bb" "Bb" :major)
     ("bb" "Bb" :minor)
     ("Bbm" "Bb" :minor)
     ("bbm" "Bb" :minor)
     ("b" "B" :minor)
     ("Cb" "Cb" :major)
     ("C#" "C#" :major)
     ("a#" "A#" :minor)
     ("ab" "Ab" :minor)
     ("g# minor" "G#" :minor)
     ("D#m" "D#" :minor))
  (ok (equalp (make-key :tonic (pc tonic) :mode mode) (parse-key text))))

(deftest-parametrize parse-key-rejects
    ((text)
     ("")
     ("H")
     ("G#")
     ("Fb")
     ("Cb minor")
     ("cbm")
     ("e#")
     ("dbm")
     ("B#")
     ("Gx")
     ("Gmaj")
     ("G maj")
     ("Gminor")
     ("GM")
     ("G-")
     ("G major minor")
     ("Gm7")
     ("m")
     ("4")
     ("Gm minor")
     ("G#M")
     ("major"))
  (ok (signals-with-text (lambda () (parse-key text)) 'invalid-key text)))

(deftest parse-key-use-value-restart
  (let ((fallback (make-key :tonic (pc "C") :mode :major)))
    (ok (equalp fallback
                (handler-bind ((invalid-key (lambda (c) (use-value fallback c))))
                  (parse-key "G#"))))
    (ok (eq :key
            (handler-case (parse-key "Gmaj")
              (invalid-pitch () :pitch)
              (invalid-key () :key))))))

(deftest-parametrize key-name-unicode
    ((text expected)
     ("F# minor" "F♯ minor")
     ("Bb major" "B♭ major")
     ("C major" "C major")
     ("Cb major" "C♭ major")
     ("g" "G minor"))
  (ok (string= expected (key-name (k text) :accidentals :unicode))))

(deftest-parametrize keys-beyond-seven-accidentals
    ((tonic mode natural)
     ("G#" :major '("G#" "A#" "B#" "C#" "D#" "E#" "F##"))
     ("Fb" :major '("Fb" "Gb" "Ab" "Bbb" "Cb" "Db" "Eb"))
     ("D#" :major '("D#" "E#" "F##" "G#" "A#" "B#" "C##"))
     ("Fb" :minor '("Fb" "Gb" "Abb" "Bbb" "Cb" "Dbb" "Ebb"))
     ("B#" :minor '("B#" "C##" "D#" "E#" "F##" "G#" "A#")))
  ;; Theoretical keys have no signature here, but their scales exist (music21
  ;; agrees on these spellings): applied chords tonicize them.
  (let ((key (make-key :tonic (pc tonic) :mode mode)))
    (ok (signals-with-text (lambda () (key-signature key)) 'invalid-key nil))
    (ok (equal natural (names (scale-degrees key))))))

;;; Scales and degrees ------------------------------------------------------

(deftest-parametrize minor-scale-variants
    ((kname variant expected)
     ("A minor" :natural '("A" "B" "C" "D" "E" "F" "G"))
     ("A minor" :harmonic '("A" "B" "C" "D" "E" "F" "G#"))
     ("A minor" :melodic '("A" "B" "C" "D" "E" "F#" "G#"))
     ("C major" :natural '("C" "D" "E" "F" "G" "A" "B"))
     ("C major" :harmonic '("C" "D" "E" "F" "G" "A" "B"))
     ("C major" :melodic '("C" "D" "E" "F" "G" "A" "B"))
     ("A# minor" :melodic '("A#" "B#" "C#" "D#" "E#" "F##" "G##"))
     ("Ab minor" :harmonic '("Ab" "Bb" "Cb" "Db" "Eb" "Fb" "G"))
     ("Eb minor" :melodic '("Eb" "F" "Gb" "Ab" "Bb" "C" "D")))
  (ok (equal expected (names (scale-degrees (k kname) :variant variant)))))

(deftest scale-variant-must-be-known
  (ok (signals-type (lambda () (call #'scale-degrees (k "A minor") :variant :dorian)) 'type-error))
  (ok (signals-type (lambda () (call #'degree-of (pc "G#") (k "A minor") :variant :lydian)) 'type-error)))

(deftest degree-fixtures
  (let* ((rows (fixture "mt2-degrees.sexp"))
         (bad (collect-mismatches (row rows)
                (destructuring-bind (kname variant name degree alteration) row
                  (equal (list degree alteration nil)
                         (multiple-value-list (degree-of (pc name) (k kname) :variant variant))))
                (destructuring-bind (kname variant name degree alteration) row
                  (equalp (pc name)
                          (pitch-of-degree degree (k kname) :alteration alteration
                                                            :variant variant))))))
    (ok (= 2100 (length rows)))
    (ok (null bad) (report bad))))

(deftest degree-of-then-pitch-of-degree-is-identity
  ;; Every MT0 fixture pitch (C0..B8, bb..##) in every key and variant.
  (let* ((pitches (mapcar (lambda (row) (parse-pitch (first row))) (fixture "mt0-pitches.sexp")))
         (keys (mapcar (lambda (row) (k (first row))) (fixture "mt2-keys.sexp")))
         (cases (loop for key in keys
                      nconc (loop for variant in '(:natural :harmonic :melodic)
                                  nconc (loop for p in pitches collect (list key variant p)))))
         (bad (collect-mismatches (trio cases)
                (destructuring-bind (key variant p) trio
                  (multiple-value-bind (d a o) (degree-of p key :variant variant)
                    (equalp p (pitch-of-degree d key :alteration a :octave o :variant variant))))
                (destructuring-bind (key variant p) trio
                  (let ((class (pitch-spelling p)))
                    (multiple-value-bind (d a o) (degree-of class key :variant variant)
                      (and (null o)
                           (equalp class (pitch-of-degree d key :alteration a
                                                                :variant variant)))))))))
    (ok (= (* 30 3 315) (length cases)))
    (ok (null bad) (report bad))))

(deftest-parametrize degree-of-spelled-pitches
    ((kname pitch variant degree alteration octave)
     ("B major" "C#5" :natural 2 0 4)
     ("C major" "Cb4" :natural 1 -1 4)
     ("C major" "B#3" :natural 7 1 3)
     ("C major" "B3" :natural 7 0 3)
     ("A minor" "G#4" :natural 7 1 3)
     ("A minor" "G#4" :harmonic 7 0 3)
     ("A minor" "F#4" :melodic 6 0 3)
     ("A minor" "G4" :melodic 7 -1 3)
     ("A minor" "A3" :natural 1 0 3)
     ("A minor" "G3" :natural 7 0 2)
     ("F# major" "Fb4" :natural 1 -2 4)
     ("Eb major" "D5" :natural 7 0 4)
     ("C# major" "C4" :natural 1 -1 4)
     ("Cb major" "Cb4" :natural 1 0 4)
     ("G major" "F4" :natural 7 -1 3)
     ("G major" "G4" :natural 1 0 4))
  (ok (equal (list degree alteration octave)
             (multiple-value-list (degree-of (parse-pitch pitch) (k kname) :variant variant)))))

(deftest-parametrize pitch-of-degree-with-octave
    ((kname degree octave alteration variant expected)
     ("B major" 2 4 0 :natural "C#5")
     ("C# major" 7 4 0 :natural "B#4")
     ("C major" 1 4 -1 :natural "Cb4")
     ("A minor" 7 4 0 :harmonic "G#5")
     ("A minor" 3 3 0 :natural "C4")
     ("Eb major" 7 4 0 :natural "D5")
     ("F# major" 1 4 -2 :natural "Fb4")
     ("G major" 4 3 1 :natural "C#4")
     ("D minor" 6 4 0 :melodic "B4")
     ("D minor" 6 4 0 :natural "Bb4"))
  (ok (equalp (parse-pitch expected)
              (pitch-of-degree degree (k kname) :octave octave :alteration alteration
                                                :variant variant))))

(deftest-parametrize pitch-of-degree-classes
    ((kname degree alteration variant expected)
     ("A minor" 6 0 :melodic "F#")
     ("A minor" 7 0 :natural "G")
     ("Bb major" 4 1 :natural "E")
     ("C# minor" 7 0 :harmonic "B#")
     ("Gb major" 4 -1 :natural "Cbb"))
  (ok (equalp (pc expected)
              (pitch-of-degree degree (k kname) :alteration alteration :variant variant))))

(deftest pitch-of-degree-errors
  (ok (signals-type (lambda () (call #'pitch-of-degree 0 (k "C major"))) 'type-error))
  (ok (signals-type (lambda () (call #'pitch-of-degree 8 (k "C major"))) 'type-error))
  (ok (signals-type (lambda () (pitch-of-degree 4 (k "Gb major") :alteration -2)) 'invalid-pitch)
      "Cb lowered twice needs three flats"))

;;; Chord-symbol value ------------------------------------------------------

(deftest chord-symbol-value
  (let ((empty (make-chord-symbol)))
    (ok (null (chord-symbol-root empty)))
    (ok (null (chord-symbol-quality empty)))
    (ok (null (chord-symbol-bass empty)))
    (ok (null (chord-symbol-no-chord-p empty)))
    (ok (null (chord-symbol-text empty)))
    (ok (null (chord-symbol-dialect empty)))
    (ok (every #'null (list (chord-symbol-extensions empty) (chord-symbol-alterations empty)
                            (chord-symbol-suspension empty) (chord-symbol-added empty)
                            (chord-symbol-omitted empty)))))
  (ok (equalp (cs "G" :dominant-7 "B") (cs "G" :dominant-7 "B")))
  (ok (not (equalp (cs "G" :dominant-7 "B") (cs "G" :dominant-7))))
  (ok (signals-type (lambda () (call #'make-chord-symbol :suspension 3)) 'type-error))
  (ok (signals-type (lambda () (call #'make-chord-symbol :dialect :baroque)) 'type-error)))

(deftest chord-quality-table
  ;; Data only: +CHORD-QUALITIES+ and +ROMAN-QUALITIES+.
  (let ((rows music-theory::+chord-qualities+))
    (ok (= 15 (length rows)))
    (ok (= (length rows) (length (remove-duplicates (mapcar #'first rows)))))
    (ok (every (lambda (row) (and (keywordp (first row))
                                  (typep (second row) '(or null string))
                                  (every #'parse-interval (third row))))
               rows))
    (ok (every (lambda (row)
                 (let ((steps (mapcar (lambda (s) (interval-steps (parse-interval s))) (third row))))
                   (equal steps (sort (copy-list steps) #'<))))
               rows)
        "chord tones ascend")
    (ok (equal (mapcar #'first (subseq rows 0 12))
               (mapcar #'first music-theory::+roman-qualities+)))
    (ok (= 12 (length (remove-duplicates
                       (mapcar (lambda (row) (list (second row) (third row) (fifth row)))
                               music-theory::+roman-qualities+)
                       :test #'equal)))
        "case, ASCII marker and seventh-p pick one quality")
    (ok (= 12 (length (remove-duplicates
                       (mapcar (lambda (row) (list (second row) (fourth row) (fifth row)))
                               music-theory::+roman-qualities+)
                       :test #'equal)))
        "case, Unicode marker and seventh-p pick one quality")))

(deftest chord-quality-table-matches-music21
  ;; Data only: every roman fixture chord's pitches are its root plus the
  ;; intervals of its quality's row, spelled exactly (MT0 arithmetic).
  (let* ((rows (fixture "mt2-roman.sexp"))
         (bad (collect-mismatches (row rows)
                (destructuring-bind (kname text literal root bass inversion quality pitches &rest more)
                    row
                  (declare (ignore kname text literal bass inversion more))
                  (let ((start (parse-pitch (format nil "~A4" root))))
                    (null (set-exclusive-or
                           pitches
                           (cons root
                                 (mapcar (lambda (name)
                                           (pitch-class-string
                                            (pitch-spelling
                                             (transpose-pitch start (parse-interval name)))))
                                         (third (assoc quality music-theory::+chord-qualities+))))
                           :test #'string=)))))))
    (ok (null bad) (report bad))))

;;; Roman numerals: fixtures --------------------------------------------------

(deftest roman-fixtures
  ;; TEXT: chord-for and back (with :applied-to for applied rows); LITERAL:
  ;; ROMAN-FOR without a target. MIXTURE: music21's isMixture (non-applied rows).
  (let* ((rows (fixture "mt2-roman.sexp"))
         (bad (collect-mismatches (row rows)
                (destructuring-bind (kname text &rest more) row
                  (declare (ignore more))
                  (equalp (roman-fixture-chord row) (chord-for (r text) (k kname))))
                (string= (second row) (roman-name (r (second row))))
                (destructuring-bind (kname text literal &rest more) row
                  (declare (ignore text more))
                  (equalp (r literal) (roman-for (roman-fixture-chord row) (k kname))))
                (string= (third row) (roman-name (r (third row))))
                (destructuring-bind (kname text &rest more) row
                  (declare (ignore more))
                  (let ((target (roman-numeral-applied-to (r text))))
                    (or (null target)
                        (equalp (r text) (roman-for (roman-fixture-chord row) (k kname)
                                                    :applied-to target)))))
                (destructuring-bind (kname text literal root bass inversion quality pitches mixture
                                     &rest more)
                    row
                  (declare (ignore literal root bass inversion quality pitches more))
                  (or (eq mixture :applied)
                      (eq (and mixture t) (and (roman-mixture-p (r text) (k kname)) t)))))))
    (ok (= 97 (length rows)))
    (ok (null bad) (report bad))))

;;; Roman numerals: text ------------------------------------------------------

(deftest-parametrize parse-roman-accepts
    ((text degree alteration quality inversion target)
     ("I" 1 0 :major 0 nil)
     ("V7" 5 0 :dominant-7 0 nil)
     ("ii6/5" 2 0 :minor-7 1 nil)
     ("ii65" 2 0 :minor-7 1 nil)
     ("V/V" 5 0 :major 0 '(5 0 :major))
     ("vii°7/V" 7 0 :diminished-7 0 '(5 0 :major))
     ("viio7/V" 7 0 :diminished-7 0 '(5 0 :major))
     ("bVI" 6 -1 :major 0 nil)
     ("♭VI" 6 -1 :major 0 nil)
     ("iv" 4 0 :minor 0 nil)
     ("N6" 2 -1 :major 1 nil)
     ("N" 2 -1 :major 0 nil)
     ("N64" 2 -1 :major 2 nil)
     ("bII6" 2 -1 :major 1 nil)
     ("viiø7" 7 0 :half-diminished-7 0 nil)
     ("vii/o7" 7 0 :half-diminished-7 0 nil)
     ("iiø65" 2 0 :half-diminished-7 1 nil)
     ("V6/5/V" 5 0 :dominant-7 1 '(5 0 :major))
     ("V65/V" 5 0 :dominant-7 1 '(5 0 :major))
     ("V6/V" 5 0 :major 1 '(5 0 :major))
     ("V43" 5 0 :dominant-7 2 nil)
     ("V4/3" 5 0 :dominant-7 2 nil)
     ("V42" 5 0 :dominant-7 3 nil)
     ("V4/2" 5 0 :dominant-7 3 nil)
     ("V2" 5 0 :dominant-7 3 nil)
     ("I64" 1 0 :major 2 nil)
     ("I6/4" 1 0 :major 2 nil)
     ("IM7" 1 0 :major-7 0 nil)
     ("IVM65" 4 0 :major-7 1 nil)
     ("iM7" 1 0 :minor-major-7 0 nil)
     ("III+" 3 0 :augmented 0 nil)
     ("III+M7" 3 0 :augmented-major-7 0 nil)
     ("V+7" 5 0 :augmented-7 0 nil)
     ("#ivo7" 4 1 :diminished-7 0 nil)
     ("♯iv°7" 4 1 :diminished-7 0 nil)
     ("bbVII" 7 -2 :major 0 nil)
     ("##iv" 4 2 :minor 0 nil)
     ("V7/IV" 5 0 :dominant-7 0 '(4 0 :major))
     ("V/bVI" 5 0 :major 0 '(6 -1 :major))
     ("V/iv" 5 0 :major 0 '(4 0 :minor))
     ("viio/ii" 7 0 :diminished 0 '(2 0 :minor))
     (" V7 " 5 0 :dominant-7 0 nil)
     ("VII" 7 0 :major 0 nil)
     ("vii" 7 0 :minor 0 nil)
     ("vo" 5 0 :diminished 0 nil)
     ("viio42" 7 0 :diminished-7 3 nil)
     ("N6/V" 2 -1 :major 1 '(5 0 :major)))
  (ok (equalp (rn degree alteration quality inversion target) (parse-roman text))))

(deftest-parametrize roman-names
    ((text ascii unicode)
     ("ii6/5" "ii65" "ii65")
     ("N6" "bII6" "♭II6")
     ("V2" "V42" "V42")
     ("vii°7/V" "viio7/V" "vii°7/V")
     ("viiø7" "vii/o7" "viiø7")
     ("V6/5/V" "V65/V" "V65/V")
     ("bVI" "bVI" "♭VI")
     ("#ivo7" "#ivo7" "♯iv°7")
     ("bbVII" "bbVII" "𝄫VII")
     ("I6/4" "I64" "I64")
     ("III+M7" "III+M7" "III+M7")
     ("V/bVI" "V/bVI" "V/♭VI")
     ("iio6" "iio6" "ii°6")
     ("vii/o65/V" "vii/o65/V" "viiø65/V")
     ("##iv" "##iv" "𝄪iv")
     ("IVM65" "IVM65" "IVM65"))
  (ok (string= ascii (roman-name (r text))))
  (ok (string= unicode (roman-name (r text) :accidentals :unicode)))
  (ok (equalp (r text) (r unicode))))

(deftest-parametrize parse-roman-rejects
    ((text)
     ("")
     ("VIII")
     ("Vi")
     ("Io")
     ("v+")
     ("IM")
     ("iiø")
     ("V9")
     ("V/V/V")
     ("V/viio")
     ("V7/V7")
     ("V/")
     ("Ger65")
     (" V 7")
     ("IIII")
     ("V7b9")
     ("iiø6")
     ("N7")
     ("bN6")
     ("H")
     ("V+o")
     ("V/V6")
     ("/V")
     ("x")
     ("VI I")
     ("Vo")
     ("IM6")
     ("V/o")
     ("It6")
     ("V/o7"))
  (ok (signals-with-text (lambda () (parse-roman text)) 'invalid-roman-numeral text)))

(deftest parse-roman-use-value-restart
  (let ((fallback (rn 5 0 :dominant-7)))
    (ok (equalp fallback
                (handler-bind ((invalid-roman-numeral (lambda (c) (use-value fallback c))))
                  (parse-roman "V9"))))
    (ok (eq :roman
            (handler-case (parse-roman "Ger65")
              (chord-symbol-parse-error () :chord)
              (invalid-key () :key)
              (invalid-roman-numeral () :roman))))))

(deftest roman-round-trip
  ;; Every well-formed numeral: degrees, alterations -2..2, all qualities and
  ;; their inversions, with no target or one of four.
  (let* ((targets (list nil (rn 5 0 :major) (rn 4 0 :minor) (rn 6 -1 :major)))
         (numerals
           (loop for (quality nil nil nil seventh-p) in music-theory::+roman-qualities+
                 nconc (loop for degree from 1 to 7
                             nconc (loop for alteration from -2 to 2
                                         nconc (loop for inversion from 0 to (if seventh-p 3 2)
                                                     nconc (loop for target in targets
                                                                 collect (make-roman-numeral
                                                                          :degree degree
                                                                          :alteration alteration
                                                                          :quality quality
                                                                          :inversion inversion
                                                                          :applied-to target)))))))
         (bad (collect-mismatches (x numerals)
                (equalp x (parse-roman (roman-name x)))
                (equalp x (parse-roman (roman-name x :accidentals :unicode))))))
    (ok (= (* 7 5 (+ (* 4 3) (* 8 4)) 4) (length numerals)))
    (ok (null bad) (report bad))))

;;; Roman numerals: chords ----------------------------------------------------

(deftest-parametrize applied-chords
    ((kname text root quality bass)
     ("C major" "V/V" "D" :major nil)
     ("C major" "V7/V" "D" :dominant-7 nil)
     ("C major" "vii°7/V" "F#" :diminished-7 nil)
     ("C major" "viiø7/V" "F#" :half-diminished-7 nil)
     ("C major" "V65/V" "D" :dominant-7 "F#")
     ("C major" "V/iv" "C" :major nil)
     ("C major" "V/bVI" "Eb" :major nil)
     ("A minor" "V/III" "G" :major nil)
     ("A minor" "V/VII" "D" :major nil)
     ("A minor" "vii°7/iv" "C#" :diminished-7 nil)
     ("C# major" "V/V" "D#" :major nil)
     ("C# major" "V7/VII" "F##" :dominant-7 nil)
     ("Eb major" "viio7/ii" "E" :diminished-7 nil)
     ("C minor" "V7/iv" "C" :dominant-7 nil)
     ("C minor" "viio43/V" "F#" :diminished-7 "C")
     ("F major" "V/vi" "A" :major nil))
  (ok (equalp (cs root quality bass) (chord-for (r text) (k kname)))))

(deftest-parametrize roman-for-applied
    ((kname root quality bass target expected)
     ("C major" "D" :dominant-7 nil "V" "V7/V")
     ("C major" "F#" :diminished-7 nil "V" "viio7/V")
     ("C major" "F#" :diminished-7 "C" "V" "viio43/V")
     ("C major" "C" :dominant-7 "Bb" "IV" "V42/IV")
     ("A minor" "G" :major nil "III" "V/III")
     ("C major" "Eb" :major nil "bVI" "V/bVI")
     ("C major" "C" :major nil "iv" "V/iv")
     ("C major" "D" :major nil "V" "V/V")
     ("A minor" "D#" :diminished-7 nil "V" "viio7/V")
     ("C major" "F#" :half-diminished-7 "A" "V" "vii/o65/V")
     ("C major" "A" :dominant-7 nil "ii" "V7/ii")
     ("C major" "D" :major nil "ii" "I/ii"))
  (ok (equalp (r expected) (roman-for (cs root quality bass) (k kname) :applied-to (r target)))))

(deftest-parametrize roman-for-is-literal
    ((kname root quality bass expected)
     ("C major" "D" :major nil "II")
     ("C major" "D" :dominant-7 nil "II7")
     ("C major" "F#" :diminished-7 nil "#ivo7")
     ("C major" "Ab" :major nil "bVI")
     ("C major" "F" :minor nil "iv")
     ("C minor" "Ab" :major nil "VI")
     ("C minor" "A" :minor nil "vi")
     ("C minor" "A" :major nil "#VI")
     ("C minor" "B" :diminished nil "viio")
     ("C minor" "Bb" :major nil "VII")
     ("C minor" "B" :major nil "#VII")
     ("C minor" "B" :diminished-7 nil "viio7")
     ("C minor" "Db" :major "F" "bII6")
     ("C major" "C" :major "C" "I")
     ("C major" "G" :dominant-7 "F" "V42")
     ("C major" "C" :dominant-7 nil "I7")
     ("C major" "C" :major-7 nil "IM7")
     ("C minor" "Abb" :major nil "bVI")
     ("C minor" "B#" :diminished-7 nil "#viio7")
     ("C major" "E" :major "G#" "III6")
     ("C major" "G" :major "D" "V64")
     ("C major" "Bb" :major nil "bVII")
     ("E major" "C" :augmented nil "bVI+"))
  (ok (equalp (r expected) (roman-for (cs root quality bass) (k kname)))))

(deftest-parametrize mixture
    ((kname text expected)
     ("C major" "bVI" t)
     ("C major" "bIII" t)
     ("C major" "bVII" t)
     ("C major" "iv" t)
     ("C major" "iv6" t)
     ("C major" "i" t)
     ("C major" "v" t)
     ("C major" "iio" t)
     ("C major" "ii/o7" t)
     ("C major" "viio7" t)
     ("C major" "bVIM7" t)
     ("C major" "iv7" t)
     ("C major" "bVII7" t)
     ("C major" "IV" nil)
     ("C major" "V7" nil)
     ("C major" "I" nil)
     ("C major" "bII6" nil)
     ("C major" "vii/o7" nil)
     ("C major" "II" nil)
     ("C major" "V/V" nil)
     ("C major" "viio7/V" t)
     ("C major" "V/iv" nil)
     ("C minor" "I" t)
     ("C minor" "IV" t)
     ("C minor" "ii" t)
     ("C minor" "vi" t)
     ("C minor" "vii/o7" t)
     ("C minor" "IM7" t)
     ("C minor" "V" nil)
     ("C minor" "viio" nil)
     ("C minor" "viio7" nil)
     ("C minor" "VI" nil)
     ("C minor" "iv" nil)
     ("C minor" "bII6" nil)
     ("C minor" "III+" nil)
     ("C minor" "vii/o7/V" nil)
     ("C major" "bVI7" nil)
     ("C minor" "I7" nil))
  ;; The last two rows are deliberate differences from music21's isMixture,
  ;; which reads only the triad: Ab C Eb Gb is not a chord of C minor, and
  ;; C E G Bb is not a chord of C major.
  (ok (eq expected (and (roman-mixture-p (r text) (k kname)) t))))

(deftest mixture-in-major
  (let ((c-major (k "C major")))
    (ok (equalp (cs "Ab" :major) (chord-for (r "bVI") c-major)))
    (ok (equalp (r "bVI") (roman-for (cs "Ab" :major) c-major)))
    (ok (roman-mixture-p (r "bVI") c-major))
    (ok (equalp (cs "Ab" :major) (chord-for (r "VI") (k "C minor"))) "bVI in C is VI of C minor")
    (ok (equalp (cs "Abb" :major) (chord-for (r "bVI") (k "C minor"))) "bVI in C minor is Abb")))

(deftest roman-for-rejects-other-chords
  (let ((c-major (k "C major")))
    (dolist (chord (list (make-chord-symbol :root (pc "C") :quality :major :suspension 4)
                         (make-chord-symbol :root (pc "C") :quality :dominant-7 :extensions '(9))
                         (make-chord-symbol :root (pc "C") :quality :major :added '((9 . 0)))
                         (make-chord-symbol :root (pc "C") :quality :major :omitted '(3))
                         (make-chord-symbol :root (pc "C") :quality :dominant-7
                                            :alterations '((5 . -1)))
                         (cs "C" :major-6) (cs "C" :power)
                         (make-chord-symbol :no-chord-p t)
                         (cs "C" :major "D")
                         (cs "C" :major "Fb")))
      (ok (signals-type (lambda () (roman-for chord c-major)) 'music-theory-error)
          (prin1-to-string chord))))
  (ok (signals-type (lambda () (roman-for (cs "Cbb" :major) (k "C# major"))) 'music-theory-error)
      "three flats below the default root")
  (ok (signals-type (lambda () (roman-for (cs "D" :major) (k "C major")
                                          :applied-to (rn 7 0 :diminished)))
                    'invalid-roman-numeral)))

(deftest chord-for-rejects-malformed-numerals
  (let ((c-major (k "C major")))
    (dolist (roman (list (rn 1 0 :major 3)
                         (rn 1 0 :power)
                         (rn 1 0 :major-6)
                         (rn 5 0 :major 0 '(7 0 :diminished))
                         (make-roman-numeral :degree 5 :applied-to (rn 5 0 :major 1))
                         (make-roman-numeral :degree 5 :applied-to (rn 5 0 :major 0 '(5 0 :major)))))
      (ok (signals-with-text (lambda () (chord-for roman c-major)) 'invalid-roman-numeral nil)
          (prin1-to-string roman))))
  (ok (signals-with-text (lambda () (roman-name (rn 1 0 :major 3))) 'invalid-roman-numeral nil))
  (ok (signals-type (lambda () (chord-for (r "#III") (k "C# major"))) 'invalid-pitch)
      "E## major needs G###"))

;;; Values and conditions ---------------------------------------------------

(deftest mt2-values-are-immutable-and-readable
  (ok (not (fboundp '(setf key-tonic))))
  (ok (not (fboundp '(setf roman-numeral-degree))))
  (ok (not (fboundp '(setf chord-symbol-root))))
  (let ((*package* (find-package '#:music-theory/tests)))
    (dolist (x (list (make-key :tonic (pc "F#") :mode :minor)
                     (rn 7 0 :diminished-7 2 '(5 0 :major))
                     (cs "G" :dominant-7 "B")
                     (make-chord-symbol :root (pc "C") :quality :dominant-7 :extensions '(9)
                                        :alterations '((5 . -1)) :text "C9b5" :dialect :jazz)))
      (ok (equalp x (read-from-string (prin1-to-string x)))))))

(deftest mt2-conditions
  (ok (subtypep 'invalid-roman-numeral 'music-theory-error))
  (ok (not (subtypep 'invalid-roman-numeral 'invalid-key)))
  (let ((c (make-condition 'invalid-key :text "G#" :reason "eight sharps")))
    (ok (search "G#" (princ-to-string c)))
    (ok (search "eight sharps" (princ-to-string c)))))
