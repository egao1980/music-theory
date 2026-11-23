;;;; MT1 tempo arithmetic.
;;;;
;;;; A TEMPO is BPM beats per minute of BEAT-UNIT (a duration: 1/4 for ♩ = BPM,
;;;; 3/8 for a dotted quarter in 6/8). Tempo maps belong to score-protocol.
;;;;
;;;; DURATION-SECONDS d tempo = d / beat-unit * 60 / bpm.
;;;; SECONDS-DURATION s tempo = s * bpm / 60 * beat-unit, where a float S is first
;;;; converted with RATIONALIZE. With a rational BPM both are exact, so
;;;; (seconds-duration (duration-seconds d tm) tm) = d.
;;;;
;;;; MAX-WINDOW-DURATION tempo seconds &key grid: the longest duration that
;;;; lasts at most SECONDS, i.e. SECONDS-DURATION, rounded down to a multiple of
;;;; GRID when GRID is given. Always a rational. This is phrase-window arithmetic
;;;; for "a rest at least every N seconds".

(in-package #:music-theory)

(defstruct (tempo (:constructor make-tempo))
  (bpm 120 :type (real (0)) :read-only t)
  (beat-unit 1/4 :type rational :read-only t))

(defun duration-seconds (duration tempo)
  (declare (ignorable duration tempo))
  (%mt1-pending 'duration-seconds))

(defun seconds-duration (seconds tempo)
  (declare (ignorable seconds tempo))
  (%mt1-pending 'seconds-duration))

(defun max-window-duration (tempo seconds &key grid)
  (declare (ignorable tempo seconds grid))
  (%mt1-pending 'max-window-duration))
