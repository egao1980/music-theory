;;;; music-theory: the vocabulary of tonal music theory as values and arithmetic.
;;;; Brief: cl-stack/docs/capabilities/music-theory.md. No I/O, no rules.

(defpackage #:music-theory
  (:use #:cl)
  (:nicknames #:stack-music)
  (:documentation "Spelled pitches, intervals and the line of fifths (MT0); time, meter and
tempo (MT1); keys, scale degrees and Roman numerals (MT2); chord symbols: the
grammar, dialects, realisation and essential tones (MT3); spelling, key
detection and transposition to a key (MT4); MusicXML <kind> values for chord
symbols (0.5.1); key fit with a tuning offset for pitch centres in cents (MT5).")
  (:export
   ;; Conditions (all slices; see conditions.lisp)
   #:music-theory-error #:music-theory-warning
   #:music-theory-error-text #:music-theory-error-reason
   #:invalid-pitch #:invalid-interval #:invalid-meter #:invalid-key
   #:invalid-roman-numeral #:chord-symbol-parse-error
   #:chord-symbol-parse-error-position #:chord-symbol-parse-error-expected
   #:skip-chord-symbol
   #:unknown-chord-quality #:unknown-chord-quality-text
   #:ambiguous-spelling #:ambiguous-spelling-midi #:ambiguous-spelling-candidates
   #:no-key-evidence
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
   #:duration-seconds #:seconds-duration #:max-window-duration
   ;; Keys, scales and degrees (MT2)
   #:key #:make-key #:key-p #:key-tonic #:key-mode
   #:parse-key #:key-name #:key-signature
   #:scale-degrees #:degree-of #:pitch-of-degree
   ;; Chord symbols: the value (MT2)
   #:chord-symbol #:make-chord-symbol #:chord-symbol-p
   #:chord-symbol-root #:chord-symbol-quality #:chord-symbol-extensions
   #:chord-symbol-alterations #:chord-symbol-suspension #:chord-symbol-added
   #:chord-symbol-omitted #:chord-symbol-bass #:chord-symbol-no-chord-p
   #:chord-symbol-text #:chord-symbol-dialect
   ;; Chord symbols: grammar, dialects, realisation, priorities (MT3)
   #:parse-chord-symbol #:print-chord-symbol
   #:chord-tones #:chord-essential-tones #:transpose-chord-symbol
   ;; Chord symbols: MusicXML <kind> (0.5.1, music-theory#16)
   #:musicxml-kind-chord-symbol #:chord-symbol-musicxml-kind
   ;; Spelling, key detection, transposition (MT4)
   #:spell-midi #:spell-sequence
   #:pitch-class-histogram #:detect-key
   #:transpose-to-key #:choose-enharmonic-key
   ;; Key fit with a tuning offset (MT5)
   #:fit-key
   #:key-fit #:make-key-fit #:key-fit-p
   #:key-fit-key #:key-fit-offset #:key-fit-correlation #:key-fit-ranking
   #:key-fit-midis #:key-fit-deviations
   #:key-fit-hint #:key-fit-hint-offset #:key-fit-hint-correlation
   #:key-fit-hint-distance
   ;; Roman numerals (MT2)
   #:roman-numeral #:make-roman-numeral #:roman-numeral-p
   #:roman-numeral-degree #:roman-numeral-alteration #:roman-numeral-quality
   #:roman-numeral-inversion #:roman-numeral-applied-to
   #:parse-roman #:roman-name #:chord-for #:roman-for #:roman-mixture-p))

(in-package #:music-theory)

(defun %mt5-pending (name)
  "Contract stub for slice MT5 (key fit with a tuning offset). Every call is
replaced by the implementation, then this function is deleted."
  (error "music-theory MT5 pending: ~A" name))
