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

(defun parse-key (string)
  "Parse STRING (see the file header) into one of the 30 KEYs."
  (declare (ignorable string))
  (%mt2-pending 'parse-key))

(defun key-name (key &key (accidentals :ascii))
  "Print KEY as \"G major\" or \"F# minor\" (\"F♯ minor\" with :UNICODE)."
  (declare (ignorable key accidentals))
  (%mt2-pending 'key-name))

(defun key-signature (key)
  "Sharps (positive) or flats (negative) of KEY, -7..7. INVALID-KEY beyond that."
  (declare (ignorable key))
  (%mt2-pending 'key-signature))

(defun scale-degrees (key &key (variant :natural))
  "The 7 PITCH-CLASS-NAMEs of KEY's scale (VARIANT :NATURAL, :HARMONIC or :MELODIC)."
  (declare (ignorable key variant))
  (%mt2-pending 'scale-degrees))

(defun degree-of (pitch key &key (variant :natural))
  "(values degree alteration octave) of PITCH in KEY; OCTAVE is NIL for a class."
  (declare (ignorable pitch key variant))
  (%mt2-pending 'degree-of))

(defun pitch-of-degree (degree key &key octave (alteration 0) (variant :natural))
  "Scale degree DEGREE of KEY, altered by ALTERATION: a PITCH-CLASS-NAME, or a
SPELLED-PITCH in the scale starting on the tonic in OCTAVE."
  (declare (ignorable degree key octave alteration variant))
  (%mt2-pending 'pitch-of-degree))
