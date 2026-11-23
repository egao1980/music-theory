;;;; MT2 keys, scales and scale degrees.
;;;;
;;;; A KEY is a TONIC (a PITCH-CLASS-NAME) and a MODE, :MAJOR or :MINOR (church
;;;; modes are reserved). Like every value here it is an immutable struct,
;;;; compared with EQUALP and printed readably.
;;;;
;;;; Key signature, on the line of fifths: KEY-SIGNATURE = (PITCH-FIFTHS tonic)
;;;; + the mode's offset in +MODE-SIGNATURES+ (major 0, minor -3). G major and
;;;; E minor are 1, Bb minor is -5; positive counts sharps, negative flats. The
;;;; 30 keys with signatures -7..7 are the valid keys. KEY-SIGNATURE signals
;;;; INVALID-KEY (TEXT NIL) for any other KEY (G# major is 8, Fb major -8).
;;;; Every other function here accepts any KEY: applied chords tonicize keys
;;;; such as G# major (V/V in C# major).
;;;;
;;;; Text syntax, read by PARSE-KEY (surrounding whitespace is trimmed):
;;;;   key   = tonic [ "m" ] | tonic space+ mode
;;;;   tonic = letter accidental            ; as PARSE-PITCH-CLASS
;;;;   mode  = "major" | "minor"            ; in any letter case
;;;;   space = #\Space
;;;; With no mode, an uppercase letter is major and a lowercase letter minor:
;;;; "G" is G major, "g" G minor, "f#" F# minor, "bb" Bb minor. A trailing "m"
;;;; is minor whatever the case ("Gm", "F#m", "Ebm", "bbm"). With a mode word
;;;; the letter's case is ignored ("eb major" is Eb major). Anything else
;;;; ("Gmaj", "G maj", "Gminor", "GM", "G-"), and any key whose signature lies
;;;; outside -7..7 ("G#", "Fb", "e# minor"), signals INVALID-KEY with TEXT =
;;;; the original string, inside a USE-VALUE restart.
;;;;
;;;; KEY-NAME prints an uppercase tonic, one space and the mode word: "G major",
;;;; "F# minor", "Bb minor". ACCIDENTALS is :ASCII (default) or :UNICODE
;;;; ("F♯ minor"), as for PITCH-NAME. (parse-key (key-name k)) is EQUALP to k
;;;; for the 30 keys.
;;;;
;;;; SCALE-DEGREES key &key (variant :natural) → a list of 7 PITCH-CLASS-NAMEs,
;;;; degrees 1..7. Degree d lies d-1 letters above the tonic, at the semitones
;;;; above the tonic listed for it in the scale of +SCALES+ that +MODE-VARIANTS+
;;;; gives for the mode and VARIANT:
;;;;   major  every variant is the major scale;
;;;;   minor  :NATURAL (Aeolian), :HARMONIC (raised 7th), :MELODIC (the
;;;;          ascending form: raised 6th and 7th).
;;;; Any other VARIANT is a TYPE-ERROR. A degree that needs more than two
;;;; accidentals (in a key beyond the 30) signals INVALID-PITCH.
;;;;
;;;; DEGREE-OF pitch key &key (variant :natural) → (values degree alteration octave)
;;;; for a SPELLED-PITCH or PITCH-CLASS-NAME:
;;;;   DEGREE      1 + (letter of PITCH - letter of the tonic) mod 7. The letter
;;;;               decides: in C major B#3 is degree 7 and Cb4 degree 1.
;;;;   ALTERATION  alter of PITCH - alter of that degree in (SCALE-DEGREES key
;;;;               :variant variant). G# in A minor is 7 with +1 (:natural) or
;;;;               0 (:harmonic); Fb in F# major is 1 with -2.
;;;;   OCTAVE      for a SPELLED-PITCH, the octave of the tonic at or below it,
;;;;               floor((PITCH-DIATONIC-INDEX pitch - tonic letter) / 7):
;;;;               C#5 in B major is 4, B#3 in C major is 3. NIL for a class.
;;;;
;;;; PITCH-OF-DEGREE degree key &key octave (alteration 0) (variant :natural) is
;;;; the inverse. DEGREE is 1..7 (else TYPE-ERROR); the result is that scale
;;;; degree with ALTERATION added to its alter. Without OCTAVE it is a
;;;; PITCH-CLASS-NAME. With OCTAVE it is a SPELLED-PITCH in the scale that
;;;; starts on the tonic in OCTAVE: its diatonic index is tonic letter +
;;;; 7 * OCTAVE + DEGREE - 1, so degree 2 of B major in octave 4 is C#5 and
;;;; degree 7 of C# major in octave 4 is B#4. For every pitch p and key k:
;;;;   (multiple-value-bind (d a o) (degree-of p k :variant v)
;;;;     (pitch-of-degree d k :alteration a :octave o :variant v))  is EQUALP to p.
;;;; It signals INVALID-PITCH when the result needs more than two accidentals.

(in-package #:music-theory)

(defstruct (key (:constructor make-key))
  (tonic (make-pitch-class-name :letter 0) :type pitch-class-name :read-only t)
  (mode :major :type (member :major :minor) :read-only t))

(defparameter +scales+
  '((:major          . #(0 2 4 5 7 9 11))
    (:natural-minor  . #(0 2 3 5 7 8 10))
    (:harmonic-minor . #(0 2 3 5 7 8 11))
    (:melodic-minor  . #(0 2 3 5 7 9 11)))
  "Semitones above the tonic of degrees 1..7; degree d is d-1 letters up. Data.")

(defparameter +mode-variants+
  '((:major (:natural . :major) (:harmonic . :major) (:melodic . :major))
    (:minor (:natural . :natural-minor) (:harmonic . :harmonic-minor)
            (:melodic . :melodic-minor)))
  "Per mode, (variant . scale in +SCALES+). Data.")

(defparameter +mode-signatures+
  '((:major . 0) (:minor . -3))
  "Per mode, the key signature minus the tonic's line-of-fifths position.
Church modes would add rows (dorian -2, mixolydian -1, ...). Data.")

(defparameter +mode-words+
  '((:major . "major") (:minor . "minor"))
  "Mode keyword → its word in key names, read case-insensitively. Data.")

;;; Kernel: positions on the line of fifths -----------------------------------
;;;
;;; Pitch classes are handled as PITCH-FIFTHS integers, unbounded, and turned
;;; back into names only by FIFTHS-PITCH-CLASS, the one place a spelling beyond
;;; two accidentals signals INVALID-PITCH. An interval moves a pitch the same
;;; distance on the line of fifths from every start, so the offsets of the
;;; scales are measured once, at load time, with MT0's TRANSPOSE-PITCH.

(defun %interval-fifths (interval)
  "How far INTERVAL moves a pitch on the line of fifths (M2 → 2, m3 → -3).
The same from every start, so it is measured from C4 with TRANSPOSE-PITCH."
  (pitch-fifths (transpose-pitch (make-spelled-pitch :letter 0 :alter 0 :octave 4) interval)))

(defparameter +scale-fifths+
  (loop for (scale . semitones) in +scales+
        collect (cons scale
                      (coerce (loop for steps from 0
                                    for s across semitones
                                    collect (%interval-fifths
                                             (make-interval :steps steps :semitones s)))
                              'simple-vector)))
  "Per scale of +SCALES+, the fifths offsets of degrees 1..7 from the tonic.
Derived from +SCALES+ at load time.")

(defun %scale-fifths (mode variant)
  "The fifths offsets (+SCALE-FIFTHS+) of the scale +MODE-VARIANTS+ gives for
MODE and VARIANT. An unknown VARIANT is a TYPE-ERROR."
  (let* ((variants (cdr (assoc mode +mode-variants+)))
         (entry (assoc variant variants)))
    (unless entry
      (error 'type-error :datum variant
                         :expected-type `(member ,@(mapcar #'car variants))))
    (cdr (assoc (cdr entry) +scale-fifths+))))

(defun %degree-fifths (key degree variant)
  "Fifths position of scale degree DEGREE (1..7) of KEY in VARIANT. Never signals
for a spelling: the result may lie beyond two accidentals."
  (+ (pitch-fifths (key-tonic key))
     (svref (%scale-fifths (key-mode key) variant) (1- degree))))

(defun %signature-fifths (key)
  "KEY's signature on the line of fifths, unchecked: tonic + the mode's offset."
  (+ (pitch-fifths (key-tonic key))
     (cdr (assoc (key-mode key) +mode-signatures+))))

(defun %signature-p (fifths)
  "True for a signature of the 30 keys: seven flats to seven sharps."
  (<= -7 fifths 7))

(defun %alter-difference (from to)
  "TO's alter minus FROM's, for two fifths positions on the same letter: their
distance on the line of fifths is 7 per semitone."
  (multiple-value-bind (difference remainder) (floor (- to from) 7)
    (assert (zerop remainder) () "fifths positions ~D and ~D are not on one letter" from to)
    difference))

;;; Keys ----------------------------------------------------------------------

(defun parse-key (string)
  "Parse STRING (see the file header) into one of the 30 KEYs."
  (check-type string string)
  (flet ((fail (reason)
           (return-from parse-key
             (%parse-failure 'invalid-key string reason #'parse-key))))
    (let ((text (string-trim +pitch-whitespace+ string)))
      ;; Our own FAIL: a bad tonic is INVALID-KEY, never INVALID-PITCH.
      (multiple-value-bind (letter alter next) (%scan-spelling text #'fail)
        (let* ((rest (subseq text next))
               (mode (cond ((string= rest "")
                            (if (upper-case-p (char text 0)) :major :minor))
                           ((string= rest "m") :minor)
                           ((char= #\Space (char rest 0))
                            (or (car (rassoc (string-left-trim '(#\Space) rest) +mode-words+
                                             :test #'string-equal))
                                (fail "unknown mode")))
                           (t (fail "trailing characters"))))
               ;; ALTER comes from +ACCIDENTAL-TOKENS+, so the slot types hold.
               (key (make-key :tonic (make-pitch-class-name :letter letter :alter alter)
                              :mode mode)))
          ;; Checked here, with TEXT, rather than by KEY-SIGNATURE (TEXT NIL).
          (unless (%signature-p (%signature-fifths key))
            (fail "signature beyond seven sharps or flats"))
          key)))))

(defun key-name (key &key (accidentals :ascii))
  "Print KEY as \"G major\" or \"F# minor\" (\"F♯ minor\" with :UNICODE)."
  (check-type key key)
  (format nil "~A ~A"
          (pitch-class-string (key-tonic key) :accidentals accidentals)
          (cdr (assoc (key-mode key) +mode-words+))))

(defun key-signature (key)
  "Sharps (positive) or flats (negative) of KEY, -7..7. INVALID-KEY beyond that."
  (check-type key key)
  (let ((fifths (%signature-fifths key)))
    (unless (%signature-p fifths)
      (error 'invalid-key :reason "signature beyond seven sharps or flats"))
    fifths))

(defun scale-degrees (key &key (variant :natural))
  "The 7 PITCH-CLASS-NAMEs of KEY's scale (VARIANT :NATURAL, :HARMONIC or :MELODIC)."
  (check-type key key)
  (let ((tonic (pitch-fifths (key-tonic key))))
    (loop for offset across (%scale-fifths (key-mode key) variant)
          collect (fifths-pitch-class (+ tonic offset)))))

(defun degree-of (pitch key &key (variant :natural))
  "(values degree alteration octave) of PITCH in KEY; OCTAVE is NIL for a class."
  (check-type key key)
  ;; The variant first: an unknown one is a TYPE-ERROR whatever PITCH is.
  (%scale-fifths (key-mode key) variant)
  (let* ((tonic-letter (pitch-class-name-letter (key-tonic key)))
         (degree (1+ (mod (- (%letter-alter pitch) tonic-letter) 7))))
    ;; The letter decides the degree, so PITCH and the scale degree share a
    ;; letter and their alters differ by a whole number of semitones.
    (values degree
            (%alter-difference (%degree-fifths key degree variant) (pitch-fifths pitch))
            (and (spelled-pitch-p pitch)
                 (floor (- (pitch-diatonic-index pitch) tonic-letter) 7)))))

(defun pitch-of-degree (degree key &key octave (alteration 0) (variant :natural))
  "Scale degree DEGREE of KEY, altered by ALTERATION: a PITCH-CLASS-NAME, or a
SPELLED-PITCH in the scale starting on the tonic in OCTAVE."
  (check-type degree (integer 1 7))
  (check-type key key)
  (check-type alteration integer)
  (check-type octave (or null integer))
  ;; FIFTHS-PITCH-CLASS signals INVALID-PITCH before any slot-typed constructor.
  (let ((class (fifths-pitch-class (+ (%degree-fifths key degree variant) (* 7 alteration)))))
    (if (null octave)
        class
        (make-spelled-pitch
         :letter (pitch-class-name-letter class)
         :alter (pitch-class-name-alter class)
         ;; Diatonic index = tonic letter + 7 * OCTAVE + DEGREE - 1.
         :octave (floor (+ (pitch-class-name-letter (key-tonic key)) (* 7 octave) (1- degree))
                        7)))))
