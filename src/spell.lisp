;;;; MT4 spelling: MIDI numbers to spelled pitches, by distance on the line of fifths.
;;;;
;;;; SPELL-MIDI midi &key key previous → (values spelled-pitch ambiguity)
;;;; SPELL-SEQUENCE midis &key key (window 8) → (values pitches ambiguities)
;;;;   MIDI is an (INTEGER 0 127) and MIDIS a proper list of them; KEY a KEY or
;;;;   NIL; PREVIOUS a SPELLED-PITCH or NIL; WINDOW a non-negative integer.
;;;;   Anything else is a TYPE-ERROR. SPELL-SEQUENCE returns two fresh lists as
;;;;   long as MIDIS (NIL and NIL for no notes): the SPELLED-PITCHes and, for
;;;;   each note, its ambiguity, a rational from 0 to 1.
;;;;
;;;; Own rules, not an import: music-spelling (Apache-2.0) was evaluated for an
;;;; unmodified import and rejected. Its penalties can carry a key only as the
;;;; starting accidental table of its first block of notes, a single note
;;;; ignores penalties and table alike (61 in Db major is C#), it returns no
;;;; per-note score, it keeps global state, and it fails on a sequence whose
;;;; length leaves one note in the last block. tests/fixtures/PROVENANCE.md has
;;;; the figures. Its ideas survive as rules S3 (parsimony), S4 (direction) and
;;;; S5 (augmented and diminished intervals).
;;;;
;;;; Candidates. The spellings of MIDI number m are the SPELLED-PITCHes with
;;;; PITCH-MIDI m and at most two accidentals. On the line of fifths they are the
;;;; positions f with 7f ≡ m (mod 12) in -15..19: two or three, 12 apart (60:
;;;; Dbb -12, C 0, B# 12; 68: Ab -4, G# 8). Position f and m give the pitch:
;;;; FIFTHS-PITCH-CLASS f names the letter and alter, and the octave is the one
;;;; whose PITCH-MIDI is m (B#3 and Cb5 for 60 and 71).
;;;;
;;;; The key. Its positions K are the scale's, with the raised seventh in minor:
;;;;   major  T + {-1 0 1 2 3 4 5}      (C major: F C G D A E B)
;;;;   minor  T + {-4 -3 -1 0 1 2 5}    (A minor: F C D A E B G#)
;;;; where T is (PITCH-FIFTHS (KEY-TONIC key)); for the 30 keys these are the
;;;; PITCH-FIFTHS of (SCALE-DEGREES key) and (SCALE-DEGREES key :variant
;;;; :harmonic). Without a KEY, SPELL-SEQUENCE takes the first key of
;;;;   (detect-key (pitch-class-histogram midis :weight :count))
;;;; or C major when that is NIL (no notes, or every pitch class equally often:
;;;; the chromatic scale). SPELL-MIDI without a KEY uses C major.
;;;;
;;;; The center of note i, c(i), is the mean of K together with the positions of
;;;; the WINDOW notes before note i (fewer at the start), as spelled; for
;;;; SPELL-MIDI, of K together with PREVIOUS's position, when given. It is an
;;;; exact rational; C major alone has the center 2 (D, the middle of F..B).
;;;;
;;;; Runs. Consecutive notes with the same MIDI number form a run, spelled once,
;;;; at its first note, i; every note of the run takes that spelling. The note
;;;; before the run is note i-1 and the note after it the first note past the
;;;; run. Rule by rule, the first that applies decides:
;;;;   S0  (SPELL-MIDI only) PREVIOUS has MIDI number m: PREVIOUS's spelling.
;;;;   S1  Key: a candidate in K. At most one is, since K spans fewer than 12
;;;;       positions. Every scale note keeps the key's spelling: B#3 in C#
;;;;       major, Cb5 in Gb major, D4 in Eb minor, C##4 in D# minor.
;;;;   Otherwise LO is the largest candidate at or below c(i) and HI the
;;;;   smallest above it: the flatter and the sharper spelling nearest the
;;;;   center (Eb and D# in C major, D and C## in G# minor).
;;;;   S2  One side: when only LO or only HI exists, that one.
;;;;   S3  Consistency: the latest of the WINDOW notes before note i with m's
;;;;       pitch class, when its spelling is LO or HI: that spelling, so a
;;;;       chromatic note keeps its accidental (in B minor, F# E# C# E# E: the
;;;;       second E# keeps the first one's spelling). SPELL-MIDI: PREVIOUS,
;;;;       when it has m's pitch class and its spelling is LO or HI.
;;;;   S4  Resolution (SPELL-SEQUENCE only): the note after the run is one
;;;;       semitone above m: HI; one below: LO. The step is then diatonic:
;;;;       C major D D# E, E Eb D, G Ab G, A G# A; C## resolving to D# in B
;;;;       major, Ebb to Db in Ab major.
;;;;   S5  Interval: when exactly one of LO and HI lies within 5 positions of
;;;;       the note before the run (SPELL-MIDI: PREVIOUS), a third, fourth or
;;;;       other interval that is neither augmented nor diminished, that one:
;;;;       C major E G# B, F Ab C.
;;;;   S6  Center: the one of LO and HI nearer c(i).
;;;;   S7  Tie: HI, after signalling AMBIGUOUS-SPELLING (below).
;;;;
;;;; Ambiguity. For note i with MIDI number m, d is the distance from c(i) to
;;;; the nearest integer f with 7f ≡ m (mod 12), so 0 ≤ d ≤ 6, and the
;;;; ambiguity is d/6: 0 at the center, 1 midway between two spellings. Each
;;;; note of a run has its own center. SPELL-MIDI: d from its center. In C
;;;; major with no window, C 1/3, D 0, F 1/2, F# 2/3, C# 5/6, G# 1.
;;;;
;;;; AMBIGUOUS-SPELLING is signalled with SIGNAL, not WARN, so it is silent
;;;; unless handled: MIDI is m, CANDIDATES the list (LO HI) as SPELLED-PITCHes
;;;; of m. Two restarts surround it: USE-VALUE, whose value (a SPELLED-PITCH
;;;; whose PITCH-MIDI is m, else TYPE-ERROR) becomes the run's spelling, and
;;;; MUFFLE-WARNING, which keeps HI. A handler that declines also leaves HI. The
;;;; spelling chosen enters the window like any other.
;;;;
;;;; Properties: transposing MIDIS by octaves moves every spelling by the same
;;;; octaves; with a KEY, every note of the key's positions is spelled from them.

(in-package #:music-theory)

(defparameter +key-positions+
  '((:major -1 0 1 2 3 4 5)
    (:minor -4 -3 -1 0 1 2 5))
  "Per mode, the line-of-fifths positions of the key's spelled notes relative to
the tonic: the major scale, and the harmonic minor scale (raised seventh). Data.")

(defparameter +default-spelling-key+ "C major"
  "The key SPELL-MIDI uses without a KEY, and SPELL-SEQUENCE when it has no KEY and
DETECT-KEY returns NIL (KEY-NAME text). Data.")

;;; Kernel: exact positions on the line of fifths ---------------------------------

(defun %midi-list-p (object)
  "True for a proper list of MIDI numbers 0..127."
  (do ((tail object (rest tail)))
      ((atom tail) (null tail))
    (unless (typep (first tail) '(integer 0 127))
      (return nil))))

(defun %candidates (midi)
  "The line-of-fifths positions of MIDI's spellings, ascending: the f in -15..19 with
7f ≡ MIDI (mod 12), two or three, 12 apart."
  (loop for f from (- (mod (+ (* 7 midi) 15) 12) 15) to 19 by 12
        collect f))

(defun %position-pitch (fifths midi)
  "The SPELLED-PITCH at line-of-fifths position FIFTHS whose PITCH-MIDI is MIDI:
(12 60) is B#3, (-7 71) Cb5."
  (let* ((class (fifths-pitch-class fifths))
         (letter (pitch-class-name-letter class))
         (alter (pitch-class-name-alter class)))
    (make-spelled-pitch :letter letter :alter alter
                        :octave (1- (floor (- midi (aref +letter-semitones+ letter) alter) 12)))))

(defun %key-positions (key)
  "K: the line-of-fifths positions of KEY's notes, a fresh list (+KEY-POSITIONS+)."
  (let ((tonic (pitch-fifths (key-tonic key))))
    (mapcar (lambda (offset) (+ tonic offset))
            (rest (assoc (key-mode key) +key-positions+)))))

(defun %ambiguity (midi center)
  "d/6, d the distance from CENTER to the nearest integer f with 7f ≡ MIDI (mod 12)."
  (let ((r (mod (- center (mod (* 7 midi) 12)) 12)))
    (/ (min r (- 12 r)) 6)))

(defun %ambiguous-spelling (midi lo hi)
  "Rule S7: signal AMBIGUOUS-SPELLING for MIDI, midway between the positions LO and HI,
and return the position chosen. USE-VALUE takes a SPELLED-PITCH of MIDI (anything
else is a TYPE-ERROR); MUFFLE-WARNING, or a handler that declines, keeps HI."
  (or (restart-case
          ;; A literal SIGNAL form, so both restarts are associated with the condition.
          (signal 'ambiguous-spelling
                  :midi midi
                  :candidates (list (%position-pitch lo midi) (%position-pitch hi midi)))
        (use-value (value)
          :report "Spell the note with a SPELLED-PITCH of its MIDI number."
          :interactive (lambda ()
                         (format *query-io* "~&Spelled pitch to use: ")
                         (finish-output *query-io*)
                         (list (parse-pitch (read-line *query-io*))))
          (check-type value spelled-pitch)
          (unless (= midi (pitch-midi value))
            (error 'type-error :datum (pitch-midi value) :expected-type `(eql ,midi)))
          (pitch-fifths value))
        (muffle-warning ()
          :report "Keep the sharper spelling."
          hi))
      hi))

(defun %spell-choice (midi center positions before recent next)
  "Rules S0-S7 (file header) for the MIDI number MIDI, the first that applies:
the line-of-fifths position chosen and the rule's name, as two values. CENTER is the
note's center c(i) and POSITIONS the key's, K. BEFORE is the note just before,
(midi . position), or NIL: PREVIOUS for SPELL-MIDI, note i-1 in a sequence. RECENT
is the position of the latest window note with MIDI's pitch class, or NIL. NEXT is
the MIDI number of the first note past the run, or NIL (always NIL for SPELL-MIDI).
S0 is also the run rule: a note with the MIDI number of the note just before it
belongs to that note's run and takes its spelling, so a run is decided once, at its
first note. This is the one place that holds the rules."
  (let* ((candidates (%candidates midi))
         (in-key (find-if (lambda (f) (member f positions)) candidates))
         (lo (find-if (lambda (f) (<= f center)) candidates :from-end t))
         (hi (find-if (lambda (f) (> f center)) candidates)))
    (flet ((near-before-p (f)
             (<= (abs (- f (cdr before))) 5)))
      (cond ((and before (= midi (car before))) (values (cdr before) "S0"))
            (in-key (values in-key "S1"))
            ((null hi) (values lo "S2"))
            ((null lo) (values hi "S2"))
            ((and recent (or (= recent lo) (= recent hi))) (values recent "S3"))
            ((eql next (1+ midi)) (values hi "S4"))
            ((eql next (1- midi)) (values lo "S4"))
            ;; HI - LO = 12, so at most one of them lies within 5: "exactly one".
            ((and before (near-before-p lo)) (values lo "S5"))
            ((and before (near-before-p hi)) (values hi "S5"))
            ((< (- center lo) (- hi center)) (values lo "S6"))
            ((> (- center lo) (- hi center)) (values hi "S6"))
            (t (values (%ambiguous-spelling midi lo hi) "S7"))))))

(defun %spell-notes (midis key window &optional seed)
  "Spell the MIDI numbers MIDIS in KEY with WINDOW notes of context: (values
positions ambiguities), two fresh lists as long as MIDIS. SEED, (midi . position) or
NIL, is a note spelled before MIDIS (SPELL-MIDI's PREVIOUS): it enters the window,
and so the center and rule S3, and it is the note before the first (S0, S5)."
  (let* ((offset (if seed 1 0))
         (n (+ offset (length midis)))
         (notes (make-array n))         ; MIDI numbers, SEED's first
         (spelled (make-array n))       ; positions, as spelled
         (sums (make-array (1+ n) :initial-element 0)) ; (svref sums j) = Σ spelled[0..j-1]
         (positions (%key-positions key))
         (key-sum (reduce #'+ positions))
         (key-count (length positions))
         (chosen '())
         (ambiguities '()))
    (when seed
      (setf (svref notes 0) (car seed)
            (svref spelled 0) (cdr seed)
            (svref sums 1) (cdr seed)))
    (replace notes midis :start1 offset)
    (loop for i from offset below n
          for midi = (svref notes i)
          for start = (max 0 (- i window))
          for center = (/ (+ key-sum (- (svref sums i) (svref sums start)))
                          (+ key-count (- i start)))
          for position = (%spell-choice
                          midi center positions
                          (and (plusp i) (cons (svref notes (1- i)) (svref spelled (1- i))))
                          (loop for j from (1- i) downto start
                                when (= (mod (svref notes j) 12) (mod midi 12))
                                  return (svref spelled j))
                          (loop for j from (1+ i) below n
                                unless (= midi (svref notes j))
                                  return (svref notes j)))
          do (setf (svref spelled i) position
                   (svref sums (1+ i)) (+ (svref sums i) position))
             (push position chosen)
             (push (%ambiguity midi center) ambiguities))
    (values (nreverse chosen) (nreverse ambiguities))))

;;; Functions ----------------------------------------------------------------------

(defun spell-midi (midi &key key previous)
  "Spell MIDI in KEY after PREVIOUS (see the file header): (values pitch ambiguity).
The note is spelled as a one-note sequence after PREVIOUS, with a window of one."
  (check-type midi (integer 0 127))
  (check-type key (or null key))
  (check-type previous (or null spelled-pitch))
  (multiple-value-bind (positions ambiguities)
      (%spell-notes (list midi) (or key (parse-key +default-spelling-key+)) 1
                    (and previous (cons (pitch-midi previous) (pitch-fifths previous))))
    (values (%position-pitch (first positions) midi) (first ambiguities))))

(defun spell-sequence (midis &key key (window 8))
  "Spell the MIDI numbers MIDIS in KEY (or the detected key), WINDOW notes of
context: (values pitches ambiguities) (see the file header)."
  (check-type midis (satisfies %midi-list-p) "a proper list of MIDI numbers 0..127")
  (check-type key (or null key))
  (check-type window (integer 0 *))
  (let ((key (or key
                 (car (first (detect-key (pitch-class-histogram midis :weight :count))))
                 (parse-key +default-spelling-key+))))
    (multiple-value-bind (positions ambiguities) (%spell-notes midis key window)
      (values (mapcar #'%position-pitch positions midis) ambiguities))))
