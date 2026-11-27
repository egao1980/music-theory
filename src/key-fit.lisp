;;;; MT5 key fit with a tuning offset (0.6.0, music-theory#22).
;;;;
;;;; Sung and played pitch centres arrive as MIDI numbers with cents (61.37) and
;;;; rarely at A4 = 440 Hz. Rounded and given to DETECT-KEY, a take 50 cents flat
;;;; reads as a semitone down, or smears across two keys. FIT-KEY searches the
;;;; key and one global tuning offset together.
;;;;
;;;; FIT-KEY events &key hint (profiles :krumhansl-kessler) → a KEY-FIT.
;;;;   EVENTS    a proper list. Each event is (pitch . weight), or a bare pitch,
;;;;             which counts as (pitch . 1). A pitch is a REAL MIDI number with
;;;;             cents in its fraction (61.37 is C#4 and 37 cents). A weight is a
;;;;             non-negative REAL, a duration in any unit (only ratios matter).
;;;;   HINT      NIL (default) or a KEY the caller expects, any KEY (not only the
;;;;             30 with signatures -7..7).
;;;;   PROFILES  as for DETECT-KEY: :KRUMHANSL-KESSLER, :TEMPERLEY, :AARDEN or a
;;;;             list (major minor) of two sequences of 12 reals.
;;;;   Errors    checked in this order: EVENTS, HINT and PROFILES with CHECK-TYPE
;;;;             (a TYPE-ERROR with a STORE-VALUE restart, as everywhere here);
;;;;             then a constant profile, MUSIC-THEORY-ERROR (REASON "constant
;;;;             key profile"), as DETECT-KEY; then the evidence (No evidence).
;;;;             Every pitch and weight is taken as RATIONAL: every quantity but
;;;;             a square root is exact.
;;;;
;;;; Offsets   the 100 integers d in -50 … 49, in cents: how far the take lies
;;;;           above equal temperament at A4 = 440 Hz (positive = sharp). One
;;;;           offset holds for the whole take. +50 is not searched. A take 50
;;;;           cents sharp of C major is 50 cents flat of Db major, so the key
;;;;           absorbs whole semitones and every tuning has one reading: offset
;;;;           -50 with the tonic a semitone up. +KEY-FIT-OFFSETS+ lists the
;;;;           offsets in tie order: 0 -1 1 -2 2 … -49 49 -50.
;;;; Fold      at offset d, (pitch-class-histogram events′) of the events with
;;;;           every pitch lowered by d/100 (q = (rational pitch) - d/100) and
;;;;           every weight taken as RATIONAL. PITCH-CLASS-HISTOGRAM splits a
;;;;           real pitch between the two classes around it in proportion to its
;;;;           nearness (src/key-detect.lisp), so the fold moves continuously
;;;;           with d. Rounding instead would give one histogram for every offset
;;;;           that moves no pitch across a half semitone: an in-tune take would
;;;;           fit equally well at any offset from -49 to 49.
;;;; Score     for a candidate key K of DETECT-KEY (+DETECT-KEY-CANDIDATES+) and
;;;;           an offset d. c(K, d) is the covariance of the fold with K's mode
;;;;           profile rotated to its tonic (DETECT-KEY's numerator) and v_K that
;;;;           profile's variance:
;;;;             score(K, d) = c(K, d) / sqrt(v_K · H)
;;;;           H is the largest histogram variance Σ (h(i) - h̄)² among the 100
;;;;           folds. H is common to every pair, so the 2400 pairs rank by
;;;;           c / sqrt(v): DETECT-KEY's exact comparison, sign(c1)·c1²·v2 >
;;;;           sign(c2)·c2²·v1. At a fold of variance H the score is DETECT-KEY's
;;;;           correlation for that fold; elsewhere it is smaller in magnitude,
;;;;           so -1 ≤ score ≤ 1. Pearson r with each fold's own variance would
;;;;           reward smearing: under Krumhansl-Kessler, 28 of MT4's 50 in-tune
;;;;           melodies would fit best 3 to 46 cents off. A score is reported as
;;;;           DETECT-KEY reports a correlation: the exact c²/(v_K·H) rounded
;;;;           once to a DOUBLE-FLOAT, its square root, the sign of c.
;;;; Best      the pair of highest score is KEY-FIT-KEY and KEY-FIT-OFFSET. Equal
;;;;           scores take the smaller |d|, then the smaller d (-7 before 7), then
;;;;           the candidate order.
;;;; Ranking   KEY-FIT-RANKING: the 24 candidates at KEY-FIT-OFFSET as
;;;;           (key . score) conses, best first, equal scores in candidate order.
;;;;           That is DETECT-KEY's order for the fold at that offset. Its first
;;;;           entry is (KEY-FIT-KEY . KEY-FIT-CORRELATION). Its keys, and so
;;;;           KEY-FIT-KEY, are the shared KEYs of +DETECT-KEY-KEYS+, as in
;;;;           DETECT-KEY's ranking (EQ to them, never mutated). Every key is
;;;;           ranked at the take's one offset, not at its own. At its own offset
;;;;           each key a semitone from the best would borrow half the best score
;;;;           at ±50 cents and crowd the list.
;;;; Midis, deviations  KEY-FIT-MIDIS and KEY-FIT-DEVIATIONS have one entry per
;;;;           event, in order, zero weights included. With q = (rational pitch)
;;;;           - KEY-FIT-OFFSET/100, the MIDI number is the nearest integer,
;;;;           (floor (+ q 1/2)), so a half rounds up. The deviation is 100·(q -
;;;;           midi), in cents: an exact RATIONAL in [-50, 50).
;;;;           (spell-sequence (key-fit-midis fit) :key (key-fit-key fit)) spells
;;;;           the take.
;;;; Hint      the hint's candidate has the hint's tonic pitch class and mode
;;;;           (C# major → Db major); KEY-FIT-HINT is HINT as given.
;;;;             KEY-FIT-HINT-OFFSET  the candidate's own best offset (its
;;;;               highest-scoring d; equal scores as for Best).
;;;;             KEY-FIT-HINT-CORRELATION  its score there. At most
;;;;               KEY-FIT-CORRELATION; when the candidate is KEY-FIT-KEY, its
;;;;               offset and score are KEY-FIT-OFFSET and KEY-FIT-CORRELATION.
;;;;             KEY-FIT-HINT-DISTANCE  the semitones from the hint's tonic up to
;;;;               the tonic of the first ranking entry in the hint's mode, folded
;;;;               into -5 … 6 (a tritone is 6). It is -1 for a take sung a
;;;;               semitone below the hint, 1 for a semitone above, and 0 for a
;;;;               take in the hint's key. The hint's mode decides, because on a
;;;;               short melody DETECT-KEY often prefers the relative key: Jingle
;;;;               Bells, notated in F major, ranks A minor first and still reads
;;;;               0 against an F major hint. A key a fifth away can lead the
;;;;               hint's mode: Canon in D ranks A major above D major, -5.
;;;;           Without a HINT the four slots are NIL. Whether a take is "in the
;;;;           hint key" is the caller's policy, not this function's. A caller
;;;;           might accept distance 0, or a hint score within some margin of the
;;;;           best. A nonzero distance with the hint's score well below the
;;;;           best means a transposition of the hint fits clearly better.
;;;; No evidence  the events weigh nothing in total (no events, or zero weights
;;;;           only): REASON "zero total weight". Or H is 0, every fold constant
;;;;           (the 12 chromatic pitches at equal weights, at any tuning): REASON
;;;;           "constant histogram at every offset". FIT-KEY signals
;;;;           NO-KEY-EVIDENCE (TEXT NIL) with ERROR inside a USE-VALUE restart
;;;;           and returns the value it is given. (DETECT-KEY returns NIL for a
;;;;           constant histogram; FIT-KEY's caller asked for a fit.)
;;;;
;;;; Consequences (the tests check them):
;;;;   In tune   integer pitches and rational weights: KEY-FIT-OFFSET is 0 and
;;;;             KEY-FIT-RANKING is DETECT-KEY's ranking of the events'
;;;;             PITCH-CLASS-HISTOGRAM, the same keys and the same doubles. For
;;;;             0 < d < 100 the fold is (1 - d/100)·h + (d/100)·h′, h′ being h
;;;;             moved a semitone down. So c(K, d) mixes K's and the
;;;;             semitone-higher key's DETECT-KEY covariances, and no offset beats 0.
;;;;   Shifted   adding c/100 to every pitch of such a take, c an integer in
;;;;             -50 … 49, gives offset c and the same ranking, unless two keys a
;;;;             semitone apart tie for the best score in tune. Adding 1 + c/100
;;;;             also moves every key a semitone up.
;;;;   Octaves   adding 12 to every pitch changes only the MIDIs.
;;;;   Weights   scaling every weight by a positive rational changes nothing; a
;;;;             zero-weight event changes only the MIDIs and deviations.

(in-package #:music-theory)

(defstruct (key-fit (:constructor make-key-fit))
  "FIT-KEY's result (see the file header). Immutable, compared with EQUALP."
  (key nil :type (or null key) :read-only t)
  (offset nil :type (or null (integer -50 49)) :read-only t)
  (correlation nil :type (or null double-float) :read-only t)
  (ranking '() :type list :read-only t)
  (midis '() :type list :read-only t)
  (deviations '() :type list :read-only t)
  (hint nil :type (or null key) :read-only t)
  (hint-offset nil :type (or null (integer -50 49)) :read-only t)
  (hint-correlation nil :type (or null double-float) :read-only t)
  (hint-distance nil :type (or null (integer -5 6)) :read-only t))

(defparameter +key-fit-offsets+
  (sort (loop for d from -50 below 50 collect d)
        (lambda (a b) (or (< (abs a) (abs b))
                          (and (= (abs a) (abs b)) (< a b)))))
  "The 100 offsets FIT-KEY searches, in cents, in tie order: smaller |d| first, then
the negative one: 0 -1 1 -2 2 … -49 49 -50. Data.")

;;; Kernel: the take, the one search, the hint and the notes ------------------------

(defun %fit-events-p (object)
  "True for FIT-KEY's EVENTS: a proper list of REAL pitches and (pitch . weight)
conses, the pitch a REAL and the weight a non-negative REAL."
  (and (%proper-list-p object)
       (every (lambda (event)
                (if (consp event)
                    (and (realp (car event)) (typep (cdr event) '(real 0)))
                    (realp event)))
              object)))

(defun %fit-pairs (events)
  "Checked EVENTS as a fresh list of (q . w), pitch and weight taken as RATIONAL; a
bare pitch weighs 1."
  (mapcar (lambda (event)
            (if (consp event)
                (cons (rational (car event)) (rational (cdr event)))
                (cons (rational event) 1)))
          events))

(defun %improves-p (entry incumbent)
  "The search's one comparison: ENTRY, a (key c . v) of %KEY-SCORES, replaces
INCUMBENT (one such entry, or NIL for none yet) only when it ranks strictly before
it (%RANKS-BEFORE-P). Scanned in tie order, the first maximum is kept."
  (or (null incumbent) (%ranks-before-p entry incumbent)))

(defun %fit-search (pairs modes hint-key)
  "One pass over the folds of PAIRS ((q . w) rationals) at the offsets of
+KEY-FIT-OFFSETS+, in that order, and over %KEY-SCORES's candidates within each.
The fold at d is the PITCH-CLASS-HISTOGRAM of the pairs lowered by d/100. Returns
five values: H, the largest fold variance; the best offset; the fresh list of the
24 (key c . v) entries of that offset's fold; and the best offset and entry of
HINT-KEY (a key of +DETECT-KEY-KEYS+, or NIL for none). The best pair and the
hint's use the one comparison, %IMPROVES-P."
  (let ((h 0) (best nil) (offset nil) (entries nil) (hint-offset nil) (hint-entry nil))
    (dolist (d +key-fit-offsets+ (values h offset entries hint-offset hint-entry))
      (let ((shift (/ d 100)))
        (multiple-value-bind (cells variance)
            (%centered (pitch-class-histogram
                        (mapcar (lambda (pair) (cons (- (car pair) shift) (cdr pair)))
                                pairs)))
          (setf h (max h variance))
          (let ((scores (%key-scores cells modes)))
            (dolist (entry scores)
              (when (%improves-p entry best)
                (setf best entry offset d entries scores))
              (when (and (eq (car entry) hint-key) (%improves-p entry hint-entry))
                (setf hint-entry entry hint-offset d)))))))))

(defun %fit-notes (pairs offset)
  "Per pair of PAIRS, in order, with q its pitch lowered by OFFSET/100: the nearest
MIDI number (floor (+ q 1/2)), a half rounding up, and the deviation 100·(q - midi)
in cents, exact. Two lists, as two values."
  (loop with shift = (/ offset 100)
        for pair in pairs
        for q = (- (car pair) shift)
        for midi = (floor (+ q 1/2))
        collect midi into midis
        collect (* 100 (- q midi)) into deviations
        finally (return (values midis deviations))))

(defun %hint-candidate (hint)
  "The key of +DETECT-KEY-KEYS+ with HINT's tonic pitch class and mode (C# major →
Db major)."
  (find-if (lambda (key)
             (and (eq (key-mode key) (key-mode hint))
                  (= (pitch-class (key-tonic key)) (pitch-class (key-tonic hint)))))
           +detect-key-keys+))

(defun %hint-distance (hint ranking)
  "Semitones from HINT's tonic up to the tonic of the first RANKING entry in HINT's
mode, folded into -5 … 6 (a tritone is 6)."
  (let* ((lead (car (find (key-mode hint) ranking :key (lambda (entry) (key-mode (car entry))))))
         (s (mod (- (pitch-class (key-tonic lead)) (pitch-class (key-tonic hint))) 12)))
    (if (> s 6) (- s 12) s)))

(defun %no-key-evidence (reason)
  "Signal NO-KEY-EVIDENCE (TEXT NIL, REASON) with ERROR, inside a USE-VALUE restart.
Returns the value given to USE-VALUE, unchecked: FIT-KEY returns it."
  (restart-case (error 'no-key-evidence :reason reason)
    (use-value (value)
      :report (lambda (stream)
                (format stream "Supply a value for FIT-KEY to return instead of a fit (~A)."
                        reason))
      :interactive (lambda ()
                     (format *query-io* "~&Form to evaluate, its value returned by FIT-KEY: ")
                     (finish-output *query-io*)
                     (list (eval (read *query-io*))))
      value)))

;;; Function ---------------------------------------------------------------------------

(defun fit-key (events &key hint (profiles :krumhansl-kessler))
  "The candidate key and global tuning offset (cents, -50 … 49) that best fit
EVENTS, real MIDI pitch centres or (pitch . weight) conses, as a KEY-FIT; with
HINT, how the hint key fares (see the file header)."
  (check-type events (satisfies %fit-events-p)
              "a proper list of real pitches or (pitch . non-negative real weight) conses")
  (check-type hint (or null key))
  (check-type profiles (satisfies %key-profiles-p)
              "a +KEY-PROFILES+ name or a list (major minor) of two sequences of 12 reals")
  (let ((modes (%profile-modes profiles))
        (pairs (%fit-pairs events)))
    (when (zerop (reduce #'+ pairs :key #'cdr))
      (return-from fit-key (%no-key-evidence "zero total weight")))
    (multiple-value-bind (h offset entries hint-offset hint-entry)
        (%fit-search pairs modes (and hint (%hint-candidate hint)))
      (when (zerop h)
        (return-from fit-key (%no-key-evidence "constant histogram at every offset")))
      (flet ((score (entry)
               (destructuring-bind (c . v) (cdr entry)
                 (%correlation c v h))))
        (let ((ranking (mapcar (lambda (entry) (cons (car entry) (score entry)))
                               (stable-sort entries #'%ranks-before-p))))
          (multiple-value-bind (midis deviations) (%fit-notes pairs offset)
            (make-key-fit :key (car (first ranking))
                          :offset offset
                          :correlation (cdr (first ranking))
                          :ranking ranking
                          :midis midis
                          :deviations deviations
                          :hint hint
                          :hint-offset hint-offset
                          :hint-correlation (and hint (score hint-entry))
                          :hint-distance (and hint (%hint-distance hint ranking)))))))))
