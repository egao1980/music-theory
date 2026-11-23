;;;; Conditions for every music-theory slice (CLHS 9). Parse functions signal
;;;; these with ERROR / WARN and establish restarts around the signal:
;;;;
;;;;   PARSE-PITCH, PARSE-PITCH-CLASS, PARSE-INTERVAL, PARSE-KEY (MT2),
;;;;   PARSE-ROMAN (MT2): a USE-VALUE restart; its value is returned from the
;;;;     parse function.
;;;;   PARSE-CHORD-SYMBOL (MT3): USE-VALUE and SKIP-CHORD-SYMBOL (returns NIL).

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
             :documentation "A short description of what the grammar expected there.")))

(define-condition music-theory-warning (warning) ())

(define-condition unknown-chord-quality (music-theory-warning)
  ((text :initarg :text :initform nil :reader unknown-chord-quality-text)))

(define-condition ambiguous-spelling (music-theory-warning)
  ((midi :initarg :midi :reader ambiguous-spelling-midi)
   (candidates :initarg :candidates :reader ambiguous-spelling-candidates)))

(defun skip-chord-symbol (&optional condition)
  "Invoke the SKIP-CHORD-SYMBOL restart (established by PARSE-CHORD-SYMBOL)."
  (let ((restart (find-restart 'skip-chord-symbol condition)))
    (when restart (invoke-restart restart))))
