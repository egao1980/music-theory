;;;; music-theory: the vocabulary of tonal music theory as values and arithmetic.
;;;; Brief: cl-stack/docs/capabilities/music-theory.md. No I/O, no rules.

(defpackage #:music-theory
  (:use #:cl)
  (:nicknames #:stack-music)
  (:documentation "Spelled pitches, intervals and the line of fifths (MT0).
Later slices add time and meter (MT1), keys and Roman numerals (MT2), chord
symbols (MT3), and spelling, key detection and transposition (MT4).")
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
   #:interval-between #:transpose-pitch))

(in-package #:music-theory)

(defun %mt0-pending (name)
  "Contract stub for slice MT0. Every call is replaced by the implementation,
then this function is deleted."
  (error "music-theory MT0 pending: ~A" name))
