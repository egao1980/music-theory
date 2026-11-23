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

;;; Kernel --------------------------------------------------------------------

(defun %whole-notes-per-second (tempo)
  "The exact rate of TEMPO in whole notes per second: BPM / 60 beats of
BEAT-UNIT. A float BPM goes through RATIONALIZE, so the conversions below
return rationals for every tempo."
  (* (rationalize (tempo-bpm tempo)) 1/60 (tempo-beat-unit tempo)))

(defun duration-seconds (duration tempo)
  "Seconds DURATION lasts at TEMPO: DURATION / BEAT-UNIT * 60 / BPM, exactly."
  (check-type duration rational)
  (/ duration (%whole-notes-per-second tempo)))

(defun seconds-duration (seconds tempo)
  "The duration that lasts SECONDS at TEMPO: SECONDS * BPM / 60 * BEAT-UNIT.
A float SECONDS is first converted with RATIONALIZE."
  (check-type seconds real)
  (* (rationalize seconds) (%whole-notes-per-second tempo)))

(defun max-window-duration (tempo seconds &key grid)
  "The longest duration that lasts at most SECONDS at TEMPO, rounded down to a
multiple of GRID when GRID is given. Always a rational."
  (check-type grid (or null (rational (0))))
  (let ((duration (seconds-duration seconds tempo)))
    (if grid
        (* grid (floor duration grid))
        duration)))
