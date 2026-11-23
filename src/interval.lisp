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

(defun parse-interval (string)
  "Parse an interval name such as \"m3\", \"-P5\" or \"P12\"."
  (declare (ignorable string))
  (%mt0-pending 'parse-interval))

(defun interval-name (interval)
  "Name of INTERVAL (see the file header)."
  (declare (ignorable interval))
  (%mt0-pending 'interval-name))

(defun interval-quality (interval)
  "One of :DOUBLY-DIMINISHED :DIMINISHED :MINOR :PERFECT :MAJOR :AUGMENTED
:DOUBLY-AUGMENTED."
  (declare (ignorable interval))
  (%mt0-pending 'interval-quality))

(defun interval-number (interval)
  "|STEPS| + 1: 1 for a unison, 3 for a third, 12 for a twelfth."
  (declare (ignorable interval))
  (%mt0-pending 'interval-number))

(defun interval-direction (interval)
  "-1, 0 or 1: the sign of STEPS."
  (declare (ignorable interval))
  (%mt0-pending 'interval-direction))

(defun interval-compound-p (interval)
  "True when |STEPS| > 7 (wider than an octave)."
  (declare (ignorable interval))
  (%mt0-pending 'interval-compound-p))

(defun simple-interval (interval)
  (declare (ignorable interval))
  (%mt0-pending 'simple-interval))

(defun reverse-interval (interval)
  (declare (ignorable interval))
  (%mt0-pending 'reverse-interval))

(defun invert-interval (interval)
  (declare (ignorable interval))
  (%mt0-pending 'invert-interval))

(defun interval-between (p q)
  "The interval from SPELLED-PITCH P to SPELLED-PITCH Q."
  (declare (ignorable p q))
  (%mt0-pending 'interval-between))

(defun transpose-pitch (pitch interval)
  "PITCH moved by INTERVAL, spelling preserved (F#4 up M2 → G#4)."
  (declare (ignorable pitch interval))
  (%mt0-pending 'transpose-pitch))
