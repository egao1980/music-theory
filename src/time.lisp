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

(defparameter +note-bases+ '(2 1 1/2 1/4 1/8 1/16 1/32 1/64 1/128)
  "Notated base values, breve to 128th. Data.")

;;; Dots and tuplets ----------------------------------------------------------

(defun %dot-factor (dots)
  "Value of a note with DOTS dots relative to its base: 2 - 1/2^DOTS
(1, 3/2, 7/4, 15/8, ...)."
  (- 2 (expt 1/2 dots)))

(defun duration-dots (duration &key (max-dots 3) tuplet)
  "BASE and DOTS with BASE * (2 - 1/2^DOTS) = DURATION * TUPLET (file header),
or NIL and NIL when no base with at most MAX-DOTS dots fits."
  (check-type duration (rational (0)))
  (check-type max-dots (integer 0))
  (check-type tuplet (or null (rational (0))))
  (let ((value (* duration (or tuplet 1))))
    ;; At most one DOTS fits: the odd part of VALUE's numerator is 2^(DOTS+1) - 1.
    (loop for dots from 0 to max-dots
          for base = (/ value (%dot-factor dots))
          when (member base +note-bases+)
            return (values base dots)
          finally (return (values nil nil)))))

(defun tuplet-duration (base ratio &key (dots 0))
  "Sounding duration of BASE with DOTS under RATIO n/m:
BASE * (2 - 1/2^DOTS) / RATIO, so (tuplet-duration 1/8 3/2) = 1/12."
  (check-type base (rational (0)))
  (check-type ratio (rational (0)))
  (check-type dots (integer 0))
  (/ (* base (%dot-factor dots)) ratio))

;;; Tie splitting -------------------------------------------------------------
;;; Rule numbers refer to the file header. After rule 1 every segment is in bar
;;; positions, 0 <= S < E <= bar, and the metric tree of meter.lisp answers both
;;; questions the rules ask: the weight of S and the lowest point inside.

(defun %bar-segments (offset duration bar)
  "Rule 1: cut [OFFSET, OFFSET + DURATION) at every multiple of BAR. Returns
(S . E) pairs in bar positions, 0 <= S < E <= BAR, in time order."
  (loop with end = (+ offset duration)
        for start = offset then cut
        for bar-start = (* bar (floor start bar))
        for cut = (min end (+ bar-start bar))
        collect (cons (- start bar-start) (- cut bar-start))
        until (= cut end)))

(defun %one-piece-p (tier unit max-dots s e p p-weight)
  "Rule 2 for the segment [S, E). P is its earliest lowest interior point and
P-WEIGHT that point's weight, or NIL when no interior point weighs 8 or less.
UNIT is the beat of a compound meter, else NIL."
  (let ((s-weight (%tier-weight tier s)))
    (and
     ;; a. Notatable with MAX-DOTS dots and no tuplet.
     (duration-dots (- e s) :max-dots max-dots)
     ;; b. Nothing inside is stronger than S. A weight-9 point never is.
     (or (null p) (>= p-weight s-weight))
     ;; c. Compound meters: a beat start inside (then the lowest point is one)
     ;;    needs S on a beat start and a whole number of beats.
     (or (null unit)
         (null p)
         (not (%beat-start-weight-p p-weight))
         (and (%beat-start-weight-p s-weight)
              (integerp (/ (- e s) unit)))))))

(defun %split-segment (tier unit max-dots s e)
  "Rules 2 and 3 for the segment [S, E): its tied pieces, in time order."
  (multiple-value-bind (p p-weight) (%lowest-interior tier s e)
    (cond ((%one-piece-p tier unit max-dots s e p p-weight)
           (list (- e s)))
          (p
           (nconc (%split-segment tier unit max-dots s p)
                  (%split-segment tier unit max-dots p e)))
          ;; Without an interior point only rule a can fail: a tuplet length.
          (t
           (error 'music-theory-error :reason "not notatable without a tuplet")))))

(defun split-duration (duration &key meter (offset 0) (max-dots 1))
  "The tied pieces of DURATION starting OFFSET after a barline (file header):
in time order, each notatable with MAX-DOTS dots and inside one bar, summing
exactly to DURATION. METER defaults to 4/4 when NIL."
  (check-type duration (rational (0)))
  (check-type meter (or null meter))
  (check-type offset rational)
  (check-type max-dots (integer 0))
  (let* ((meter (or meter (make-meter)))  ; the struct defaults are 4/4
         (tier (%bar-tier meter))
         (unit (and (compound-p meter) (beat-unit meter))))
    (loop for (s . e) in (%bar-segments offset duration (meter-measure-duration meter))
          nconc (%split-segment tier unit max-dots s e))))
