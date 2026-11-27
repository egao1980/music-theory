;;;; MT4 key detection: pitch-class histograms and correlation with key profiles.
;;;;
;;;; PITCH-CLASS-HISTOGRAM events &key (weight :duration) → a fresh SIMPLE-VECTOR
;;;; of 12 non-negative reals; cell p is the weight of pitch class p (C 0 … B 11).
;;;;   EVENTS  a list. Each event is (pitch . duration), or a bare pitch, which
;;;;           counts as (pitch . 1). A pitch is an INTEGER (a MIDI number; its
;;;;           class is (mod pitch 12), so 61 and -11 are both 1), a
;;;;           SPELLED-PITCH or a PITCH-CLASS-NAME (PITCH-CLASS: Cb is 11), or
;;;;           (0.6.0) any other REAL, a MIDI number with cents in its fraction
;;;;           (61.37 is C#4 and 37 cents). A duration is a non-negative REAL,
;;;;           in whole notes or in any unit: only ratios matter to DETECT-KEY.
;;;;   WEIGHT  :DURATION (default): each event adds its duration to its cell.
;;;;           :COUNT: each event adds 1, whatever its duration.
;;;;   Real pitches  a REAL pitch is taken as RATIONAL, q = (rational pitch),
;;;;           and its amount (duration or 1) is split between the two pitch
;;;;           classes around it in proportion to its nearness to each: with
;;;;           n = (floor q) and f = q - n, cell (mod n 12) gets amount·(1 - f)
;;;;           and, when f > 0, cell (mod (1+ n) 12) gets amount·f. An integer
;;;;           (f = 0) adds all of it to its class, as before. 60.5 gives half
;;;;           to C and half to C#, 6137/100 gives 63/100 to C# and 37/100 to D,
;;;;           71.75 a quarter to B and three quarters to C, -1/2 half to B and
;;;;           half to C; 60.0d0 is C. MT5's FIT-KEY folds pitch centres this
;;;;           way (src/key-fit.lisp).
;;;; Sums are exact: rational durations give rational cells (a float pitch is
;;;; exact too, as its RATIONAL), and no event gives twelve zeros (integer 0).
;;;; Anything else (an improper list, a pitch of another type, a negative or
;;;; non-real duration, another WEIGHT) is a TYPE-ERROR.
;;;;
;;;; DETECT-KEY histogram &key (profiles :krumhansl-kessler) → a list of 24
;;;; conses (key . correlation), best first, one per candidate key.
;;;;   HISTOGRAM  a sequence (list or vector) of 12 non-negative reals, index =
;;;;              pitch class, as PITCH-CLASS-HISTOGRAM returns; else TYPE-ERROR.
;;;;   PROFILES   :KRUMHANSL-KESSLER, :TEMPERLEY or :AARDEN, a row of
;;;;              +KEY-PROFILES+; or a list (major minor) of two sequences of 12
;;;;              reals, tonic first, for a profile of the caller's.
;;;;              Anything else is a TYPE-ERROR; a profile whose 12 weights are
;;;;              all equal signals MUSIC-THEORY-ERROR (TEXT NIL, REASON
;;;;              "constant key profile").
;;;;   Candidates  the 24 keys of +DETECT-KEY-CANDIDATES+, one per tonic pitch
;;;;              class and mode, each spelled with the fewest accidentals: Db
;;;;              major (not C#), C# minor (not Db), and at six, F# major (as
;;;;              music21) and Eb minor (its leading tone is D, not C𝄪). Their
;;;;              order, C major, C minor, Db major, C# minor, …, B minor, is the
;;;;              tie order.
;;;;   Correlation  for the key with tonic pitch class T and mode M, the Pearson
;;;;              correlation between the 12 cells h(i) and the mode's profile
;;;;              rotated to the tonic, p(i) = profile[(i - T) mod 12]:
;;;;                r = Σ (p(i) - p̄)(h(i) - h̄) / sqrt(Σ (p(i) - p̄)² · Σ (h(i) - h̄)²)
;;;;              with p̄ and h̄ the means of the 12 values. Every quantity but the
;;;;              square root is exact (cells and weights taken as RATIONAL), and
;;;;              CORRELATION is r rounded to a DOUBLE-FLOAT, -1 ≤ r ≤ 1.
;;;;   Ranking    by r, descending, decided exactly: r1 > r2 when
;;;;              sign(c1)·c1²·v2 > sign(c2)·c2²·v1, c being a key's covariance
;;;;              (the numerator) and v its profile's Σ (p(i) - p̄)²; the
;;;;              histogram's variance is common to all keys. Equal r keep the
;;;;              candidate order (stable). The rounding never reorders keys.
;;;;   No evidence  a histogram whose 12 cells are equal (all zero included) has
;;;;              no correlation with anything: DETECT-KEY returns NIL.
;;;; music21's KrumhanslKessler, TemperleyKostkaPayne and AardenEssen analyses
;;;; compute the same r from a stream's duration-weighted distribution (the
;;;; MT4 fixtures), except that they report 0.0 for a constant histogram.
;;;; Correlation is unchanged by scaling a profile, so +KEY-PROFILES+ stores the
;;;; published decimals as integers times a power of ten.

(in-package #:music-theory)

(defparameter +key-profiles+
  '((:krumhansl-kessler 100
     (635 223 348 233 438 409 252 519 239 366 229 288)
     (633 268 352 538 260 353 254 475 398 269 334 317))
    (:temperley 1000
     (748 60 488 82 670 460 96 715 104 366 57 400)
     (712 84 474 618 49 460 105 747 404 67 133 330))
    (:aarden 1000000
     (17766100 145624 14926500 160186 19804900 11358700 291248 22062000 145624 8154940 232998 4951220)
     (18264800 737619 14049900 16859900 702494 14436200 702494 18616100 4566210 1931860 7376190 1756230)))
  "Key profiles: (name scale major minor). MAJOR and MINOR are 12 weights, tonic
first (C, C#, D, … above the tonic); each published weight is the integer divided
by SCALE (Krumhansl-Kessler 6.35 = 635/100). Published numbers, cited in
tests/fixtures/PROVENANCE.md:
  :krumhansl-kessler  Krumhansl & Kessler (1982), probe-tone ratings.
  :temperley          Temperley (2007), Music and Probability: the Kostka-Payne
                      corpus profiles (music21's TemperleyKostkaPayne).
  :aarden             Aarden (2003), the Essen folksong corpus profiles
                      (music21's AardenEssen).
Data.")

(defparameter +detect-key-candidates+
  '("C major" "C minor" "Db major" "C# minor" "D major" "D minor"
    "Eb major" "Eb minor" "E major" "E minor" "F major" "F minor"
    "F# major" "F# minor" "G major" "G minor" "Ab major" "G# minor"
    "A major" "A minor" "Bb major" "Bb minor" "B major" "B minor")
  "The 24 keys DETECT-KEY ranks, as KEY-NAME text, in tie order: by tonic pitch
class, major before minor. Data.")

(defparameter +detect-key-keys+
  (mapcar #'parse-key +detect-key-candidates+)
  "The KEYs of +DETECT-KEY-CANDIDATES+, in its order. Derived at load time; shared by
every ranking, so never mutated (KEYs are read-only).")

;;; Kernel: validation and exact statistics --------------------------------------

(defun %proper-list-p (object)
  "True for a proper list."
  (do ((tail object (rest tail)))
      ((atom tail) (null tail))))

(defun %cells-p (object type)
  "True for a list or vector of exactly 12 elements of TYPE."
  (and (or (vectorp object) (%proper-list-p object))
       (= 12 (length object))
       (every (lambda (x) (typep x type)) object)))

(defun %histogram-p (object)
  "True for a DETECT-KEY histogram: a list or vector of 12 non-negative reals."
  (%cells-p object '(real 0)))

(defun %key-profiles-p (object)
  "True for a DETECT-KEY PROFILES argument: the name of a +KEY-PROFILES+ row, or a
list (major minor) of two sequences of 12 reals."
  (if (symbolp object)
      (and object (assoc object +key-profiles+) t)
      (and (%proper-list-p object)
           (= 2 (length object))
           (every (lambda (weights) (%cells-p weights 'real)) object))))

(defun %centered (cells)
  "CELLS, 12 reals taken as RATIONAL, minus their mean: a fresh SIMPLE-VECTOR, and the
sum of its squares, as two values. Exact."
  (let* ((centered (map 'simple-vector #'rational cells))
         (mean (/ (reduce #'+ centered) 12)))
    (map-into centered (lambda (x) (- x mean)) centered)
    (values centered (reduce #'+ centered :key (lambda (x) (* x x))))))

(defun %ranks-before-p (a b)
  "The header's exact ranking of two scored candidates, (key c . v) each: A's r is
larger than B's when sign(c1)·c1²·v2 > sign(c2)·c2²·v1."
  (destructuring-bind (c1 . v1) (cdr a)
    (destructuring-bind (c2 . v2) (cdr b)
      (> (* (signum c1) c1 c1 v2) (* (signum c2) c2 c2 v1)))))

(defun %correlation (c v histogram-variance)
  "r = c / sqrt(v · HISTOGRAM-VARIANCE) as a DOUBLE-FLOAT: the exact c²/(v·v_h)
rounded once, then the IEEE square root, both monotone, so the rounding never
reorders keys and |r| ≤ 1."
  (let ((s (sqrt (float (/ (* c c) (* v histogram-variance)) 1d0))))
    (if (minusp c) (- s) s)))

(defun %profile-modes (profiles)
  "Per mode, major then minor, (centered-weights . variance) of PROFILES, a DETECT-KEY
PROFILES argument that %KEY-PROFILES-P accepts. Signals MUSIC-THEORY-ERROR (REASON
\"constant key profile\") when a profile's 12 weights are all equal. Shared by
DETECT-KEY and FIT-KEY."
  (let ((modes (mapcar (lambda (weights)
                         (multiple-value-bind (centered variance) (%centered weights)
                           (cons centered variance)))
                       (if (symbolp profiles)
                           (cddr (assoc profiles +key-profiles+))
                           profiles))))
    (when (some (lambda (mode) (zerop (cdr mode))) modes)
      (error 'music-theory-error :reason "constant key profile"))
    modes))

(defun %key-scores (cells modes)
  "The 24 candidates of +DETECT-KEY-KEYS+ scored against CELLS, a centered histogram
as %CENTERED returns it: a fresh list of (key c . v), in candidate order. C is the
covariance of CELLS with the key's mode profile rotated to its tonic (the header's
numerator) and V that profile's variance; MODES as %PROFILE-MODES returns. Exact.
Shared by DETECT-KEY and FIT-KEY; %RANKS-BEFORE-P orders the entries."
  (loop for key in +detect-key-keys+
        for tonic = (pitch-class (key-tonic key))
        for (weights . variance) = (if (eq (key-mode key) :major)
                                       (first modes)
                                       (second modes))
        collect (list* key
                       (loop for i below 12
                             sum (* (svref weights (mod (- i tonic) 12))
                                    (svref cells i)))
                       variance)))

;;; Functions --------------------------------------------------------------------

(defun pitch-class-histogram (events &key (weight :duration))
  "The 12-cell pitch-class histogram of EVENTS, (pitch . duration) conses or bare
pitches, weighted by :DURATION or :COUNT (see the file header)."
  (check-type events (satisfies %proper-list-p) "a proper list of events")
  (check-type weight (member :duration :count))
  (let ((cells (make-array 12 :initial-element 0)))
    (dolist (event events cells)
      (multiple-value-bind (pitch duration)
          (if (consp event) (values (car event) (cdr event)) (values event 1))
        (check-type duration (real 0) "a non-negative real duration")
        (let ((amount (if (eq weight :count) 1 duration)))
          (etypecase pitch
            (integer (incf (svref cells (mod pitch 12)) amount))
            ((or spelled-pitch pitch-class-name) (incf (svref cells (pitch-class pitch)) amount))
            (real (multiple-value-bind (n f) (floor (rational pitch))
                    (incf (svref cells (mod n 12)) (* amount (- 1 f)))
                    (when (plusp f)
                      (incf (svref cells (mod (1+ n) 12)) (* amount f)))))))))))

(defun detect-key (histogram &key (profiles :krumhansl-kessler))
  "The 24 candidate keys ranked by correlation with PROFILES, best first, as
(key . correlation) conses; NIL for a constant HISTOGRAM (see the file header)."
  (check-type histogram (satisfies %histogram-p) "a list or vector of 12 non-negative reals")
  (check-type profiles (satisfies %key-profiles-p)
              "a +KEY-PROFILES+ name or a list (major minor) of two sequences of 12 reals")
  (let ((modes (%profile-modes profiles)))
    (multiple-value-bind (cells histogram-variance) (%centered histogram)
      (unless (zerop histogram-variance)
        (mapcar (lambda (entry)
                  (destructuring-bind (key c . v) entry
                    (cons key (%correlation c v histogram-variance))))
                (stable-sort (%key-scores cells modes) #'%ranks-before-p))))))
