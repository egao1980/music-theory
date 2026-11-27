;;;; Conditions for every music-theory slice (CLHS 9). Parse functions signal
;;;; these with ERROR / WARN and establish restarts around the signal:
;;;;
;;;;   PARSE-PITCH, PARSE-PITCH-CLASS, PARSE-INTERVAL, PARSE-KEY (MT2),
;;;;   PARSE-ROMAN (MT2): a USE-VALUE restart; its value is returned from the
;;;;     parse function.
;;;;   PARSE-CHORD-SYMBOL (MT3): USE-VALUE and SKIP-CHORD-SYMBOL (returns NIL)
;;;;     around CHORD-SYMBOL-PARSE-ERROR; USE-VALUE (a quality keyword) around
;;;;     the UNKNOWN-CHORD-QUALITY warning.
;;;;   SPELL-MIDI, SPELL-SEQUENCE (MT4): AMBIGUOUS-SPELLING is signalled with
;;;;     SIGNAL (silent unless handled) inside USE-VALUE (a SPELLED-PITCH to use)
;;;;     and MUFFLE-WARNING (keep the default spelling); see src/spell.lisp.
;;;;   FIT-KEY (MT5): NO-KEY-EVIDENCE inside a USE-VALUE restart; its value is
;;;;     returned from FIT-KEY. Its argument checks are CHECK-TYPE, so a
;;;;     TYPE-ERROR offers STORE-VALUE; see src/key-fit.lisp.

(in-package #:music-theory)

(define-condition music-theory-error (error)
  ((text :initarg :text :initform nil :reader music-theory-error-text
         :documentation "The offending input string, or NIL for a non-text input.")
   (reason :initarg :reason :initform nil :reader music-theory-error-reason
           :documentation "A short lower-case explanation, e.g. \"unknown letter\"."))
  (:report (lambda (c s)
             (format s "~A~@[ ~S~]~@[: ~A~]"
                     (string-downcase (symbol-name (type-of c)))
                     (music-theory-error-text c)
                     (music-theory-error-reason c)))))

(define-condition invalid-pitch (music-theory-error) ()
  (:documentation "A pitch or pitch class can't be parsed, or an operation
would need more than two accidentals."))

(define-condition invalid-interval (music-theory-error) ()
  (:documentation "An interval can't be parsed, or its quality lies beyond
doubly augmented / doubly diminished, so it has no name in this model."))

(define-condition invalid-meter (music-theory-error) ())
(define-condition invalid-key (music-theory-error) ()
  (:documentation "A key can't be parsed, or its signature lies beyond seven
sharps or flats (G# major), so it is not one of the 30 keys."))

(define-condition invalid-roman-numeral (music-theory-error) ()
  (:documentation "A Roman numeral can't be parsed (TEXT is the input), or a
ROMAN-NUMERAL value is malformed (TEXT NIL): a triad in third inversion, a
quality outside +ROMAN-QUALITIES+, or an applied target that is not a
root-position major or minor triad."))

(define-condition chord-symbol-parse-error (music-theory-error)
  ((position :initarg :position :initform nil
             :reader chord-symbol-parse-error-position
             :documentation "Zero-based index into TEXT where parsing stopped.")
   (expected :initarg :expected :initform nil
             :reader chord-symbol-parse-error-expected
             :documentation "A short description of what the grammar expected there."))
  (:report (lambda (c s)
             (format s "chord-symbol-parse-error~@[ ~S~]~@[ at ~D~]~@[: expected ~A~]~@[ (~A)~]"
                     (music-theory-error-text c)
                     (chord-symbol-parse-error-position c)
                     (chord-symbol-parse-error-expected c)
                     (music-theory-error-reason c)))))

(define-condition no-key-evidence (music-theory-error) ()
  (:documentation "FIT-KEY's events give no key anything to correlate with: they
weigh nothing in total (REASON \"zero total weight\"), or every offset folds them
into a constant histogram (REASON \"constant histogram at every offset\"). TEXT is
NIL. Signalled with ERROR inside a USE-VALUE restart (src/key-fit.lisp)."))

(define-condition music-theory-warning (warning) ())

(define-condition unknown-chord-quality (music-theory-warning)
  ((text :initarg :text :initform nil :reader unknown-chord-quality-text
         :documentation "The unknown quality word, e.g. \"dom7\"."))
  (:report (lambda (c s)
             (format s "unknown chord quality ~S" (unknown-chord-quality-text c)))))

(define-condition ambiguous-spelling (music-theory-warning)
  ((midi :initarg :midi :initform nil :reader ambiguous-spelling-midi
         :documentation "The MIDI number being spelled.")
   (candidates :initarg :candidates :initform nil :reader ambiguous-spelling-candidates
               :documentation "The two SPELLED-PITCHes it lies midway between, flatter first."))
  (:documentation "A note lies midway between two spellings and no rule decides
(rule S7 in src/spell.lisp). Signalled with SIGNAL, so it is silent unless handled.")
  (:report (lambda (c s)
             (format s "ambiguous spelling of MIDI ~D: ~{~A~^ or ~}"
                     (ambiguous-spelling-midi c)
                     (mapcar #'pitch-name (ambiguous-spelling-candidates c))))))

(defun skip-chord-symbol (&optional condition)
  "Invoke the SKIP-CHORD-SYMBOL restart (established by PARSE-CHORD-SYMBOL)."
  (let ((restart (find-restart 'skip-chord-symbol condition)))
    (when restart (invoke-restart restart))))
