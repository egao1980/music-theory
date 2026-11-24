;;;; MT4: spelling, key detection, transposition between keys, enharmonic keys.
;;;; Fixture vectors come from music21 10.5.2 (tests/fixtures/PROVENANCE.md): 50
;;;; public-domain melodies re-encoded by us, music21's MIDI numbers for them,
;;;; its key rankings under three profiles, and its transposition of every melody
;;;; to two other keys. Hand-written rows follow the rules in src/spell.lisp,
;;;; src/key-detect.lisp and src/transpose.lisp; they were cross-checked against
;;;; an independent reference implementation of those rules (no mismatches).
;;;; Uses P (mt0), K, PC, CALL and SIGNALS-TYPE (mt2), CP, CH and SAME-CHORD-P (mt3).

(in-package #:music-theory/tests)

(defparameter *profiles* '(:krumhansl-kessler :temperley :aarden))

(defun melodies () (fixture "mt4-melodies.sexp"))

(defun melody (id)
  (or (find id (melodies) :key #'first :test #'string=)
      (error "no melody ~S" id)))

(defun melody-events (row)
  "(spelled-pitch . duration) for every note of a mt4-melodies.sexp row."
  (destructuring-bind (id key names durations midis) row
    (declare (ignore id key midis))
    (mapcar (lambda (name duration) (cons (p name) duration)) names durations)))

(defun ev (spec)
  "A histogram event from a test row: a string names a pitch (\"F#4\") or a pitch
class (\"Cb\"); anything else stays as it is."
  (flet ((pitch (x)
           (if (stringp x)
               (if (find-if #'digit-char-p x) (p x) (pc x))
               x)))
    (if (consp spec) (cons (pitch (car spec)) (cdr spec)) (pitch spec))))

(defun spelled-names (pitches) (mapcar #'pitch-name pitches))

(defun opt (function value)
  "FUNCTION of VALUE, or NIL for NIL (a function, so constant rows fold nothing away)."
  (and value (funcall function value)))

(defun ranking-names (ranking)
  (mapcar (lambda (entry) (key-name (car entry))) ranking))

(defun same-key-p (a b)
  "Same tonic pitch class and mode (F# major and Gb major are the same key here)."
  (and (= (pitch-class (key-tonic a)) (pitch-class (key-tonic b)))
       (eq (key-mode a) (key-mode b))))

(defun ranking-matches-p (ranking expected)
  "RANKING (DETECT-KEY's) has EXPECTED's keys in EXPECTED's order, each correlation a
DOUBLE-FLOAT within 1d-9 of the expected one."
  (and (= (length ranking) (length expected))
       (every (lambda (got want)
                (and (key-p (car got))
                     (string= (key-name (car got)) (first want))
                     (typep (cdr got) 'double-float)
                     (< (abs (- (cdr got) (second want))) 1d-9)))
              ranking expected)))

(defun spelling-accuracy (rows &key use-key)
  "Correctly spelled notes and all notes, as two values, over ROWS of (key names
midis): SPELL-SEQUENCE of MIDIS, with the key when USE-KEY, against NAMES."
  (let ((right 0) (total 0))
    (dolist (row rows (values right total))
      (destructuring-bind (key names midis) row
        (let ((got (ignore-errors
                    (spelled-names (if use-key
                                       (spell-sequence midis :key (k key))
                                       (spell-sequence midis))))))
          (incf total (length names))
          (incf right (count t (mapcar #'equal names (or got (make-list (length names)))))))))))

(defun base-rows ()
  (mapcar (lambda (row) (list (second row) (third row) (fifth row))) (melodies)))

(defun transposed-rows ()
  (mapcar (lambda (row) (destructuring-bind (id from to iv names midis) row
                          (declare (ignore id from iv))
                          (list to names midis)))
          (fixture "mt4-transposed.sexp")))

(defun quiet-output (thunk)
  "Call THUNK; return its first value and everything it wrote to *ERROR-OUTPUT*."
  (let* ((text (make-string-output-stream))
         (value (let ((*error-output* text)) (funcall thunk))))
    (values value (get-output-stream-string text))))

;;; Data tables ------------------------------------------------------------------

(deftest key-profiles-match-music21
  (let ((rows (fixture "mt4-profiles.sexp")))
    (ok (equal *profiles* (mapcar #'first music-theory::+key-profiles+)))
    (ok (equal *profiles* (mapcar #'first rows)))
    (dolist (row rows)
      (destructuring-bind (name major minor) row
        (destructuring-bind (scale ours-major ours-minor)
            (rest (assoc name music-theory::+key-profiles+))
          (ok (and (= 12 (length ours-major) (length ours-minor))
                   (every (lambda (n w) (= (/ n scale) w)) ours-major major)
                   (every (lambda (n w) (= (/ n scale) w)) ours-minor minor))
              (format nil "~(~A~) is the published table" name)))))))

(deftest detect-key-candidates-table
  (let ((keys (mapcar #'k music-theory::+detect-key-candidates+)))
    (ok (= 24 (length keys)))
    (ok (equal music-theory::+detect-key-candidates+ (mapcar #'key-name keys)) "KEY-NAME text")
    (ok (loop for key in keys for index from 0
              always (and (= (floor index 2) (pitch-class (key-tonic key)))
                          (eq (if (evenp index) :major :minor) (key-mode key))))
        "by tonic pitch class, major before minor")
    (ok (every (lambda (key) (<= (abs (key-signature key)) 6)) keys) "at most six accidentals")
    (ok (equal '("Eb minor" "F# major")
               (mapcar #'key-name (remove-if-not (lambda (key) (= 6 (abs (key-signature key)))) keys)))
        "the six-accidental ties")))

(deftest spelling-key-positions-table
  (ok (equal '((:major -1 0 1 2 3 4 5) (:minor -4 -3 -1 0 1 2 5)) music-theory::+key-positions+))
  ;; The positions are the scale's (raised seventh in minor) for every one of the 30 keys.
  (ok (every (lambda (row)
               (let* ((key (k (first row)))
                      (tonic (pitch-fifths (key-tonic key)))
                      (offsets (rest (assoc (key-mode key) music-theory::+key-positions+)))
                      (scale (scale-degrees key :variant :harmonic)))
                 (null (set-exclusive-or (mapcar (lambda (o) (+ tonic o)) offsets)
                                         (mapcar #'pitch-fifths scale)))))
             (fixture "mt2-keys.sexp")))
  (ok (equal "C major" music-theory::+default-spelling-key+)))

;;; Histograms -------------------------------------------------------------------

(deftest-parametrize pitch-class-histogram-cells
    ((events weight expected)
     ('((60 . 1/4) (64 . 1/8) (67 . 1/4) (72 . 1/2)) :duration #(3/4 0 0 0 1/8 0 0 1/4 0 0 0 0))
     ('((60 . 1/4) (64 . 1/8) (67 . 1/4) (72 . 1/2)) :count #(2 0 0 0 1 0 0 1 0 0 0 0))
     ('(60 62 64 62) :duration #(1 0 2 0 1 0 0 0 0 0 0 0))
     ('(60 62 64 62) :count #(1 0 2 0 1 0 0 0 0 0 0 0))
     ('(("F#4" . 1/2) ("Gb3" . 1/4) ("E##" . 1)) :duration #(0 0 0 0 0 0 7/4 0 0 0 0 0))
     ('(("Cb" . 3) ("B#3" . 1) ("Dbb5" . 1/2)) :duration #(3/2 0 0 0 0 0 0 0 0 0 0 3))
     ('((-11 . 1) (127 . 2) (0 . 0)) :duration #(0 1 0 0 0 0 0 2 0 0 0 0))
     ('((-11 . 1) (127 . 2) (0 . 0)) :count #(1 1 0 0 0 0 0 1 0 0 0 0))
     ('((69 . 0.5d0) (69 . 1/4)) :duration #(0 0 0 0 0 0 0 0 0 0.75d0 0 0))
     ('() :duration #(0 0 0 0 0 0 0 0 0 0 0 0)))
  (let ((h (pitch-class-histogram (mapcar #'ev events) :weight weight)))
    (ok (and (simple-vector-p h) (= 12 (length h))))
    (ok (every #'= expected h) (format nil "~S" h))))

(deftest pitch-class-histogram-defaults-and-errors
  (ok (equalp #(1/4 0 0 0 0 0 0 0 0 0 0 0) (pitch-class-histogram '((60 . 1/4)))) ":duration by default")
  (ok (not (eq (pitch-class-histogram '()) (pitch-class-histogram '()))) "a fresh vector")
  (ok (let ((row (melody "fur-elise")))
        (equalp (pitch-class-histogram (melody-events row))
                (pitch-class-histogram (mapcar #'cons (fifth row) (fourth row)))))
      "spelled pitches and MIDI numbers give the same cells")
  (ok (signals-type (lambda () (call #'pitch-class-histogram '((60 . -1/4)))) 'type-error) "negative duration")
  (ok (signals-type (lambda () (call #'pitch-class-histogram '((60 . :long)))) 'type-error) "non-real duration")
  (ok (signals-type (lambda () (call #'pitch-class-histogram '((c4 . 1/4)))) 'type-error) "a symbol is no pitch")
  (ok (signals-type (lambda () (call #'pitch-class-histogram '((60 . 1/4)) :weight :velocity)) 'type-error))
  (ok (signals-type (lambda () (call #'pitch-class-histogram '((60 . 1/4)) :weight nil)) 'type-error))
  (ok (signals-type (lambda () (call #'pitch-class-histogram #(60 62))) 'type-error) "a list, not a vector")
  (ok (signals-type (lambda () (call #'pitch-class-histogram '(60 . 62))) 'type-error) "a proper list"))

;;; Key detection ----------------------------------------------------------------

(deftest detect-key-melodies-match-music21
  (let* ((rows (fixture "mt4-key-detection.sexp"))
         (bad (collect-mismatches (row rows)
                (destructuring-bind (id profile expected) row
                  (ranking-matches-p
                   (detect-key (pitch-class-histogram (melody-events (melody id))) :profiles profile)
                   expected)))))
    (ok (= (* 50 3) (length rows)))
    (ok (null bad) (report (mapcar (lambda (b) (subseq (first b) 0 2)) bad)))))

(deftest detect-key-histograms-match-music21
  (let* ((rows (fixture "mt4-histograms.sexp"))
         (bad (collect-mismatches (row rows)
                (destructuring-bind (label histogram profile expected) row
                  (declare (ignore label))
                  (ranking-matches-p (detect-key histogram :profiles profile) expected))
                (destructuring-bind (label histogram profile expected) row
                  (declare (ignore label))
                  (ranking-matches-p (detect-key (coerce histogram 'vector) :profiles profile)
                                     expected)))))
    (ok (= (* 9 3) (length rows)))
    (ok (null bad) (report (mapcar (lambda (b) (list (first (first b)) (third (first b)) (second b))) bad)))))

(deftest detect-key-ranking
  (let ((ranking (detect-key #(1 0 1 0 1 1 0 1 0 1 0 1))))
    (ok (= 24 (length ranking)))
    (ok (null (set-exclusive-or (ranking-names ranking) music-theory::+detect-key-candidates+
                                :test #'string=))
        "every candidate once")
    (ok (every (lambda (a b) (>= (cdr a) (cdr b))) ranking (rest ranking)) "best first")
    (ok (every (lambda (entry) (<= -1d0 (cdr entry) 1d0)) ranking))
    (ok (string= "C major" (key-name (car (first ranking)))) "the C major scale"))
  ;; Exact ties keep the candidate order: with only C sounding, the Aarden profile
  ;; scores two pairs of keys alike (its weights 0.145624 and 0.702494 repeat).
  (let ((names (ranking-names (detect-key #(1 0 0 0 0 0 0 0 0 0 0 0) :profiles :aarden))))
    (ok (= 1 (- (position "B major" names :test #'string=) (position "E major" names :test #'string=)))
        "E major (C is its b6) just before B major (C is its b2): candidate order")
    (ok (= 1 (- (position "G# minor" names :test #'string=) (position "F# minor" names :test #'string=)))
        "F# minor just before G# minor: candidate order"))
  (ok (string= "Eb minor" (key-name (car (first (detect-key #(0 0 0 2 0 0 1 0 0 0 1 0)))))) "Eb, not D#, minor")
  (ok (string= "F# major" (key-name (car (first (detect-key #(0 1 0 0 0 0 2 0 0 0 1 0)))))) "F#, not Gb, major"))

(deftest-parametrize detect-key-no-evidence
    ((histogram)
     (#(0 0 0 0 0 0 0 0 0 0 0 0))
     (#(1 1 1 1 1 1 1 1 1 1 1 1))
     ('(3/2 3/2 3/2 3/2 3/2 3/2 3/2 3/2 3/2 3/2 3/2 3/2)))
  (ok (null (detect-key histogram)) "a constant histogram ranks nothing")
  (ok (null (detect-key histogram :profiles :aarden))))

(deftest detect-key-profiles-argument
  (let* ((h #(7 0 5 0 7 16 0 16 0 15 6 0))
         (table (rest (assoc :krumhansl-kessler music-theory::+key-profiles+)))
         (kk (detect-key h)))
    (ok (equal (ranking-names kk) (ranking-names (detect-key h :profiles :krumhansl-kessler)))
        ":krumhansl-kessler is the default")
    (ok (equal (ranking-names kk) (ranking-names (detect-key h :profiles (rest table))))
        "a (major minor) list of the caller's")
    (ok (equal (ranking-names kk)
               (ranking-names (detect-key h :profiles (list (mapcar (lambda (x) (* 7 x)) (second table))
                                                            (coerce (third table) 'vector)))))
        "scaling a profile changes nothing")
    (ok (every (lambda (a b) (< (abs (- (cdr a) (cdr b))) 1d-12))
               kk (detect-key h :profiles (rest table))))
    (ok (not (equal (ranking-names kk) (ranking-names (detect-key h :profiles :temperley))))))
  (ok (signals-type (lambda () (detect-key #(1 0 0 0 0 0 0 0 0 0 0 0)
                                           :profiles (list (make-list 12 :initial-element 1)
                                                           (make-list 12 :initial-element 2))))
                    'music-theory-error)
      "a constant profile")
  (ok (signals-type (lambda () (call #'detect-key #(1 0 0 0 0 0 0 0 0 0 0 0) :profiles :bellman)) 'type-error))
  (ok (signals-type (lambda () (call #'detect-key #(1 0 0 0 0 0 0 0 0 0 0) )) 'type-error) "11 cells")
  (ok (signals-type (lambda () (call #'detect-key #(1 0 0 0 0 0 0 0 0 0 0 -1))) 'type-error) "a negative cell")
  (ok (signals-type (lambda () (call #'detect-key '(1 0 0 0 0 0 0 0 0 0 0 :x))) 'type-error))
  (ok (signals-type (lambda () (call #'detect-key "C major")) 'type-error)))

(deftest-parametrize detect-key-accuracy
    ((profile top-1 top-2)
     ;; Calibrated on the 50 melodies: what music21's own analysis scores
     ;; (PROVENANCE.md). DETECT-KEY reproduces its rankings, so it scores the same.
     (:krumhansl-kessler 39 47)
     (:temperley 45 49)
     (:aarden 41 48))
  (let ((first-hits 0) (second-hits 0))
    (dolist (row (melodies))
      (let* ((key (k (second row)))
             (ranking (ignore-errors
                       (detect-key (pitch-class-histogram (melody-events row)) :profiles profile)))
             (hits (mapcar (lambda (entry) (same-key-p key (car entry)))
                           (subseq ranking 0 (min 2 (length ranking))))))
        (when (first hits) (incf first-hits))
        (when (some #'identity hits) (incf second-hits))))
    (ok (>= first-hits top-1) (format nil "~(~A~) top-1 ~D/50" profile first-hits))
    (ok (>= second-hits top-2) (format nil "~(~A~) top-2 ~D/50" profile second-hits))))

;;; Spelling one note --------------------------------------------------------------

(deftest-parametrize spell-midi-rules
    ((midi key previous expected ambiguity)
     ;; S1: the key's spelling
     (61 "D major" nil "C#4" 1/2)
     (61 "Ab major" nil "Db4" 1/2)
     (64 "C major" nil "E4" 1/3)
     (68 "A minor" nil "G#4" 5/6)
     (68 "C minor" nil "Ab4" 2/3)
     (57 "Bb minor" nil "A3" 5/6)
     (60 "C# major" nil "B#3" 1/2)
     (65 "F# major" nil "E#4" 1/2)
     (71 "Gb major" nil "Cb5" 1/2)
     (62 "Eb minor" nil "D4" 5/6)
     (62 "D# minor" nil "C##4" 5/6)
     ;; no key: C major
     (60 nil nil "C4" 1/3)
     (62 nil nil "D4" 0)
     (0 nil nil "C-1" 1/3)
     (127 nil nil "G9" 1/6)
     (77 nil "E#4" "F5" 11/16)
     ;; S6: nearer the center
     (61 nil nil "C#4" 5/6)
     (63 nil nil "Eb4" 5/6)
     (66 nil nil "F#4" 2/3)
     (70 nil nil "Bb4" 2/3)
     (64 "Gb major" nil "Fb4" 2/3)
     ;; S0, S3: PREVIOUS
     (61 nil "Db4" "Db4" 47/48)
     (64 "C major" "Fb4" "Fb4" 13/24)
     (73 nil "Db4" "Db5" 47/48)
     ;; S5: no augmented or diminished interval with PREVIOUS
     (68 "C major" "E4" "G#4" 23/24)
     (68 "C major" "F4" "Ab4" 15/16)
     (66 "C major" "G4" "F#4" 11/16)
     (66 "C major" "Eb4" "Gb4" 37/48)
     (61 nil "D4" "C#4" 5/6)
     (63 nil "D4" "Eb4" 5/6)
     (61 "C major" "C4" "Db4" 7/8)
     ;; S7: midway, HI
     (68 nil nil "G#4" 1)
     (68 "C major" nil "G#4" 1))
  (multiple-value-bind (pitch amb)
      (let ((*error-output* (make-broadcast-stream)))
        (spell-midi midi :key (opt #'k key) :previous (opt #'p previous)))
    (ok (and (spelled-pitch-p pitch) (string= expected (pitch-name pitch)) (= midi (pitch-midi pitch)))
        (format nil "~D: ~A" midi (and (spelled-pitch-p pitch) (pitch-name pitch))))
    (ok (and (rationalp amb) (= ambiguity amb)) (format nil "ambiguity ~S" amb))))

(deftest spell-midi-ambiguous-spelling
  (let (seen)
    (ok (string= "G#4" (pitch-name (handler-bind ((ambiguous-spelling (lambda (c) (setf seen c))))
                                     (spell-midi 68))))
        "a handler that declines leaves HI")
    (ok (typep seen 'ambiguous-spelling))
    (ok (and seen (eql 68 (ambiguous-spelling-midi seen))))
    (ok (and seen (equal '("Ab4" "G#4") (mapcar #'pitch-name (ambiguous-spelling-candidates seen))))
        "LO, then HI")
    (ok (and seen (search "68" (princ-to-string seen)))))
  (ok (string= "Ab4" (pitch-name (handler-bind ((ambiguous-spelling
                                                  (lambda (c) (use-value (p "Ab4") c))))
                                   (spell-midi 68))))
      "USE-VALUE chooses")
  (ok (string= "G#4" (pitch-name (handler-bind ((ambiguous-spelling #'muffle-warning))
                                   (spell-midi 68))))
      "MUFFLE-WARNING keeps HI")
  (ok (signals-type (lambda () (handler-bind ((ambiguous-spelling (lambda (c) (use-value (p "A4") c))))
                                 (spell-midi 68)))
                    'type-error)
      "USE-VALUE needs a spelling of the same MIDI number")
  (multiple-value-bind (pitch output) (quiet-output (lambda () (spell-midi 68)))
    (ok (string= "G#4" (pitch-name pitch)))
    (ok (string= "" output) "SIGNAL, not WARN: nothing printed"))
  (ok (null (let (seen)
              (handler-bind ((ambiguous-spelling (lambda (c) (setf seen c))))
                (spell-midi 61))
              seen))
      "no signal when a rule decides"))

(deftest spell-midi-errors
  (ok (signals-type (lambda () (call #'spell-midi 128)) 'type-error))
  (ok (signals-type (lambda () (call #'spell-midi -1)) 'type-error))
  (ok (signals-type (lambda () (call #'spell-midi 60.0)) 'type-error))
  (ok (signals-type (lambda () (call #'spell-midi 60 :key "C major")) 'type-error))
  (ok (signals-type (lambda () (call #'spell-midi 60 :previous 59)) 'type-error))
  (ok (signals-type (lambda () (call #'spell-midi 60 :previous (pc "B"))) 'type-error)))

;;; Spelling a sequence ------------------------------------------------------------

(deftest-parametrize spell-sequence-rules
    ((midis key window expected ambiguities)
     ;; S4: resolution by semitone
     ('(62 63 64) "C major" 8 '("D4" "D#4" "E4") '(0 5/6 11/54))
     ('(64 63 62) "C major" 8 '("E4" "Eb4" "D4") '(1/3 7/8 1/18))
     ('(67 68 67) "C major" 8 '("G4" "Ab4" "G4") '(1/6 47/48 1/27))
     ('(69 68 69) "C major" 8 '("A4" "G#4" "A4") '(1/6 47/48 1/27))
     ('(69 70 71) "C major" 8 '("A4" "A#4" "B4") '(1/6 11/16 1/3))
     ('(67 66 65) "C major" 8 '("G4" "Gb4" "F4") '(1/6 11/16 1/3))
     ('(62 61 60) "C major" 8 '("D4" "Db4" "C4") '(0 5/6 11/54))
     ('(73 74 75 76) "B major" 8 '("C#5" "C##5" "D#5" "E5") '(0 5/6 11/54 13/20))
     ('(63 62 61) "Ab major" 8 '("Eb4" "Ebb4" "Db4") '(1/6 11/16 1/3))
     ('(76 75 76 75 76 71 74 72 69) "A minor" 8
      '("E5" "D#5" "E5" "D#5" "E5" "B4" "D5" "C5" "A4")
      '(1/6 47/48 1/27 13/15 1/22 1/8 5/13 29/42 13/90))
     ;; S5: intervals with the note before
     ('(64 68 71) "C major" 8 '("E4" "G#4" "B4") '(1/3 23/24 19/54))
     ('(65 68 72) "C major" 8 '("F4" "Ab4" "C5") '(1/2 15/16 1/6))
     ;; runs: spelled once, resolved past the run
     ('(61 61 62) "C major" 8 '("C#4" "C#4" "D4") '(5/6 35/48 5/27))
     ('(68 68 69) "C major" 8 '("G#4" "G#4" "A4") '(1 7/8 1/18))
     ;; S3: the window keeps an accidental; without a window S4 decides
     ('(66 65 61 65 64) "B minor" 8 '("F#4" "E#4" "C#4" "E#4" "E4") '(1/6 47/48 11/54 17/20 13/33))
     ('(66 65 61 65 64) "B minor" 0 '("F#4" "E#4" "C#4" "F4" "E4") '(1/6 1 1/3 1 1/6))
     ;; S6: the window moves the center; without it the tie falls to S7
     ('(70 75 74 68) "C major" 8 '("Bb4" "Eb5" "D5" "Ab4") '(2/3 3/4 1/6 17/20))
     ('(70 75 74 68) "C major" 0 '("Bb4" "Eb5" "D5" "G#4") '(2/3 5/6 0 1))
     ('(60 64 67) "C major" 8 '("C4" "E4" "G4") '(1/3 3/8 1/6))
     ('(60 64 67) "C major" 0 '("C4" "E4" "G4") '(1/3 1/3 1/6))
     ;; no key: the detected key, else C major
     ('(66 68 70 71 73 75 77 78) nil 8 '("F#4" "G#4" "A#4" "B4" "C#5" "D#5" "E#5" "F#5")
      '(1/3 1/24 10/27 1/2 4/33 2/9 7/13 1/3))
     ('(63 65 67 68 70 72 74 75) nil 8 '("Eb4" "F4" "G4" "Ab4" "Bb4" "C5" "D5" "Eb5")
      '(1/3 1/24 10/27 1/2 4/33 2/9 7/13 1/3))
     ('(60 61 62 63 64 65 66 67 68 69 70 71) nil 8
      '("C4" "C#4" "D4" "D#4" "E4" "F4" "F#4" "G4" "G#4" "A4" "A#4" "B4")
      '(1/3 7/8 1/18 53/60 2/11 2/3 43/78 9/28 13/15 1/18 38/45 7/30))
     ('(72 71 70 69 68 67 66 65 64 63 62 61 60) nil 8
      '("C5" "B4" "Bb4" "A4" "Ab4" "G4" "Gb4" "F4" "E4" "Eb4" "D4" "Db4" "C4")
      '(1/3 13/24 37/54 13/60 32/33 1/18 61/78 25/84 5/9 59/90 4/15 17/18 1/45)))
  (multiple-value-bind (pitches amb)
      (spell-sequence midis :key (opt #'k key) :window window)
    (ok (equal expected (ignore-errors (spelled-names pitches))) (format nil "~S" (ignore-errors (spelled-names pitches))))
    (ok (and (every #'rationalp amb) (equal ambiguities amb)) (format nil "~S" amb))))

(deftest spell-sequence-ambiguous-spelling
  (let ((seen '()))
    (ok (equal '("D4" "G#4")
               (spelled-names (handler-bind ((ambiguous-spelling (lambda (c) (push c seen))))
                                (spell-sequence '(62 68) :key (k "C major")))))
        "S7 takes HI")
    (ok (= 1 (length seen)) "signalled once")
    (ok (and seen (equal '("Ab4" "G#4") (mapcar #'pitch-name (ambiguous-spelling-candidates (first seen)))))))
  (ok (equal '("D4" "Ab4")
             (spelled-names (handler-bind ((ambiguous-spelling (lambda (c) (use-value (p "Ab4") c))))
                              (spell-sequence '(62 68) :key (k "C major")))))
      "USE-VALUE chooses")
  (ok (equal '("D4" "G#4" "G#4")
             (spelled-names (let ((n 0))
                              (handler-bind ((ambiguous-spelling (lambda (c) (incf n) (muffle-warning c))))
                                (prog1 (spell-sequence '(62 68 68) :key (k "C major"))
                                  (ok (= 1 n) "a run signals once"))))))
      "MUFFLE-WARNING keeps HI for the whole run")
  ;; A chosen spelling enters the window: the later G#/Ab follows it (S3).
  (ok (equal '("D4" "Ab4" "B4" "Ab4")
             (spelled-names (handler-bind ((ambiguous-spelling (lambda (c) (use-value (p "Ab4") c))))
                              (spell-sequence '(62 68 71 68) :key (k "C major"))))))
  (multiple-value-bind (pitches output) (quiet-output (lambda () (spell-sequence '(62 68) :key (k "C major"))))
    (ok (equal '("D4" "G#4") (ignore-errors (spelled-names pitches))))
    (ok (string= "" output) "SIGNAL, not WARN")))

(deftest spell-sequence-shape-and-errors
  (multiple-value-bind (pitches amb) (spell-sequence '())
    (ok (and (null pitches) (null amb)) "no notes"))
  (multiple-value-bind (pitches amb) (spell-sequence '(60 62 64 65 67))
    (ok (and (= 5 (length pitches)) (= 5 (length amb))))
    (ok (every (lambda (a) (and (rationalp a) (<= 0 a 1))) amb)))
  (ok (equal '("C4" "D4" "E4") (spelled-names (spell-sequence '(60 62 64) :key (k "C major") :window 0))))
  (ok (signals-type (lambda () (call #'spell-sequence '(60 128))) 'type-error))
  (ok (signals-type (lambda () (call #'spell-sequence '(60 nil))) 'type-error))
  (ok (signals-type (lambda () (call #'spell-sequence #(60 62))) 'type-error) "a list")
  (ok (signals-type (lambda () (call #'spell-sequence '(60 . 62))) 'type-error) "a proper list")
  (ok (signals-type (lambda () (call #'spell-sequence '(60) :window -1)) 'type-error))
  (ok (signals-type (lambda () (call #'spell-sequence '(60) :window 1.5)) 'type-error))
  (ok (signals-type (lambda () (call #'spell-sequence '(60) :key "C major")) 'type-error)))

(deftest-parametrize spell-sequence-accuracy
    ((label rows use-key threshold)
     ;; The brief's thresholds. On these melodies music21's speller scores 98.35%
     ;; with the key and 94.23% without, music-spelling 97.94% and 96.35%, and the
     ;; rules here 100% (PROVENANCE.md: calibration).
     ("melodies with the key" (base-rows) t 98/100)
     ("melodies without a key" (base-rows) nil 95/100)
     ;; The same melodies moved to remote keys by music21: with the key only, since
     ;; without one F# major and Gb major sound alike.
     ("transposed melodies with the key" (transposed-rows) t 98/100))
  (multiple-value-bind (right total) (spelling-accuracy rows :use-key use-key)
    (ok (plusp total))
    (ok (>= (/ right total) threshold)
        (format nil "~A: ~D/~D = ~,2F%" label right total (* 100 (/ right total))))))

(deftest spell-sequence-properties
  ;; Octaves: transposing MIDIS by an octave moves every spelling by an octave.
  (let ((bad (collect-mismatches (row (melodies))
               (let ((midis (fifth row)) (key (k (second row))))
                 (equalp (mapcar (lambda (pitch)
                                  (make-spelled-pitch :letter (spelled-pitch-letter pitch)
                                                      :alter (spelled-pitch-alter pitch)
                                                      :octave (1+ (spelled-pitch-octave pitch))))
                                (spell-sequence midis :key key))
                        (spell-sequence (mapcar (lambda (m) (+ m 12)) midis) :key key))))))
    (ok (null bad) (report (mapcar #'caar bad))))
  ;; S1: with the key, every note of the key's positions takes the key's spelling.
  (let ((bad (collect-mismatches (row (append (base-rows) (transposed-rows)))
               (destructuring-bind (key-text names midis) row
                 (declare (ignore names))
                 (let* ((key (k key-text))
                        (scale (scale-degrees key :variant :harmonic))
                        (pitches (spell-sequence midis :key key)))
                   (every (lambda (pitch midi)
                            (let ((member (find (mod midi 12) scale :key #'pitch-class)))
                              (or (null member) (equalp member (pitch-spelling pitch)))))
                          pitches midis))))))
    (ok (null bad) (report (mapcar #'caar bad))))
  ;; Every spelling is one of the candidates: the right MIDI number, two accidentals at most.
  (let ((bad (collect-mismatches (row (base-rows))
               (every (lambda (pitch midi) (= midi (pitch-midi pitch)))
                      (spell-sequence (third row))
                      (third row)))))
    (ok (null bad) (report (mapcar #'caar bad)))))

;;; Transposition ----------------------------------------------------------------

(deftest-parametrize transpose-to-key-rows
    ((pitch from to expected)
     ("F#4" "C major" "D major" "G#4")
     ("F#4" "C major" "Db major" "G4")
     ("F#4" "C major" "C# major" "F##4")
     ("C4" "C major" "G major" "G3")
     ("C4" "C major" "F major" "F4")
     ("C4" "C major" "F# major" "F#4")
     ("C4" "C major" "Gb major" "Gb3")
     ("C#4" "C# major" "Db major" "Db4")
     ("D4" "D major" "Db major" "Db4")
     ("E4" "C major" "A minor" "C#4")
     ("A4" "A minor" "C major" "C5")
     ("B3" "C major" "Cb major" "Bb3")
     ("Bb4" "F major" "E major" "A4")
     ("G#4" "A minor" "Bb minor" "A4")
     ("E#4" "B minor" "Bb minor" "E4")
     ("Fb4" "Db major" "C# major" "E4")
     ("C##4" "D# minor" "Eb minor" "D4")
     ("D4" "C major" "C major" "D4"))
  (let ((got (transpose-to-key (p pitch) (k from) (k to))))
    (ok (and (spelled-pitch-p got) (string= expected (pitch-name got)))
        (format nil "~A ~A → ~A: ~A" pitch from to (and (spelled-pitch-p got) (pitch-name got))))))

(deftest-parametrize transpose-to-key-classes
    ((class from to expected)
     ("F#" "C major" "D major" "G#")
     ("F#" "C major" "Db major" "G")
     ("Eb" "C minor" "C# minor" "E")
     ("B" "C major" "Gb major" "F"))
  (let ((got (transpose-to-key (pc class) (k from) (k to))))
    (ok (and (pitch-class-name-p got) (string= expected (pitch-class-string got))))))

(deftest transpose-to-key-matches-music21
  (let* ((rows (fixture "mt4-transposed.sexp"))
         (bad (collect-mismatches (row rows)
                (destructuring-bind (id from to iv names midis) row
                  (declare (ignore iv midis))
                  (equal names
                         (mapcar (lambda (name) (pitch-name (transpose-to-key (p name) (k from) (k to))))
                                 (third (melody id)))))
                (destructuring-bind (id from to iv names midis) row
                  (declare (ignore iv midis))
                  (equal (third (melody id))
                         (mapcar (lambda (name) (pitch-name (transpose-to-key (p name) (k to) (k from))))
                                 names))))))
    (ok (= 100 (length rows)))
    (ok (null bad) (report (mapcar (lambda (b) (list (subseq (first b) 0 3) (second b))) bad)))))

(deftest transpose-to-key-chord-symbols
  ;; Chord symbols transpose and respell the same way as notes (MT3 by keys).
  (let ((pairs '(("C major" "Db major") ("C major" "C# major") ("C major" "Cb major")
                 ("A minor" "Bb minor") ("E major" "Ab major") ("Bb major" "F# major")))
        (chords '("G7/B" "Cm7b5(b9)/Gb" "F#maj7#11" "Bbm6/9" "E7alt" "N.C.")))
    (let ((bad (loop for (from to) in pairs
                     nconc (loop for text in chords
                                 for chord = (cp text :jazz)
                                 for moved = (ignore-errors (transpose-chord-symbol chord (list (k from) (k to))))
                                 unless (and moved
                                             (equalp (chord-symbol-root moved)
                                                     (and (chord-symbol-root chord)
                                                          (ignore-errors
                                                           (transpose-to-key (chord-symbol-root chord) (k from) (k to)))))
                                             (equalp (chord-symbol-bass moved)
                                                     (and (chord-symbol-bass chord)
                                                          (ignore-errors
                                                           (transpose-to-key (chord-symbol-bass chord) (k from) (k to))))))
                                   collect (list text from to)))))
      (ok (null bad) (report bad))))
  (ok (string= "Ab7/C" (print-chord-symbol (transpose-chord-symbol (cp "G7/B") (list (k "C major") (k "Db major"))))))
  ;; A semitone up from C major is C# major; the enharmonic choice respells it as Db.
  (let ((target (choose-enharmonic-key (k "C# major"))))
    (ok (string= "Db major" (key-name target)))
    (ok (string= "Ab7/C" (print-chord-symbol (transpose-chord-symbol (cp "G7/B") (list (k "C major") target)))))
    (ok (string= "Ab4" (pitch-name (transpose-to-key (p "G4") (k "C major") target))))))

(deftest transpose-to-key-errors
  (ok (signals-type (lambda () (transpose-to-key (p "F##4") (k "C major") (k "C# major"))) 'invalid-pitch)
      "beyond two accidentals")
  (ok (signals-type (lambda () (transpose-to-key (pc "Bbb") (k "C major") (k "Cb major"))) 'invalid-pitch))
  (ok (signals-type (lambda () (call #'transpose-to-key "C4" (k "C major") (k "D major"))) 'type-error))
  (ok (signals-type (lambda () (call #'transpose-to-key (p "C4") "C major" (k "D major"))) 'type-error))
  (ok (signals-type (lambda () (call #'transpose-to-key (p "C4") (k "C major") nil)) 'type-error))
  (ok (signals-type (lambda () (call #'transpose-to-key 60 (k "C major") (k "D major"))) 'type-error)))

;;; Enharmonic keys ----------------------------------------------------------------

(defun kk* (tonic mode)
  "A KEY from a tonic string and a mode, also beyond the 30 keys."
  (make-key :tonic (pc tonic) :mode mode))

(deftest-parametrize choose-enharmonic-key-rows
    ((tonic mode args expected)
     ("C#" :major '() "Db major")
     ("Cb" :major '() "B major")
     ("A#" :minor '() "Bb minor")
     ("Ab" :minor '() "G# minor")
     ("F#" :major '() "F# major")
     ("Gb" :major '() "Gb major")
     ("D#" :minor '() "D# minor")
     ("Eb" :minor '() "Eb minor")
     ("D" :major '() "D major")
     ("B" :major '() "B major")
     ("Db" :major '() "Db major")
     ;; beyond the 30 keys
     ("G#" :major '() "Ab major")
     ("D#" :major '() "Eb major")
     ("A#" :major '() "Bb major")
     ("E#" :major '() "F major")
     ("B#" :major '() "C major")
     ("Fb" :major '() "E major")
     ("Cb" :minor '() "B minor")
     ("E#" :minor '() "F minor")
     ("Dbb" :major '() "C major")
     ("E##" :major '() "F# major")
     ;; MAX-ACCIDENTALS and PREFER
     ("C#" :major '(:max-accidentals 7) "C# major")
     ("Cb" :major '(:max-accidentals 7) "Cb major")
     ("C#" :major '(:max-accidentals 7 :prefer :flats) "Db major")
     ("Db" :major '(:max-accidentals 7 :prefer :sharps) "C# major")
     ("F#" :major '(:prefer :flats) "Gb major")
     ("Gb" :major '(:prefer :sharps) "F# major")
     ("Eb" :minor '(:prefer :sharps) "D# minor")
     ("B" :major '(:max-accidentals 4) "B major")
     ("Cb" :major '(:max-accidentals 4) "B major")
     ("C#" :major '(:max-accidentals 0) "Db major")
     ("F#" :major '(:max-accidentals 0) "F# major")
     ("F#" :major '(:max-accidentals 0 :prefer :flats) "Gb major")
     ("E##" :major '(:prefer :flats) "Gb major")
     ("G#" :minor '(:max-accidentals 7 :prefer :flats) "Ab minor"))
  (let ((got (apply #'choose-enharmonic-key (kk* tonic mode) args)))
    (ok (and (key-p got) (string= expected (key-name got)))
        (format nil "~A ~(~A~) ~S: ~A" tonic mode args (and (key-p got) (key-name got))))))

(deftest choose-enharmonic-key-properties
  ;; Every key of every mode with a tonic of at most two accidentals: the result is
  ;; one of the 30 keys, sounds the same, and keeps the mode.
  (let ((bad '()))
    (dolist (mode '(:major :minor))
      (loop for fifths from -15 to 19
            for key = (make-key :tonic (fifths-pitch-class fifths) :mode mode)
            do (dolist (args '(() (:max-accidentals 0) (:max-accidentals 7) (:prefer :sharps) (:prefer :flats)))
                 (let ((got (ignore-errors (apply #'choose-enharmonic-key key args))))
                   (unless (ignore-errors (and (key-p got)
                                               (<= -7 (key-signature got) 7)
                                               (same-key-p key got)))
                     (push (list (key-name key) args) bad))))))
    (ok (null bad) (report bad)))
  (ok (every (lambda (row)
               (let ((key (k (first row))))
                 (if (<= (abs (key-signature key)) 6)
                     (equalp key (choose-enharmonic-key key))
                     (= 5 (abs (key-signature (choose-enharmonic-key key)))))))
             (fixture "mt2-keys.sexp"))
      "the 30 keys: as given up to six accidentals, else the five-accidental equivalent"))

(deftest choose-enharmonic-key-errors
  (ok (signals-type (lambda () (call #'choose-enharmonic-key (k "C major") :max-accidentals 8)) 'type-error))
  (ok (signals-type (lambda () (call #'choose-enharmonic-key (k "C major") :max-accidentals -1)) 'type-error))
  (ok (signals-type (lambda () (call #'choose-enharmonic-key (k "C major") :max-accidentals nil)) 'type-error))
  (ok (signals-type (lambda () (call #'choose-enharmonic-key (k "C major") :prefer :both)) 'type-error))
  (ok (signals-type (lambda () (call #'choose-enharmonic-key "C# major")) 'type-error)))

;;; Conditions -------------------------------------------------------------------

(deftest ambiguous-spelling-condition
  (ok (subtypep 'ambiguous-spelling 'music-theory-warning))
  (let ((c (make-condition 'ambiguous-spelling :midi 68 :candidates (list (p "Ab4") (p "G#4")))))
    (ok (eql 68 (ambiguous-spelling-midi c)))
    (ok (search "Ab4" (princ-to-string c)))
    (ok (search "G#4" (princ-to-string c)))))
