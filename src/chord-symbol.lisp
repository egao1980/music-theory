;;;; MT3 chord symbols: the grammar, the dialects and the printer.
;;;;
;;;; PARSE-CHORD-SYMBOL reads lead-sheet text into a CHORD-SYMBOL (the value is
;;;; defined in src/chord.lisp and is unchanged here) with a hand-written
;;;; recursive descent over the closed grammar below. No regular expressions.
;;;; PRINT-CHORD-SYMBOL writes a dialect's canonical text. Realisation,
;;;; essential-tone priorities and transposition are in src/chord-tones.lisp.
;;;;
;;;; Grammar (EBNF). Literals are case-sensitive; { } repeats, [ ] is optional.
;;;;
;;;;   symbol       = { space } ( no-chord | chord ) { space }
;;;;   no-chord     = "N.C." | "N.C" | "NC"
;;;;   chord        = root body [ "/" bass ]
;;;;   root         = letter accidental
;;;;   bass         = letter accidental
;;;;   letter       = "A" | "B" | "C" | "D" | "E" | "F" | "G"        ; uppercase only
;;;;   accidental   = "" | a token of +ACCIDENTAL-TOKENS+            ; b bb # ## x ♭ ♯ 𝄫 𝄪 ♭♭ ♯♯
;;;;   body         = quality { modifier } [ group ]
;;;;   quality      = word | unknown
;;;;   word         = a quality word of the dialect                  ; "" is the major triad
;;;;   unknown      = alpha { alpha | digit }                        ; see Unknown qualities
;;;;   modifier     = alteration | raised-fifth | addition | omission | suspension | "alt"
;;;;   group        = "(" item { [ "," ] item } ")"
;;;;   item         = modifier | add-degree                          ; bare degree: (9) is add9
;;;;   alteration   = flat ( "5" | "9" | "13" ) | sharp ( "5" | "9" | "11" )
;;;;   raised-fifth = "+"                                            ; no digit follows: #5
;;;;   addition     = "add" [ flat | sharp ] add-degree
;;;;   omission     = ( "omit" | "no" ) omit-degree
;;;;   suspension   = "sus2" | "sus4" | "sus"                        ; "sus" is sus4
;;;;   flat         = "b" | "♭" | "-"
;;;;   sharp        = "#" | "♯" | "+"
;;;;   add-degree   = "2" | "4" | "6" | "9" | "11" | "13"
;;;;   omit-degree  = "3" | "5" | "9" | "11"
;;;;   space        = a character of +PITCH-WHITESPACE+
;;;;   alpha        = a character satisfying ALPHA-CHAR-P;  digit = "0" .. "9"
;;;;
;;;; The quality words of a dialect are the rows of +CHORD-QUALITY-WORDS+ whose
;;;; DIALECTS include it (no DIALECTS: every dialect), and the seventh words:
;;;; each stem of +CHORD-SEVENTH-STEMS+ followed by a number of
;;;; +CHORD-EXTENSION-NUMBERS+ ("maj" "9" → "maj9"; "" "13" → "13").
;;;;
;;;; Matching. Every choice is the longest match, no backtracking:
;;;;   - The root's accidental is the longest token, as in PARSE-PITCH: "Cbb5"
;;;;     is the C𝄫 power chord, "Cb5" the C♭ power chord, "C#5" the C♯ power
;;;;     chord. Altered tones right after the root need a group: C(b5), C(#5).
;;;;     "-" is never a flat after a letter (as in PARSE-PITCH): C- is C minor.
;;;;   - A modifier is first read as a token, then checked: a flat or sharp and
;;;;     the maximal run of ASCII digits after it; "+" with no digit after it;
;;;;     "add", an optional flat or sharp, and a digit run; "omit" or "no" and a
;;;;     digit run; "sus2", "sus4", "sus"; "alt". A token whose digits are not an
;;;;     allowed degree is an error at its first character: "C7b95" and "C7b6"
;;;;     at index 2, "Comit7" at 1. "C7b9#11" is b9 then #11. Inside a group a
;;;;     bare digit run is an item too ("(13)").
;;;;   - At the quality position the parser takes the longest of the quality
;;;;     words and the modifier tokens that match there, a tie going to the
;;;;     word: "Comit3" is C with omit3 (not the word "o"), "C+5" is C with +5
;;;;     and "C-5" C with b5, but "C+9" is the augmented ninth (word "+9", not
;;;;     #9), "C-9" the minor ninth and "C-6" the minor sixth. "Cmadd9" is "m"
;;;;     then "add9".
;;;;   - Modifiers repeat while a token matches; then an optional group, an
;;;;     optional "/" bass, trailing space and the end. "6/9" is a word, so
;;;;     C6/9/E is the 6/9 chord over E. No space is allowed inside the symbol.
;;;;
;;;; Unknown qualities. When at the quality position nothing but the empty word
;;;; matches (no other word, no modifier token, no "(" or "/") and the
;;;; character there is an alpha, the quality is UNKNOWN: the maximal run of alpha
;;;; characters and ASCII digits there ("Cdom7(b9)" → "dom7"). PARSE-CHORD-SYMBOL
;;;; then signals UNKNOWN-CHORD-QUALITY with WARN (TEXT = the run), inside a
;;;; USE-VALUE restart whose value is a quality keyword of +CHORD-QUALITIES+
;;;; (anything else: TYPE-ERROR). If the warning is not handled, or muffled,
;;;; the quality is :MAJOR. Parsing goes on after the run, and the modifiers
;;;; that follow are checked against the quality in use. "Cmajor" is not
;;;; unknown: the word "maj" matches, and "or" is an error at index 4.
;;;;
;;;; Reading: the value. ROOT and BASS are the spelled letter + accidental.
;;;; The word's row gives QUALITY, EXTENSIONS and ADDED; a seventh word gives
;;;; its stem's quality and the number's extensions (7 none, 9 (9), 11 (9 11),
;;;; 13 (9 11 13)), so C13 lists (9 11 13). Then each item, in text order:
;;;;   alteration       (degree . -1) or (degree . 1) in ALTERATIONS.
;;;;   raised-fifth     (5 . 1) in ALTERATIONS.
;;;;   addition         (degree . alter) in ADDED, alter -1, 0 or 1 from the sign;
;;;;                    but the four tension pairs (9 . -1) (9 . 1) (11 . 1)
;;;;                    (13 . -1) go to ALTERATIONS: Cadd#11 is C(#11).
;;;;   omission         the degree in OMITTED.
;;;;   suspension       SUSPENSION 2 or 4.
;;;;   "alt"            the alterations of +ALTERED-DOMINANT+ (b9 #9 #11 b13) and
;;;;                    OMITTED 5: C7alt is C E Bb Db D# F# Ab.
;;;; Each item must keep these rules, checked as it is read:
;;;;   R1  one suspension at most, only on a quality with a major third
;;;;       (+SUSPENDABLE-QUALITIES+), with the 3 not omitted and its degree (2
;;;;       or 4) not added: Cm7sus4, Comit3sus4 and Cadd4sus4 are errors.
;;;;   R2  an alteration of 5 needs a quality with a perfect fifth
;;;;       (+PERFECT-FIFTH-QUALITIES+): C+(b5) and Cdim(#5) are errors.
;;;;   R3  a (degree . alter) pair at most once in ALTERATIONS; b5 and #5, b9 and
;;;;       #9 may both appear (C7(b9,#9)).
;;;;   R4  an added degree is not already a degree of the chord: the quality's
;;;;       (the interval numbers of its row: 3 5 7, or 3 5 6), the extensions,
;;;;       the suspension's, an altered or an added one. C9(add9), C6add6,
;;;;       Csus4(add4) and C7(b9,add9) are errors; an alteration of an added
;;;;       degree too (C7(add9,b9)).
;;;;   R5  an omitted degree is a natural tone of the chord: 3 of a quality
;;;;       with a third and no suspension, 5 of a quality with a fifth, 9 or 11
;;;;       of the EXTENSIONS; it is not altered, and not omitted twice. An
;;;;       alteration of an omitted degree is an error too. C(omit7),
;;;;       Csus4(omit3), C9(omit11), C7(b5,omit5) are errors.
;;;;   R6  "alt" needs the quality :DOMINANT-7 with no EXTENSIONS, once; its
;;;;       tones obey R3 and R5 like any others (C7b9alt is an error).
;;;; After the body, the fold: when ALTERATIONS holds exactly one alteration of
;;;; 5 and +FIFTH-ALTERATION-FOLDS+ has a row for the quality and that pair, the
;;;; quality becomes the row's and the alteration is dropped. C7#5 = C+7,
;;;; Cm7b5 = Cø7, Cm(b5) = the diminished triad (in every dialect),
;;;; Cmaj7(#5) = C+M7, C(#5) = C+. C7(b5) and C7(b5,#5) do not fold.
;;;; ALTERATIONS and ADDED are sorted by degree, then alter; OMITTED ascending.
;;;; TEXT is STRING as given (untrimmed) and DIALECT the dialect. N.C. is
;;;; (make-chord-symbol :no-chord-p t :text string :dialect dialect).
;;;; C7(9) and C9 realise the same tones but are different values (dominant
;;;; plus an added ninth versus the dominant-ninth kind), as in MusicXML.
;;;;
;;;; Errors. Anything outside the grammar, or an item that breaks R1-R6,
;;;; signals CHORD-SYMBOL-PARSE-ERROR with TEXT = STRING and
;;;;   POSITION  the index into STRING (leading space counted) of the first
;;;;             character the parser could not accept: where the root, a group
;;;;             item, ",", ")", the bass or the end was required, or where a
;;;;             token that breaks a rule begins; the length of STRING when the
;;;;             text runs out there. "H7" 0, "c7" 0, "" 0, "   " 3, "C7(b9" 5,
;;;;             "C/" 2, "C/E7" 3, "Cmajor" 4, "C7b" 2, "C7b6" 2, "Cm7sus4" 3,
;;;;             "C7(b9,b9)" 6, "  H" 2, "C7 b9" 3 (space may only end the
;;;;             symbol), "C7(b9 )" 5, "N.C.x" 4.
;;;;   EXPECTED  a short phrase naming what the grammar or the rule allowed
;;;;             there ("a root letter A-G or N.C.", "\",\" or \")\"", "a bass
;;;;             letter A-G", "a suspension on a major-third quality", ...).
;;;;   REASON    NIL or a short explanation.
;;;; The error is signalled inside two restarts associated with it: USE-VALUE
;;;; (its value is returned by PARSE-CHORD-SYMBOL, unchecked) and
;;;; SKIP-CHORD-SYMBOL (PARSE-CHORD-SYMBOL returns NIL). Pitch syntax inside a
;;;; chord symbol never signals INVALID-PITCH. A DIALECT outside :CLASSICAL
;;;; :POP :JAZZ, or a STRING that is not a string, is a TYPE-ERROR.
;;;;
;;;; Dialects. :CLASSICAL, :POP (the default) and :JAZZ read the same grammar.
;;;; They differ only where a word has DIALECTS: "dim", "o" and "°" are the
;;;; diminished triad in :CLASSICAL and the diminished seventh in :POP and
;;;; :JAZZ ("Cdim7", "Co7", "C°7" are the diminished seventh everywhere). The
;;;; other conventions hold in every dialect: "-" minor, "Δ" major seventh,
;;;; "ø" half-diminished seventh (= m7♭5), "+" augmented, "7alt". Printing is
;;;; where the dialects differ most (+CHORD-PRINT-WORDS+).
;;;;
;;;; Well-formed values: what PARSE-CHORD-SYMBOL returns. PRINT-CHORD-SYMBOL,
;;;; CHORD-TONES, CHORD-ESSENTIAL-TONES and TRANSPOSE-CHORD-SYMBOL signal
;;;; MUSIC-THEORY-ERROR (TEXT NIL, with a REASON) for any other CHORD-SYMBOL.
;;;;   W1  N.C.: NO-CHORD-P true; ROOT, QUALITY, SUSPENSION and BASS NIL; the
;;;;       lists empty.
;;;;   W2  otherwise ROOT is set and QUALITY is a keyword of +CHORD-QUALITIES+.
;;;;   W3  EXTENSIONS is (), (9), (9 11) or (9 11 13); not () only for the
;;;;       eight seventh qualities.
;;;;   W4  ALTERATIONS pairs are of +CHORD-ALTERATIONS+; ADDED pairs have a
;;;;       degree of 2 4 6 9 11 13 and an alter of -1 0 1 and are not one of the
;;;;       four tension pairs; OMITTED degrees are of 3 5 9 11; all three are
;;;;       sorted and free of repeats, and together they keep R1-R5.
;;;;   W5  no single fifth alteration that the fold would fold.
;;;; TEXT and DIALECT are not checked, so CHORD-FOR's values are well-formed.
;;;;
;;;; Printing. PRINT-CHORD-SYMBOL chord &key dialect (accidentals :ascii):
;;;;   "N.C." for N.C.; otherwise  root word [ suspension ] [ group ] [ "/" bass ].
;;;;   DIALECT   defaults to the chord's DIALECT, else :POP.
;;;;   unfold    a cell (quality (5 . alter)) of +CHORD-PRINT-WORDS+ prints the
;;;;             chord as that quality plus that fifth alteration: :POP prints the
;;;;             diminished triad "Cm(b5)" and Cø7 "Cm7(b5)", :JAZZ "C-(b5)".
;;;;   specials  the first row of +CHORD-PRINT-SPECIALS+ for the dialect whose
;;;;             quality and extensions are the chord's and whose alterations,
;;;;             added and omitted tones are all among the chord's: its word is
;;;;             printed, and those tones leave the group (C6/9, C-6/9, :JAZZ
;;;;             C7alt).
;;;;   word      the dialect's cell of +CHORD-PRINT-WORDS+; for a seventh quality
;;;;             the cell is a stem and the number follows it: 7, or the last
;;;;             extension (Cm9, CΔ13, Cø11).
;;;;   suspension "sus2" or "sus4".
;;;;   group     when altered, added or omitted tones remain: "(", the
;;;;             alterations (flat or sharp, then the degree), the added tones
;;;;             ("add", an accidental if any, the degree), the omitted degrees
;;;;             ("omit" and the degree), in that order and each sorted, joined
;;;;             by ",", then ")". Every alteration prints in the group: C7(b9),
;;;;             C13(#11), C(b5), C5(add#4,addb6,omit5).
;;;;   ACCIDENTALS :ASCII ("b" "#", and PITCH-CLASS-STRING's "bb" "##") or :UNICODE
;;;;             ("♭" "♯" "𝄫" "𝄪"), else TYPE-ERROR. It spells the root, the
;;;;             bass and the group's accidentals only; the dialect's words are
;;;;             fixed, so :JAZZ prints Δ ø ° in both styles.
;;;; Properties, for every well-formed chord C, dialect D and style A:
;;;;   (parse-chord-symbol (print-chord-symbol c :dialect d :accidentals a) :dialect d)
;;;;   is equal to C in every slot but TEXT and DIALECT (which is D); and
;;;;   printing that value again gives the same text.

(in-package #:music-theory)

;;; Reading -------------------------------------------------------------------

(defparameter +chord-quality-words+
  '(;; triads
    ("" :major) ("M" :major) ("maj" :major) ("Maj" :major)
    ("m" :minor) ("min" :minor) ("mi" :minor) ("-" :minor)
    ("aug" :augmented) ("+" :augmented)
    ("dim" :diminished :dialects (:classical))
    ("o" :diminished :dialects (:classical))
    ("°" :diminished :dialects (:classical))
    ("dim" :diminished-7 :dialects (:pop :jazz))
    ("o" :diminished-7 :dialects (:pop :jazz))
    ("°" :diminished-7 :dialects (:pop :jazz))
    ;; sixths and the power chord
    ("6" :major-6) ("M6" :major-6) ("maj6" :major-6)
    ("m6" :minor-6) ("min6" :minor-6) ("mi6" :minor-6) ("-6" :minor-6)
    ("6/9" :major-6 :added ((9 . 0))) ("69" :major-6 :added ((9 . 0)))
    ("m6/9" :minor-6 :added ((9 . 0))) ("m69" :minor-6 :added ((9 . 0)))
    ("-6/9" :minor-6 :added ((9 . 0))) ("-69" :minor-6 :added ((9 . 0)))
    ("5" :power)
    ;; sevenths named without a number
    ("Δ" :major-7) ("△" :major-7) ("^" :major-7)
    ("ø" :half-diminished-7) ("Ø" :half-diminished-7)
    ("-Δ" :minor-major-7) ("mΔ" :minor-major-7)
    ("+Δ" :augmented-major-7)
    ;; minor-major sevenths with the number inside parentheses
    ("m(maj7)" :minor-major-7) ("m(maj9)" :minor-major-7 :extensions (9))
    ("m(maj11)" :minor-major-7 :extensions (9 11))
    ("m(maj13)" :minor-major-7 :extensions (9 11 13)))
  "Quality words other than the seventh words: (word quality &key extensions
added dialects). DIALECTS NIL means every dialect. Within one dialect no word
has two rows, and no word is also a seventh word. Read by longest match. Data.")

(defparameter +chord-seventh-stems+
  '((:dominant-7        "")
    (:major-7           "maj" "Maj" "M" "Δ" "△" "^")
    (:minor-7           "m" "min" "mi" "-")
    (:minor-major-7     "mM" "mmaj" "mMaj" "minmaj" "mΔ" "-Δ" "-maj" "-M")
    (:half-diminished-7 "ø" "Ø")
    (:diminished-7      "dim" "o" "°")
    (:augmented-7       "+" "aug")
    (:augmented-major-7 "+M" "+maj" "augmaj" "+Δ"))
  "Per seventh quality, the stems a number of +CHORD-EXTENSION-NUMBERS+ follows
to make a seventh word in every dialect: \"maj7\", \"-9\", \"ø11\", \"°7\", \"13\".
Data.")

(defparameter +chord-extension-numbers+
  '(("7") ("9" 9) ("11" 9 11) ("13" 9 11 13))
  "(number . extensions): the number ending a seventh word and the EXTENSIONS it
gives. Also read by the printer: a seventh chord prints the number of its
EXTENSIONS. Data.")

(defparameter +chord-alterations+
  '((5 . -1) (5 . 1) (9 . -1) (9 . 1) (11 . 1) (13 . -1))
  "The six alterations a chord symbol writes (b5 #5 b9 #9 #11 b13), as
(degree . alter), in their sorted order. Data.")

(defparameter +altered-dominant+
  '((9 . -1) (9 . 1) (11 . 1) (13 . -1))
  "The alterations \"alt\" adds (b9 #9 #11 b13); it also omits the 5. Data.")

(defparameter +fifth-alteration-folds+
  '((:major (5 . 1) :augmented)
    (:minor (5 . -1) :diminished)
    (:dominant-7 (5 . 1) :augmented-7)
    (:major-7 (5 . 1) :augmented-major-7)
    (:minor-7 (5 . -1) :half-diminished-7))
  "(quality fifth-alteration quality'): a quality whose fifth, so altered, is
another quality of +CHORD-QUALITIES+. The parser folds a single such alteration
into the quality. Data.")

(defparameter +suspendable-qualities+
  '(:major :augmented :dominant-7 :major-7 :augmented-7 :augmented-major-7 :major-6)
  "Qualities with a major third, which a suspension may replace (rule R1). Data.")

(defparameter +perfect-fifth-qualities+
  '(:major :minor :dominant-7 :major-7 :minor-7 :minor-major-7 :major-6 :minor-6 :power)
  "Qualities with a perfect fifth, which an alteration of 5 may alter (rule R2). Data.")

(defparameter +no-chord-words+ '("N.C." "N.C" "NC")
  "The texts of N.C. The printer writes the first. Data.")

;;; Printing ------------------------------------------------------------------

(defparameter +chord-print-words+
  ;; quality            :classical :pop                 :jazz
  '((:major             ""         ""                   "")
    (:minor             "m"        "m"                  "-")
    (:diminished        "°"        (:minor (5 . -1))    (:minor (5 . -1)))
    (:augmented         "+"        "+"                  "+")
    (:dominant-7        ""         ""                   "")
    (:major-7           "M"        "maj"                "Δ")
    (:minor-7           "m"        "m"                  "-")
    (:minor-major-7     "mM"       "mmaj"               "-Δ")
    (:half-diminished-7 "ø"        (:minor-7 (5 . -1))  "ø")
    (:diminished-7      "°"        "dim"                "°")
    (:augmented-7       "+"        "+"                  "+")
    (:augmented-major-7 "+M"       "+maj"               "+Δ")
    (:major-6           "6"        "6"                  "6")
    (:minor-6           "m6"       "m6"                 "-6")
    (:power             "5"        "5"                  "5"))
  "Per quality, what each dialect prints: a word, for a seventh quality the
stem its number follows, or (quality alteration) to print the chord as that
quality with that fifth alteration (see the file header). Every printed word
reads back as the same quality in its dialect. Data.")

(defparameter +chord-print-dialects+ '(:classical :pop :jazz)
  "The dialects, in the column order of +CHORD-PRINT-WORDS+. Data.")

(defparameter +chord-print-specials+
  '(((:classical :pop :jazz) :major-6 () "6/9" () ((9 . 0)) ())
    ((:classical :pop) :minor-6 () "m6/9" () ((9 . 0)) ())
    ((:jazz) :minor-6 () "-6/9" () ((9 . 0)) ())
    ((:jazz) :dominant-7 () "7alt" ((9 . -1) (9 . 1) (11 . 1) (13 . -1)) () (5)))
  "Words that print a quality together with some of its tones: (dialects
quality extensions word alterations added omitted). Data.")

;;; MusicXML ------------------------------------------------------------------

(defparameter +musicxml-kinds+
  '(("major" "C") ("minor" "Cm") ("augmented" "C+") ("diminished" "Cm(b5)")
    ("dominant" "C7") ("major-seventh" "Cmaj7") ("minor-seventh" "Cm7")
    ("diminished-seventh" "Cdim7") ("augmented-seventh" "C+7")
    ("half-diminished" "Cm7(b5)") ("major-minor" "Cmmaj7")
    ("major-sixth" "C6") ("minor-sixth" "Cm6")
    ("dominant-ninth" "C9") ("major-ninth" "Cmaj9") ("minor-ninth" "Cm9")
    ("dominant-11th" "C11") ("major-11th" "Cmaj11") ("minor-11th" "Cm11")
    ("dominant-13th" "C13") ("major-13th" "Cmaj13") ("minor-13th" "Cm13")
    ("suspended-second" "Csus2") ("suspended-fourth" "Csus4")
    ("Neapolitan" "C")
    ("Italian" "C5(add#4,addb6,omit5)")
    ("French" "C5(add2,add#4,addb6,omit5)")
    ("German" "Cm(add#4,addb6,omit5)")
    ("pedal" "C5(omit5)") ("power" "C5")
    ("Tristan" "C5(#9,add#4,add#6,omit5)")
    ("other" nil) ("none" "N.C."))
  "Every MusicXML 4.0 <kind> value and the canonical :POP symbol, on the root
C, that realises it (other roots: TRANSPOSE-CHORD-SYMBOL). The kinds of
+CHORD-QUALITIES+ are their quality; ninth to thirteenth kinds a seventh with
EXTENSIONS; suspended kinds a SUSPENSION. Functional kinds, which MusicXML
gives no intervals: Neapolitan is the major triad on its own root (the bII of
the key); Italian, French and German follow music21's convention, the root
being the key's tonic (C F# Ab is the Italian sixth of C minor); Tristan is A4,
A6 and A9 above the root; pedal is the root alone. \"other\" (a harmony made of
<degree> additions only) has no symbol: NIL. \"none\" is N.C. Data.")

;;; Functions -----------------------------------------------------------------

(defun parse-chord-symbol (string &key (dialect :pop))
  "Parse STRING (see the file header) into a CHORD-SYMBOL read in DIALECT
(:CLASSICAL, :POP or :JAZZ)."
  (declare (ignorable string dialect))
  (%mt3-pending 'parse-chord-symbol))

(defun print-chord-symbol (chord &key dialect (accidentals :ascii))
  "Canonical text of CHORD in DIALECT (default: CHORD's, else :POP); ACCIDENTALS
is :ASCII or :UNICODE."
  (declare (ignorable chord dialect accidentals))
  (%mt3-pending 'print-chord-symbol))
