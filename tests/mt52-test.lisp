;;;; 0.5.2: the deciding rule (music-theory#19). The third value of
;;;; SPELL-SEQUENCE and of SPELL-MIDI names, for each note, the rule of
;;;; src/spell.lisp's header that decided it, :S0 .. :S7. The SPELL-SEQUENCE
;;;; rows are those of music-theory#19, computed from the 0.5.1 rules by a copy
;;;; of its speller that keeps each rule; their spellings and ambiguities are
;;;; 0.5.1's. The SPELL-MIDI rows are mt4's, with the rule worked out by hand.
;;;; Uses P (mt0), K and PC (mt2), COLLECT-MISMATCHES and REPORT (package),
;;;; SPELLED-NAMES, OPT, BASE-ROWS and TRANSPOSED-ROWS (mt4), CHROMATIC-ROWS
;;;; (mt51).

(in-package #:music-theory/tests)

(defparameter *spelling-rules* '(:s0 :s1 :s2 :s3 :s4 :s5 :s6 :s7)
  "The deciding rules of src/spell.lisp, in the header's order.")

(defun rule-row-key (designator)
  "The KEY of a row: PARSE-KEY of a string, MAKE-KEY of (tonic mode) for a key
outside the 30 signatures."
  (if (stringp designator)
      (k designator)
      (make-key :tonic (pc (first designator)) :mode (second designator))))

(defparameter *deciding-rule-rows*
  '(("D major" (62 66 67 68 69) ("D4" "F#4" "G4" "G#4" "A4") (1/3 3/8 1/2 43/60 2/11)
     (:s1 :s1 :s1 :s4 :s1))
    ("C major" (60 61 62) ("C4" "C#4" "D4") (1/3 7/8 1/18) (:s1 :s4 :s1))
    ("C major" (64 63 62) ("E4" "Eb4" "D4") (1/3 7/8 1/18) (:s1 :s4 :s1))
    ("C major" (64 68 71) ("E4" "G#4" "B4") (1/3 23/24 19/54) (:s1 :s5 :s1))
    ("C major" (60 66 60 66 60) ("C4" "F#4" "C4" "F#4" "C4") (1/3 17/24 10/27 2/3 13/33)
     (:s1 :s6 :s1 :s3 :s1))
    ("C major" (60 66 68) ("C4" "F#4" "G#4") (1/3 17/24 26/27) (:s1 :s6 :s5))
    ("C major" (68 68 69) ("G#4" "G#4" "A4") (1 7/8 1/18) (:s4 :s0 :s1))
    ("C major" (68) ("G#4") (1) (:s7))
    ("A minor" (64 66 68 69) ("E4" "F#4" "G#4" "A4") (1/6 23/48 41/54 3/20) (:s1 :s1 :s1 :s1))
    (("A#" :major) (68) ("G#4") (2/3) (:s2))
    ("G minor" (55 54 53 52 51 50) ("G3" "F#3" "F3" "E3" "Eb3" "D3") (0 5/6 23/54 9/20 25/33 5/36)
     (:s1 :s1 :s1 :s1 :s1 :s1)))
  "(key midis spelled ambiguities rules), the rows of music-theory#19. KEY is a
RULE-ROW-KEY designator. Values, not forms (deftest-parametrize :rows).")

(defparameter *spell-midi-rule-rows*
  '((61 "D major" nil "C#4" 1/2 :s1)
    (64 "C major" nil "E4" 1/3 :s1)
    (68 "A minor" nil "G#4" 5/6 :s1)
    (60 nil nil "C4" 1/3 :s1)
    (68 ("A#" :major) nil "G#4" 2/3 :s2)
    (61 nil nil "C#4" 5/6 :s6)
    (66 nil nil "F#4" 2/3 :s6)
    (61 nil "Db4" "Db4" 47/48 :s0)
    (64 "C major" "Fb4" "Fb4" 13/24 :s0)
    (73 nil "Db4" "Db5" 47/48 :s3)
    (68 "C major" "E4" "G#4" 23/24 :s5)
    (66 "C major" "Eb4" "Gb4" 37/48 :s5)
    (61 "C major" "C4" "Db4" 7/8 :s5)
    (68 nil nil "G#4" 1 :s7))
  "(midi key previous spelled ambiguity rule) for SPELL-MIDI: mt4's SPELL-MIDI-RULES
rows, one or two per rule (S4 never decides SPELL-MIDI). KEY is NIL or a
RULE-ROW-KEY designator, PREVIOUS NIL or PARSE-PITCH text.")

;;; Rows -------------------------------------------------------------------------

(deftest-parametrize spell-sequence-deciding-rule-rows
    ((key midis expected ambiguities rules) :rows *deciding-rule-rows*)
  (multiple-value-bind (pitches amb got)
      (ignore-errors (spell-sequence midis :key (rule-row-key key)))
    (ok (equal expected (ignore-errors (spelled-names pitches)))
        (format nil "~S ~S: ~S" key midis (ignore-errors (spelled-names pitches))))
    (ok (equal ambiguities amb) (format nil "ambiguities ~S" amb))
    (ok (equal rules got) (format nil "~S ~S: rules ~S" key midis got))))

(deftest-parametrize spell-midi-deciding-rule-rows
    ((midi key previous expected ambiguity rule) :rows *spell-midi-rule-rows*)
  (multiple-value-bind (pitch amb got)
      (ignore-errors (spell-midi midi :key (opt #'rule-row-key key) :previous (opt #'p previous)))
    (ok (and (spelled-pitch-p pitch) (string= expected (pitch-name pitch)))
        (format nil "~D: ~A" midi (and (spelled-pitch-p pitch) (pitch-name pitch))))
    (ok (eql ambiguity amb) (format nil "ambiguity ~S" amb))
    (ok (eq rule got) (format nil "~D in ~S after ~S: rule ~S" midi key previous got))))

(deftest deciding-rule-rows-cover-every-rule
  (ok (null (set-exclusive-or *spelling-rules*
                              (remove-duplicates (reduce #'append *deciding-rule-rows* :key #'fifth))))
      "each of S0-S7 decides a note of SPELL-SEQUENCE's rows")
  (ok (null (set-exclusive-or (remove :s4 *spelling-rules*)
                              (remove-duplicates (mapcar #'sixth *spell-midi-rule-rows*))))
      "each of S0-S7 but S4 decides a SPELL-MIDI row"))

;;; S7 and AMBIGUOUS-SPELLING ----------------------------------------------------

(deftest deciding-rule-s7-whatever-the-handler
  ;; In C major 62 68 68 is D4, then a tie (S7) and its run (S0); 68 alone a tie.
  (flet ((sequence-with (handler)
           (handler-bind ((ambiguous-spelling handler))
             (multiple-value-bind (pitches amb rules) (spell-sequence '(62 68 68) :key (k "C major"))
               (declare (ignore amb))
               (list (spelled-names pitches) rules))))
         (midi-with (handler)
           (handler-bind ((ambiguous-spelling handler))
             (multiple-value-bind (pitch amb rule) (spell-midi 68)
               (declare (ignore amb))
               (list (pitch-name pitch) rule)))))
    (let ((use-ab (lambda (c) (use-value (p "Ab4") c)))
          (decline (lambda (c) (declare (ignore c)) nil)))
      (ok (equal '(("D4" "G#4" "G#4") (:s1 :s7 :s0)) (sequence-with decline)) "declining")
      (ok (equal '(("D4" "G#4" "G#4") (:s1 :s7 :s0)) (sequence-with #'muffle-warning)) "MUFFLE-WARNING")
      (ok (equal '(("D4" "Ab4" "Ab4") (:s1 :s7 :s0)) (sequence-with use-ab)) "USE-VALUE")
      (ok (equal '("G#4" :s7) (midi-with decline)) "SPELL-MIDI, declining")
      (ok (equal '("G#4" :s7) (midi-with #'muffle-warning)) "SPELL-MIDI, MUFFLE-WARNING")
      (ok (equal '("Ab4" :s7) (midi-with use-ab)) "SPELL-MIDI, USE-VALUE"))))

;;; Shape, runs and determinism over the corpora ---------------------------------

(defun corpus-rows ()
  "(key names midis) for every melody, transposition and chromatic line."
  (append (base-rows) (transposed-rows) (chromatic-rows)))

(defun run-continuation-p (midis)
  "For each of MIDIS, true when it has the MIDI number of the note just before it."
  (loop for (before . rest) on (cons nil midis)
        while rest
        collect (eql before (first rest))))

(deftest deciding-rule-shape
  (multiple-value-bind (pitches amb rules) (spell-sequence '())
    (ok (and (null pitches) (null amb) (null rules)) "no notes: NIL, NIL and NIL"))
  (ok (equal '(:s1 :s1 :s1) (nth-value 2 (spell-sequence '(60 62 64) :key (k "C major") :window 0))))
  (ok (= 3 (length (multiple-value-list (spell-midi 60)))) "SPELL-MIDI: three values")
  (ok (= 3 (length (multiple-value-list (spell-sequence '(60))))) "SPELL-SEQUENCE: three values")
  (dolist (use-key '(t nil))
    (let ((bad (collect-mismatches (row (corpus-rows))
                 (destructuring-bind (key-text names midis) row
                   (declare (ignore names))
                   (multiple-value-bind (pitches amb rules)
                       (spell-sequence midis :key (and use-key (k key-text)))
                     (and (= (length midis) (length pitches) (length amb) (length rules))
                          (every (lambda (rule) (member rule *spelling-rules*)) rules)
                          ;; :S0 marks exactly the notes of a run after its first.
                          (equal (run-continuation-p midis)
                                 (mapcar (lambda (rule) (eq rule :s0)) rules))))))))
      (ok (null bad) (format nil "~:[without~;with~] the key: ~A" use-key (report (mapcar #'caar bad)))))))

(deftest deciding-rule-determinism
  ;; The same notes give the same rules, in fresh lists, and the rule changes
  ;; neither spelling nor ambiguity.
  (let ((bad (collect-mismatches (row (corpus-rows))
               (destructuring-bind (key-text names midis) row
                 (declare (ignore names))
                 (let ((key (k key-text)))
                   (multiple-value-bind (pitches-1 amb-1 rules-1) (spell-sequence midis :key key)
                     (multiple-value-bind (pitches-2 amb-2 rules-2) (spell-sequence midis :key key)
                       (and (equal rules-1 rules-2)
                            (or (null rules-1) (not (eq rules-1 rules-2)))
                            (equalp pitches-1 pitches-2)
                            (equal amb-1 amb-2)))))))))
    (ok (null bad) (report (mapcar #'caar bad))))
  ;; A note alone: SPELL-MIDI decides it by the rule SPELL-SEQUENCE does.
  (ok (every (lambda (key-text)
               (let ((key (k key-text)))
                 (loop for midi from 0 to 127
                       always (multiple-value-bind (pitch amb rule) (spell-midi midi :key key)
                                (multiple-value-bind (pitches amb-s rules) (spell-sequence (list midi) :key key)
                                  (and (equalp pitch (first pitches))
                                       (eql amb (first amb-s))
                                       (eq rule (first rules))
                                       (not (eq rule :s0))
                                       (not (eq rule :s4))))))))
             '("C major" "A minor" "Gb major" "D# minor" "C# major" "Ab minor"))
      "SPELL-MIDI without PREVIOUS = a one-note SPELL-SEQUENCE"))
