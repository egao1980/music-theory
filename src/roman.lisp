;;;; MT2 Roman numerals: data conversion between chords and scale degrees.
;;;; Harmonic analysis (which reading a passage needs) belongs to consumers.
;;;;
;;;; A ROMAN-NUMERAL names a triad or seventh chord by its root's scale degree.
;;;; It is key-free data: the same value means different chords in different
;;;; keys. Slots (read-only):
;;;;   DEGREE      1..7.
;;;;   ALTERATION  -2..2, the prefix accidental ("b" -1, "#" +1): semitones
;;;;               added to the default root of DEGREE, letter kept.
;;;;   QUALITY     a keyword of +ROMAN-QUALITIES+ (triads and sevenths of
;;;;               +CHORD-QUALITIES+).
;;;;   INVERSION   0 root position, 1 first, 2 second, 3 third (sevenths only).
;;;;   APPLIED-TO  NIL, or the target of an applied chord (V/V, vii°7/V): a
;;;;               ROMAN-NUMERAL with QUALITY :MAJOR or :MINOR, INVERSION 0 and
;;;;               no APPLIED-TO of its own. One level only.
;;;; Mixture is not a slot: whether iv is borrowed depends on the key (it is in
;;;; C major, not in C minor), so it is ROMAN-MIXTURE-P of a numeral and a key.
;;;;
;;;; Default root of DEGREE in a key (music21's convention): the degree of the
;;;; key's natural scale, (SCALE-DEGREES key :variant :natural), except that in a
;;;; minor key degrees 6 and 7 are raised a semitone when the QUALITY is
;;;; lowercase (its case in +ROMAN-QUALITIES+). In C minor vi, vi° and vii°7 sit
;;;; on A and B; VI and VII on Ab and Bb. ALTERATION applies after this rule, so
;;;; bVI in C minor is Abb and #vii°7 is B#.
;;;;
;;;; Text syntax, read by PARSE-ROMAN (surrounding whitespace is trimmed, none
;;;; is allowed inside):
;;;;   roman      = chord [ "/" target ]
;;;;   chord      = accidental numeral marker figure
;;;;              | "N" triad-figure                    ; Neapolitan = bII
;;;;   target     = accidental numeral                  ; no marker, no figure
;;;;   accidental = "" | an accidental token of PARSE-PITCH (b bb # ## x ♭ ♯ 𝄫 𝄪 ♭♭ ♯♯)
;;;;   numeral    = "I" | "II" | "III" | "IV" | "V" | "VI" | "VII"   ; uppercase
;;;;              | "i" | "ii" | "iii" | "iv" | "v" | "vi" | "vii"   ; lowercase
;;;;   marker     = "" | "o" | "°" | "/o" | "ø" | "+" | "M" | "+M"
;;;;   figure     = triad-figure | seventh-figure
;;;;   triad-figure   = "" | "6" | "64" | "6/4"                        ; inversion 0 1 2
;;;;   seventh-figure = "7" | "65" | "6/5" | "43" | "4/3" | "42" | "4/2" | "2"
;;;;                                                                ; 0 1 1 2 2 3 3 3
;;;; The numeral is the longest match ("VII", not "VI" then "I"); the figure is
;;;; the longest match, so "V6/5/V" is V65 applied to V and "V6/V" is V6 applied
;;;; to V. "/o" is a marker only directly after the numeral.
;;;; The numeral's case, the marker and whether the figure is a seventh figure
;;;; pick the QUALITY from +ROMAN-QUALITIES+:
;;;;   case   marker   triad         seventh
;;;;   upper  ""       :major        :dominant-7
;;;;   lower  ""       :minor        :minor-7
;;;;   lower  o °      :diminished   :diminished-7
;;;;   lower  /o ø     -             :half-diminished-7
;;;;   upper  +        :augmented    :augmented-7
;;;;   upper  M        -             :major-7
;;;;   lower  M        -             :minor-major-7
;;;;   upper  +M       -             :augmented-major-7
;;;; A seventh figure names the seventh's quality explicitly, never "the seventh
;;;; the key provides": V7 and I7 are dominant sevenths in every key, IM7 is the
;;;; major seventh chord on I, IVM65 the major seventh on IV in first inversion.
;;;; A target's quality is :MAJOR when its numeral is uppercase, else :MINOR.
;;;; "N", "N6", "N64" read as bII, bII6, bII64. Anything else signals
;;;; INVALID-ROMAN-NUMERAL with TEXT = the original string, inside a USE-VALUE
;;;; restart: "", "VIII", "Vi", "Io", "v+", "IM", "iiø", "V9", "V/V/V",
;;;; "V/viio", "V7/V7", "V/", "Ger65", " V 7".
;;;;
;;;; ROMAN-NAME prints the canonical text: accidental, numeral, marker, figure
;;;; (triads "" 6 64; sevenths 7 65 43 42), then "/" and the target. ACCIDENTALS
;;;; :ASCII (default) prints b bb # ## and the markers o /o + M +M; :UNICODE
;;;; prints ♭ 𝄫 ♯ 𝄪 (the PITCH-NAME columns) and ° ø + M +M. "N6" prints as
;;;; "bII6", "ii6/5" as "ii65", "V2" as "V42", "vii°7/V" as "viio7/V" (Unicode
;;;; "vii°7/V"), "viiø7" as "vii/o7" (Unicode "viiø7").
;;;; (parse-roman (roman-name r)) is EQUALP to r for every well-formed
;;;; ROMAN-NUMERAL, in both styles, and (roman-name (parse-roman s)) = s for
;;;; canonical ASCII text. ROMAN-NAME of a malformed value (see CHORD-FOR)
;;;; signals INVALID-ROMAN-NUMERAL with TEXT NIL.
;;;;
;;;; CHORD-FOR roman key → a CHORD-SYMBOL with only ROOT, QUALITY and BASS set:
;;;;   ROOT     the default root of DEGREE (above), moved by ALTERATION.
;;;;   QUALITY  the numeral's QUALITY.
;;;;   BASS     NIL in root position; otherwise the chord's third, fifth or
;;;;            seventh: ROOT moved by the 1st, 2nd or 3rd interval of the
;;;;            quality's row in +CHORD-QUALITIES+.
;;;; An applied numeral is read in the tonicized key: its tonic is the ROOT of
;;;; (chord-for target key), its mode :MAJOR for an uppercase target and :MINOR
;;;; for a lowercase one. In C major V/V is D major, V/iv is C major (V of F
;;;; minor), vii°7/V is F# A C Eb and V/bVI is Eb major; in A minor V/III is G
;;;; major and V/VII is D major. A malformed value (a triad with INVERSION 3, a
;;;; QUALITY outside +ROMAN-QUALITIES+, a malformed target) signals
;;;; INVALID-ROMAN-NUMERAL with TEXT NIL; a chord tone that needs more than two
;;;; accidentals signals INVALID-PITCH.
;;;;
;;;; ROMAN-FOR chord key &key applied-to → the ROMAN-NUMERAL that CHORD-FOR maps
;;;; back to CHORD. It reads the chord literally: a chromatic chord gets a prefix
;;;; accidental, never an applied reading, because choosing one is analysis. In
;;;; C major D F# A is II, D F# A C is II7 and F# A C Eb is #ivo7.
;;;;   DEGREE      1 + (root letter - tonic letter) mod 7
;;;;   QUALITY     the chord's QUALITY
;;;;   ALTERATION  root alter - alter of the default root for DEGREE and QUALITY
;;;;   INVERSION   from BASS: NIL or the root 0, the third 1, the fifth 2, the
;;;;               seventh 3 (spelling must match: EQUALP pitch-class names)
;;;; With APPLIED-TO (a target as above) the chord is read the same way in the
;;;; tonicized key and the result carries APPLIED-TO: in C major D F# A C with
;;;; :applied-to V is V7/V, and F# A C Eb is viio7/V.
;;;; CHORD must have a ROOT, a QUALITY of +ROMAN-QUALITIES+ and no EXTENSIONS,
;;;; ALTERATIONS, SUSPENSION, ADDED or OMITTED tones (TEXT and DIALECT are
;;;; ignored). Otherwise, or when the BASS is not a chord tone, or |ALTERATION|
;;;; would exceed 2, it signals MUSIC-THEORY-ERROR (TEXT NIL, with a REASON).
;;;; A malformed APPLIED-TO signals INVALID-ROMAN-NUMERAL.
;;;;
;;;; ROMAN-MIXTURE-P roman key is true when the numeral is borrowed from the
;;;; parallel key (same tonic, other mode): its chord (ROOT and QUALITY from
;;;; CHORD-FOR; inversion ignored) is not the chord of any numeral listed for
;;;; the key's mode in +DIATONIC-NUMERALS+, but is the chord of one listed for
;;;; the parallel key. An applied numeral is judged in its tonicized key. In C
;;;; major i, ii°, iiø7, bIII, iv, v, bVI, bVII and vii°7 are mixture, bII is
;;;; not; in C minor I, ii, IV, vi and viiø7 are, V and vii° are not.

(in-package #:music-theory)

(defstruct (roman-numeral (:constructor make-roman-numeral))
  (degree 1 :type (integer 1 7) :read-only t)
  (alteration 0 :type (integer -2 2) :read-only t)
  (quality :major :type keyword :read-only t)
  (inversion 0 :type (integer 0 3) :read-only t)
  (applied-to nil :type (or null roman-numeral) :read-only t))

(defparameter +roman-numerals+ #("I" "II" "III" "IV" "V" "VI" "VII")
  "Degree 1..7 → its uppercase numeral. Data.")

(defparameter +roman-qualities+
  '((:major             :upper ""   ""   nil)
    (:minor             :lower ""   ""   nil)
    (:diminished        :lower "o"  "°"  nil)
    (:augmented         :upper "+"  "+"  nil)
    (:dominant-7        :upper ""   ""   t)
    (:major-7           :upper "M"  "M"  t)
    (:minor-7           :lower ""   ""   t)
    (:minor-major-7     :lower "M"  "M"  t)
    (:half-diminished-7 :lower "/o" "ø"  t)
    (:diminished-7      :lower "o"  "°"  t)
    (:augmented-7       :upper "+"  "+"  t)
    (:augmented-major-7 :upper "+M" "+M" t))
  "Qualities a Roman numeral can name: (quality case ascii-marker unicode-marker
seventh-p). PARSE-ROMAN reads it by (case marker seventh-p), ROMAN-NAME by
quality. Data, read in both directions.")

(defparameter +roman-figures+
  '((nil 0 "") (nil 1 "6") (nil 2 "64" "6/4")
    (t 0 "7") (t 1 "65" "6/5") (t 2 "43" "4/3") (t 3 "42" "4/2" "2"))
  "Inversion figures: (seventh-p inversion canonical . other-spellings). Data.")

(defparameter +minor-raised-degrees+ '(6 7)
  "Degrees whose default root in a minor key is raised a semitone for a
lowercase numeral (vi, vii°). Data.")

(defparameter +diatonic-numerals+
  '((:major "I" "ii" "iii" "IV" "V" "vi" "viio"
            "IM7" "ii7" "iii7" "IVM7" "V7" "vi7" "vii/o7")
    (:minor "i" "iio" "III" "iv" "v" "V" "VI" "VII" "viio"
            "i7" "ii/o7" "IIIM7" "iv7" "v7" "V7" "VIM7" "VII7" "viio7"))
  "The diatonic triads and sevenths of each mode, as PARSE-ROMAN text: the
major scale; the natural minor plus the harmonic minor's V, V7, vii° and vii°7.
ROMAN-MIXTURE-P compares chords against them. Data.")

(defun parse-roman (string)
  "Parse STRING (see the file header) into a ROMAN-NUMERAL."
  (declare (ignorable string))
  (%mt2-pending 'parse-roman))

(defun roman-name (roman &key (accidentals :ascii))
  "Canonical text of ROMAN (\"V65/V\"); ACCIDENTALS is :ASCII or :UNICODE."
  (declare (ignorable roman accidentals))
  (%mt2-pending 'roman-name))

(defun chord-for (roman key)
  "The CHORD-SYMBOL (ROOT, QUALITY, BASS) that ROMAN names in KEY."
  (declare (ignorable roman key))
  (%mt2-pending 'chord-for))

(defun roman-for (chord key &key applied-to)
  "The ROMAN-NUMERAL naming CHORD (a CHORD-SYMBOL) in KEY, read literally, or
as an applied chord of APPLIED-TO when that target is given."
  (declare (ignorable chord key applied-to))
  (%mt2-pending 'roman-for))

(defun roman-mixture-p (roman key)
  "True when ROMAN's chord in KEY is diatonic to the parallel key but not to KEY."
  (declare (ignorable roman key))
  (%mt2-pending 'roman-mixture-p))
