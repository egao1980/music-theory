;;;; music-theory: the vocabulary of tonal music theory as values and arithmetic.
;;;; Brief: cl-stack/docs/capabilities/music-theory.md. No I/O, no rules.

(defpackage #:music-theory
  (:use #:cl)
  (:nicknames #:stack-music)
  (:documentation "Spelled pitches, intervals and the line of fifths (MT0); time, meter and tempo (MT1).
Later slices add keys and Roman numerals (MT2), chord symbols (MT3), and
spelling, key detection and transposition (MT4).")
  (:export
   ;; Conditions (all slices; see conditions.lisp)
   #:music-theory-error #:music-theory-warning
   #:music-theory-error-text #:music-theory-error-reason
   #:invalid-pitch #:invalid-interval #:invalid-meter #:invalid-key
   #:chord-symbol-parse-error
   #:chord-symbol-parse-error-position #:chord-symbol-parse-error-expected
   #:skip-chord-symbol
   #:unknown-chord-quality #:unknown-chord-quality-text
   #:ambiguous-spelling #:ambiguous-spelling-midi #:ambiguous-spelling-candidates
   ;; Spelled pitches (MT0)
   #:spelled-pitch #:make-spelled-pitch #:spelled-pitch-p
   #:spelled-pitch-letter #:spelled-pitch-alter #:spelled-pitch-octave
   #:pitch-class-name #:make-pitch-class-name #:pitch-class-name-p
   #:pitch-class-name-letter #:pitch-class-name-alter
   #:parse-pitch #:pitch-name #:parse-pitch-class #:pitch-class-string
   #:pitch-midi #:pitch-class #:pitch-diatonic-index #:pitch-spelling
   #:pitch-enharmonic-p
   ;; Line of fifths (MT0)
   #:pitch-fifths #:fifths-pitch-class
   ;; Intervals (MT0)
   #:interval #:make-interval #:interval-p #:interval-steps #:interval-semitones
   #:parse-interval #:interval-name #:interval-quality #:interval-number
   #:interval-direction #:interval-compound-p #:simple-interval
   #:reverse-interval #:invert-interval
   #:interval-between #:transpose-pitch
   ;; Meter (MT1)
   #:meter #:make-meter #:meter-p #:meter-numerators #:meter-denominator
   #:parse-meter #:meter-string #:meter-measure-duration #:compound-p
   #:meter-beats #:beat-unit #:metric-weight
   ;; Durations (MT1)
   #:duration-dots #:tuplet-duration #:split-duration
   ;; Tempo (MT1)
   #:tempo #:make-tempo #:tempo-p #:tempo-bpm #:tempo-beat-unit
   #:duration-seconds #:seconds-duration #:max-window-duration))

(in-package #:music-theory)
