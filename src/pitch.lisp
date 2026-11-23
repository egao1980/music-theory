;;;; MT0 spelled pitches.
;;;;
;;;; Values are immutable structs (read-only slots, no SETF accessors), compared
;;;; with EQUALP and printed readably (#S(...)).
;;;;
;;;; LETTER is 0..6 for C D E F G A B. ALTER is -2..2 (bb b natural # ##).
;;;; OCTAVE is scientific: C4 = MIDI 60, and the octave belongs to the letter,
;;;; so B#3 is MIDI 60 and Cb4 is MIDI 59. Parsed octaves are -1..9.
;;;;
;;;; Text syntax, read by PARSE-PITCH (surrounding whitespace is trimmed):
;;;;   pitch      = letter accidental octave
;;;;   letter     = "A".."G" | "a".."g"
;;;;   accidental = "" | "#" | "##" | "x" | "b" | "bb"
;;;;              | "♯" | "♯♯" | "𝄪" | "♭" | "♭♭" | "𝄫"
;;;;   octave     = ["-"] digit+          ; -1..9
;;;; Anything else signals INVALID-PITCH with TEXT = the original string, inside
;;;; a USE-VALUE restart. "-" is never a flat: "B-1" is B in octave -1.
;;;; PARSE-PITCH-CLASS reads letter accidental with no octave.
;;;;
;;;; PITCH-NAME prints ASCII by default ("F#4", "Bbb3", "C##5"), so
;;;; (pitch-name (parse-pitch s)) = s for canonical ASCII input.
;;;; With :ACCIDENTALS :UNICODE it prints ♯ ♭ 𝄪 𝄫 ("F♯4", "B𝄫3", "C𝄪5").

(in-package #:music-theory)

(defstruct (spelled-pitch (:constructor make-spelled-pitch (&key letter (alter 0) octave)))
  (letter 0 :type (integer 0 6) :read-only t)
  (alter 0 :type (integer -2 2) :read-only t)
  (octave 4 :type integer :read-only t))

(defstruct (pitch-class-name (:constructor make-pitch-class-name (&key letter (alter 0))))
  (letter 0 :type (integer 0 6) :read-only t)
  (alter 0 :type (integer -2 2) :read-only t))

(defparameter +letter-names+ "CDEFGAB"
  "Letter index → name. Data, not a rule.")

(defparameter +letter-semitones+ #(0 2 4 5 7 9 11)
  "Semitones above C of each natural letter, in letter order.")

(defun parse-pitch (string)
  "Parse STRING (see the file header) into a SPELLED-PITCH."
  (declare (ignorable string))
  (%mt0-pending 'parse-pitch))

(defun pitch-name (pitch &key (accidentals :ascii))
  "Print PITCH as text. ACCIDENTALS is :ASCII (default) or :UNICODE."
  (declare (ignorable pitch accidentals))
  (%mt0-pending 'pitch-name))

(defun parse-pitch-class (string)
  "Parse letter + accidental (no octave) into a PITCH-CLASS-NAME."
  (declare (ignorable string))
  (%mt0-pending 'parse-pitch-class))

(defun pitch-class-string (pitch-class &key (accidentals :ascii))
  "Print a PITCH-CLASS-NAME (\"F#\", or \"F♯\" with :UNICODE)."
  (declare (ignorable pitch-class accidentals))
  (%mt0-pending 'pitch-class-string))

(defun pitch-midi (pitch)
  "MIDI number of a SPELLED-PITCH: 12 * (octave + 1) + letter semitones + alter."
  (declare (ignorable pitch))
  (%mt0-pending 'pitch-midi))

(defun pitch-class (pitch)
  "Unspelled pitch class 0..11 of a SPELLED-PITCH or PITCH-CLASS-NAME (Cb → 11)."
  (declare (ignorable pitch))
  (%mt0-pending 'pitch-class))

(defun pitch-diatonic-index (pitch)
  "LETTER + 7 * OCTAVE: the staff position, ignoring accidentals (C4 → 28)."
  (declare (ignorable pitch))
  (%mt0-pending 'pitch-diatonic-index))

(defun pitch-spelling (pitch)
  "The PITCH-CLASS-NAME of a SPELLED-PITCH (its letter and alter)."
  (declare (ignorable pitch))
  (%mt0-pending 'pitch-spelling))

(defun pitch-enharmonic-p (p q)
  "True when P and Q sound the same: equal MIDI numbers for SPELLED-PITCHes,
equal pitch classes for PITCH-CLASS-NAMEs. F#4 and Gb4 are enharmonic but not
EQUALP."
  (declare (ignorable p q))
  (%mt0-pending 'pitch-enharmonic-p))
