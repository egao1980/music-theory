;;;; MT1 meters and the metric hierarchy.
;;;;
;;;; Durations and positions are CL rationals in whole notes (1/4 = a quarter).
;;;; A METER is NUMERATORS (a list: (4) for 4/4, (2 3) for the additive 2+3/8)
;;;; over DENOMINATOR (a power of two, 1..64).
;;;;
;;;; PARSE-METER reads "4/4", "6/8", "2+3/8", "3+2+2/8", "C" (= 4/4) and "C|"
;;;; (= 2/2), surrounding whitespace trimmed. Numerators are integers 1..64.
;;;; Anything else signals INVALID-METER (TEXT = the input) inside a USE-VALUE
;;;; restart. METER-STRING prints "4/4" or "2+3/8" (never "C").
;;;;
;;;; Beats (METER-BEATS, a list of beat durations summing to the bar):
;;;;   compound  = a single numerator n > 3 with n mod 3 = 0 (6/8, 9/8, 12/8, 6/4):
;;;;               n/3 beats of 3/denominator.
;;;;   additive  = several numerators: one beat per numerator, numerator/denominator
;;;;               ((2 3)/8 → (1/4 3/8)).
;;;;   simple    = otherwise: n beats of 1/denominator (3/8 → three eighths, 5/4 → five quarters).
;;;; BEAT-UNIT is the common beat duration, or NIL when the beats differ.
;;;;
;;;; METRIC-WEIGHT meter offset → an integer level, 0 strongest. OFFSET is first
;;;; reduced modulo the bar length (so pickups and later bars work).
;;;;   0  the downbeat (offset 0).
;;;;   1  a beat-group start other than the downbeat. Groups: when all beats are
;;;;      equal and there are 4 or more of an even count, beats pair up
;;;;      (4/4: beat 3; 12/8: beat 3); in an additive meter every beat starts a group.
;;;;   2  any other beat start.
;;;;   3+j  inside a beat of duration D starting at b: the smallest j in 0..5 with
;;;;      (offset - b) a multiple of D / (s * 2^j), where s = 3 when D's numerator
;;;;      (in lowest terms) is 3 (a dotted beat), else 2.
;;;;   9  off every grid above (e.g. a triplet position in 4/4).

(in-package #:music-theory)

(defstruct (meter (:constructor make-meter))
  (numerators '(4) :type list :read-only t)
  (denominator 4 :type (integer 1 64) :read-only t))

(defparameter +meter-denominators+ '(1 2 4 8 16 32 64)
  "Allowed denominators. Data.")

(defun parse-meter (string)
  (declare (ignorable string))
  (%mt1-pending 'parse-meter))

(defun meter-string (meter)
  (declare (ignorable meter))
  (%mt1-pending 'meter-string))

(defun meter-measure-duration (meter)
  "Bar length in whole notes: (sum of numerators) / denominator."
  (declare (ignorable meter))
  (%mt1-pending 'meter-measure-duration))

(defun compound-p (meter)
  (declare (ignorable meter))
  (%mt1-pending 'compound-p))

(defun meter-beats (meter)
  (declare (ignorable meter))
  (%mt1-pending 'meter-beats))

(defun beat-unit (meter)
  (declare (ignorable meter))
  (%mt1-pending 'beat-unit))

(defun metric-weight (meter offset)
  (declare (ignorable meter offset))
  (%mt1-pending 'metric-weight))
