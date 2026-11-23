;;;; MT1 durations: dots, tuplets and tie splitting.
;;;;
;;;; DURATION-DOTS duration &key (max-dots 3) tuplet → (values base dots), or
;;;; (values NIL NIL) when DURATION isn't one notated value. BASE is a power of
;;;; two from 2 (breve) down to 1/128, and the notated value is
;;;; base * (2 - 1/2^dots) with 0 <= dots <= MAX-DOTS. TUPLET is a ratio n/m,
;;;; "n in the time of m" (3/2 triplets, 5/4 quintuplets): the notated value is
;;;; then duration * n/m.
;;;;
;;;; TUPLET-DURATION base ratio &key (dots 0) is the inverse: the sounding
;;;; duration of BASE (with DOTS) under RATIO, so (tuplet-duration 1/8 3/2) = 1/12.
;;;;
;;;; SPLIT-DURATION duration &key (meter 4/4) (offset 0) (max-dots 1) → the
;;;; tied pieces (a list of durations, in order, summing exactly to DURATION) for
;;;; a note starting OFFSET after a barline:
;;;;  1. Cut at every barline (multiples of the bar length).
;;;;  2. A segment [s, e) inside a bar is one piece when all of these hold:
;;;;     a. it is notatable (DURATION-DOTS with MAX-DOTS, no tuplet);
;;;;     b. no point p with s < p < e has a lower METRIC-WEIGHT than s;
;;;;     c. in a compound meter, if it contains a beat start p (s < p < e), then s
;;;;        is a beat start and e - s is a whole number of beats.
;;;;  3. Otherwise split it at the interior point with the lowest metric weight
;;;;     (the earliest one on ties; only points of weight <= 8 count) and apply
;;;;     rule 2 to both parts.
;;;; In 4/4: 1/2 at 1/4 → (1/4 1/4); 1/2 at 1/8 → (1/8 1/4 1/8); 5/8 at 0 →
;;;; (1/2 1/8); 3/4 at 0 → (3/4). In 6/8: 1/2 at 0 → (3/8 1/8).
;;;; DURATION must be a positive rational (else TYPE-ERROR). A piece that can't
;;;; be split further but is still not notatable (a tuplet length) signals
;;;; MUSIC-THEORY-ERROR with a REASON.

(in-package #:music-theory)

(defun duration-dots (duration &key (max-dots 3) tuplet)
  (declare (ignorable duration max-dots tuplet))
  (%mt1-pending 'duration-dots))

(defun tuplet-duration (base ratio &key (dots 0))
  (declare (ignorable base ratio dots))
  (%mt1-pending 'tuplet-duration))

(defun split-duration (duration &key meter (offset 0) (max-dots 1))
  "METER defaults to 4/4 when NIL."
  (declare (ignorable duration meter offset max-dots))
  (%mt1-pending 'split-duration))
