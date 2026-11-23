;;;; MT2 chord symbols: the value and the chord-quality facts.
;;;;
;;;; MT2 defines the CHORD-SYMBOL struct so that ROMAN-FOR and CHORD-FOR have a
;;;; chord to convert. MT3 adds the parser, the printer, the dialects and
;;;; realisation (src/chord-symbol.lisp, src/chord-tones.lisp); it fills the
;;;; slots MT2 leaves empty and keeps their types.
;;;;
;;;; Slots (all read-only; compared with EQUALP, printed readably):
;;;;   ROOT         a PITCH-CLASS-NAME; NIL only for N.C.
;;;;   QUALITY      a keyword of +CHORD-QUALITIES+, the closed set below; NIL
;;;;                only for N.C.
;;;;   EXTENSIONS   extension degrees above the seventh, ascending, from
;;;;                (9 11 13). C13 lists all three (src/chord-symbol.lisp).
;;;;   ALTERATIONS  altered chord tones as (degree . alter) pairs, ascending by
;;;;                degree: ((5 . -1) (9 . 1)) for 7♭5♯9.
;;;;   SUSPENSION   NIL, 2 or 4: the third is replaced by a second or a fourth.
;;;;   ADDED        added tones as (degree . alter) pairs: ((9 . 0)) for add9.
;;;;   OMITTED      omitted chord degrees, ascending: (3) for omit3.
;;;;   BASS         a PITCH-CLASS-NAME for a slash bass (a chord tone or not), or
;;;;                NIL for none. CHORD-FOR uses it for inversions: C/E.
;;;;   NO-CHORD-P   true for N.C.; then ROOT, QUALITY and BASS are NIL.
;;;;   TEXT         the parsed source string, or NIL for a constructed value.
;;;;   DIALECT      NIL, :CLASSICAL, :POP or :JAZZ: the dialect TEXT was read in.
;;;; Every slot defaults to NIL (the lists to ()), so (make-chord-symbol
;;;; :no-chord-p t) is N.C. and (make-chord-symbol :root c :quality :major) is C.
;;;; Values built by CHORD-FOR set only ROOT, QUALITY and BASS.
;;;;
;;;; +CHORD-QUALITIES+ lists one row per quality: the keyword, the MusicXML 4.0
;;;; <kind> it corresponds to (NIL when MusicXML has none), and the chord tones
;;;; above the root as interval names (read with PARSE-INTERVAL), third first.
;;;; Ninth, eleventh and thirteenth kinds are a seventh quality plus
;;;; EXTENSIONS; suspended kinds are a triad or seventh plus SUSPENSION. The
;;;; triads and sevenths (the first twelve rows) are +ROMAN-QUALITIES+.

(in-package #:music-theory)

(defstruct (chord-symbol (:constructor make-chord-symbol))
  (root nil :type (or null pitch-class-name) :read-only t)
  (quality nil :type (or null keyword) :read-only t)
  (extensions '() :type list :read-only t)
  (alterations '() :type list :read-only t)
  (suspension nil :type (member nil 2 4) :read-only t)
  (added '() :type list :read-only t)
  (omitted '() :type list :read-only t)
  (bass nil :type (or null pitch-class-name) :read-only t)
  (no-chord-p nil :type boolean :read-only t)
  (text nil :type (or null string) :read-only t)
  (dialect nil :type (member nil :classical :pop :jazz) :read-only t))

(defparameter +chord-qualities+
  '((:major             "major"              ("M3" "P5"))
    (:minor             "minor"              ("m3" "P5"))
    (:diminished        "diminished"         ("m3" "d5"))
    (:augmented         "augmented"          ("M3" "A5"))
    (:dominant-7        "dominant"           ("M3" "P5" "m7"))
    (:major-7           "major-seventh"      ("M3" "P5" "M7"))
    (:minor-7           "minor-seventh"      ("m3" "P5" "m7"))
    (:minor-major-7     "major-minor"        ("m3" "P5" "M7"))
    (:half-diminished-7 "half-diminished"    ("m3" "d5" "m7"))
    (:diminished-7      "diminished-seventh" ("m3" "d5" "d7"))
    (:augmented-7       "augmented-seventh"  ("M3" "A5" "m7"))
    (:augmented-major-7 nil                  ("M3" "A5" "M7"))
    (:major-6           "major-sixth"        ("M3" "P5" "M6"))
    (:minor-6           "minor-sixth"        ("m3" "P5" "M6"))
    (:power             "power"              ("P5")))
  "Chord qualities: (keyword musicxml-kind intervals-above-root). The closed set
of CHORD-SYMBOL-QUALITY values. Data, read in both directions.")
