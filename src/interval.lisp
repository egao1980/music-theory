;;;; MT0 intervals.
;;;;
;;;; An INTERVAL is STEPS (signed diatonic steps: 0 unison, 1 second, ...,
;;;; 7 octave, 11 twelfth; compound intervals are kept, so P12 ≠ P5) plus
;;;; SEMITONES (signed). The quality is derived, never stored.
;;;;
;;;; Direction is the sign of STEPS. A unison (STEPS 0) is non-directional and
;;;; read as ascending, so C4→Cb4 (0 steps, -1 semitone) is a diminished unison
;;;; "d1" and C4→C#4 is "A1" (this matches music21).
;;;;
;;;; Quality: normalise to ascending (negate both fields when STEPS < 0),
;;;; reduce by whole octaves (7 steps, 12 semitones) to a simple number
;;;; 0..6, and compare the semitones with +SIMPLE-INTERVALS+:
;;;;   perfect type (unison, 4th, 5th): deviation -2 dd, -1 d, 0 P, +1 A, +2 AA
;;;;   major type (2nd, 3rd, 6th, 7th): -3 dd, -2 d, -1 m, 0 M, +1 A, +2 AA
;;;; Anything further out has no name here: INTERVAL-QUALITY and INTERVAL-NAME
;;;; signal INVALID-INTERVAL (TEXT NIL). Such intervals still transpose.
;;;;
;;;; Names: [ "-" ] quality number, quality ∈ dd d m M P A AA, number = |STEPS|+1.
;;;; "-" marks a descending interval ("-M2", "-P5"); unisons never carry it.
;;;; PARSE-INTERVAL accepts exactly what INTERVAL-NAME prints and signals
;;;; INVALID-INTERVAL (TEXT = the input, inside USE-VALUE) for anything else:
;;;; "M4", "P3", "m0", "-P1", "AAA4", "".
;;;;
;;;; SIMPLE-INTERVAL removes whole octaves while |STEPS| > 7 (direction kept):
;;;; P12 → P5, P15 → P8, P8 → P8, -M9 → -M2.
;;;; REVERSE-INTERVAL negates both fields (M3 → -M3, A1 → d1).
;;;; INVERT-INTERVAL complements the simple interval within the octave, keeping
;;;; the direction: M3 → m6, A4 → d5, P1 → P8, P8 → P1, M10 → m6, -M3 → -m6.
;;;;
;;;; INTERVAL-BETWEEN p q: STEPS = diatonic index difference, SEMITONES = MIDI
;;;; difference. TRANSPOSE-PITCH p i: the letter and octave move by STEPS, and
;;;; the alter makes up the semitones. It signals INVALID-PITCH when that needs
;;;; more than two accidentals (B##4 up A1). Spelling is exact:
;;;; (transpose-pitch p (interval-between p q)) is EQUALP to q.

(in-package #:music-theory)

(defstruct (interval (:constructor make-interval))
  (steps 0 :type integer :read-only t)
  (semitones 0 :type integer :read-only t))

(defparameter +simple-intervals+
  #((0 :perfect) (2 :major) (4 :major) (5 :perfect) (7 :perfect) (9 :major) (11 :major))
  "For simple steps 0..6: (semitones of the perfect or major form, type). Data.")

(defparameter +quality-names+
  '((:doubly-diminished . "dd") (:diminished . "d") (:minor . "m") (:perfect . "P")
    (:major . "M") (:augmented . "A") (:doubly-augmented . "AA"))
  "Quality keyword → its text in interval names. Data, read in both directions.")

(defparameter +quality-deviations+
  '((:perfect (-2 . :doubly-diminished) (-1 . :diminished) (0 . :perfect)
              (1 . :augmented) (2 . :doubly-augmented))
    (:major (-3 . :doubly-diminished) (-2 . :diminished) (-1 . :minor) (0 . :major)
            (1 . :augmented) (2 . :doubly-augmented)))
  "Per interval type, (deviation from the +SIMPLE-INTERVALS+ size . quality).
INTERVAL-QUALITY reads it by deviation, PARSE-INTERVAL by quality. Data.")

;;; Kernel --------------------------------------------------------------------

(defun %interval-base (steps)
  "For STEPS >= 0: the semitones of the perfect or major interval of that size
(whole octaves included), and its type, :PERFECT or :MAJOR."
  (multiple-value-bind (octaves simple) (floor steps 7)
    (destructuring-bind (semitones type) (aref +simple-intervals+ simple)
      (values (+ semitones (* 12 octaves)) type))))

(defun interval-quality (interval)
  "One of :DOUBLY-DIMINISHED :DIMINISHED :MINOR :PERFECT :MAJOR :AUGMENTED
:DOUBLY-AUGMENTED."
  (let ((steps (interval-steps interval))
        (semitones (interval-semitones interval)))
    ;; A unison is read as ascending, so only STEPS < 0 is normalised.
    (when (minusp steps)
      (setf steps (- steps)
            semitones (- semitones)))
    (multiple-value-bind (base type) (%interval-base steps)
      (or (cdr (assoc (- semitones base) (cdr (assoc type +quality-deviations+))))
          (error 'invalid-interval
                 :reason "quality beyond doubly augmented or doubly diminished")))))

(defun interval-number (interval)
  "|STEPS| + 1: 1 for a unison, 3 for a third, 12 for a twelfth."
  (1+ (abs (interval-steps interval))))

(defun interval-direction (interval)
  "-1, 0 or 1: the sign of STEPS."
  (signum (interval-steps interval)))

(defun interval-compound-p (interval)
  "True when |STEPS| > 7 (wider than an octave)."
  (> (abs (interval-steps interval)) 7))

(defun simple-interval (interval)
  "INTERVAL with whole octaves (7 steps, 12 semitones) removed while |STEPS| > 7,
keeping the direction: P12 → P5, P15 → P8, P8 → P8, -M9 → -M2."
  (let* ((steps (interval-steps interval))
         (sign (if (minusp steps) -1 1))
         (octaves (if (> (abs steps) 7) (floor (1- (abs steps)) 7) 0)))
    (make-interval :steps (- steps (* sign 7 octaves))
                   :semitones (- (interval-semitones interval) (* sign 12 octaves)))))

(defun reverse-interval (interval)
  "INTERVAL in the opposite direction, both fields negated: M3 → -M3, A1 → d1."
  (make-interval :steps (- (interval-steps interval))
                 :semitones (- (interval-semitones interval))))

(defun invert-interval (interval)
  "The complement of (SIMPLE-INTERVAL INTERVAL) within the octave, keeping the
direction: M3 → m6, A4 → d5, P1 → P8, P8 → P1, M10 → m6, -M3 → -m6, A1 → d8."
  (let ((simple (simple-interval interval))
        (sign (if (minusp (interval-steps interval)) -1 1)))
    (make-interval :steps (- (* sign 7) (interval-steps simple))
                   :semitones (- (* sign 12) (interval-semitones simple)))))

;;; Text ----------------------------------------------------------------------

(defun interval-name (interval)
  "Name of INTERVAL (see the file header)."
  (format nil "~:[~;-~]~A~D"
          (minusp (interval-steps interval))
          (cdr (assoc (interval-quality interval) +quality-names+))
          (interval-number interval)))

(defun parse-interval (string)
  "Parse an interval name such as \"m3\", \"-P5\" or \"P12\"."
  (check-type string string)
  (flet ((fail (reason)
           (return-from parse-interval
             (%parse-failure 'invalid-interval string reason #'parse-interval))))
    (let* ((end (length string))
           (descending (and (plusp end) (char= #\- (char string 0))))
           (start (if descending 1 0))
           (split (or (position-if #'%ascii-digit-p string :start start) end))
           (quality (car (rassoc (subseq string start split) +quality-names+
                                 :test #'string=))))
      (unless quality (fail "unknown quality"))
      ;; Interval numbers are ASCII decimals >= 1 without leading zeros.
      (unless (and (< split end)
                   (char/= #\0 (char string split))
                   (every #'%ascii-digit-p (subseq string split)))
        (fail "missing interval number"))
      (let ((steps (1- (parse-integer string :start split))))
        (when (and descending (zerop steps))
          (fail "a unison has no direction"))
        (multiple-value-bind (base type) (%interval-base steps)
          (let ((deviation (car (rassoc quality (cdr (assoc type +quality-deviations+))))))
            (unless deviation (fail "quality does not fit the interval number"))
            (let ((semitones (+ base deviation)))
              (if descending
                  (make-interval :steps (- steps) :semitones (- semitones))
                  (make-interval :steps steps :semitones semitones)))))))))

;;; Pitch arithmetic ----------------------------------------------------------

(defun interval-between (p q)
  "The interval from SPELLED-PITCH P to SPELLED-PITCH Q."
  (make-interval :steps (- (pitch-diatonic-index q) (pitch-diatonic-index p))
                 :semitones (- (pitch-midi q) (pitch-midi p))))

(defun transpose-pitch (pitch interval)
  "PITCH moved by INTERVAL, spelling preserved (F#4 up M2 → G#4)."
  (let ((index (+ (pitch-diatonic-index pitch) (interval-steps interval)))
        (midi (+ (pitch-midi pitch) (interval-semitones interval))))
    (multiple-value-bind (octave letter) (floor index 7)
      (let ((alter (- midi (* 12 (1+ octave)) (aref +letter-semitones+ letter))))
        ;; Checked before the constructor, whose slot type would signal TYPE-ERROR.
        (unless (<= -2 alter 2)
          (error 'invalid-pitch :reason "needs more than two accidentals"))
        (make-spelled-pitch :letter letter :alter alter :octave octave)))))
