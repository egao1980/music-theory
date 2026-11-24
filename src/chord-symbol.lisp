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

;;; Derived tables ------------------------------------------------------------

(defparameter +chord-dialect-words+
  (loop for dialect in +chord-print-dialects+
        collect (cons dialect
                      (append
                       (loop for (word quality . plist) in +chord-quality-words+
                             for dialects = (getf plist :dialects)
                             when (or (null dialects) (member dialect dialects))
                               collect (list word quality (getf plist :extensions)
                                             (getf plist :added)))
                       (loop for (quality . stems) in +chord-seventh-stems+
                             nconc (loop for stem in stems
                                         nconc (loop for (number . extensions)
                                                       in +chord-extension-numbers+
                                                     collect (list (concatenate 'string stem number)
                                                                   quality extensions '())))))))
  "Per dialect, (word quality extensions added) for every quality word it reads (the
file header: the rows of +CHORD-QUALITY-WORDS+ for the dialect, then every seventh
stem with every number), scanned by %LONGEST-TOKEN. Derived at load time.")

(defparameter +chord-quality-degrees+
  (loop for (quality nil intervals) in +chord-qualities+
        collect (cons quality (mapcar (lambda (name) (interval-number (parse-interval name)))
                                      intervals)))
  "Per quality of +CHORD-QUALITIES+, the degrees of its tones above the root: (3 5 7),
(3 5 6), (5). The natural degrees of rules R4 and R5. Derived at load time.")

(defparameter +no-chord-tokens+ (mapcar #'list +no-chord-words+)
  "+NO-CHORD-WORDS+ as an alist for %LONGEST-TOKEN. Derived at load time.")

;;; Reading: tokens -----------------------------------------------------------
;;;
;;; One integer cursor moves forward over the original string. Every choice is
;;; one longest match among a few candidates chosen by the character at the
;;; cursor; a rejected token is an error, never a retry.

(defun %add-degree-p (degree)
  "True for an add-degree of the grammar: 2 4 6 9 11 13."
  (member degree '(2 4 6 9 11 13)))

(defun %omit-degree-p (degree)
  "True for an omit-degree of the grammar: 3 5 9 11."
  (member degree '(3 5 9 11)))

(defun %text-at (text string start)
  "The index after TEXT when STRING holds TEXT at START, else NIL."
  (let ((stop (+ start (length text))))
    (and (<= stop (length string))
         (string= text string :start2 start :end2 stop)
         stop)))

(defun %digit-end (string start)
  "The index after the maximal run of ASCII digits at START in STRING."
  (or (position-if-not #'%ascii-digit-p string :start start) (length string)))

(defun %sign-at (string index)
  "-1 for a flat (b ♭ -) or 1 for a sharp (# ♯ +) at INDEX in STRING, else NIL."
  (and (< index (length string))
       (let ((char (char string index)))
         (cond ((find char "b♭-") -1)
               ((find char "#♯+") 1)))))

(defun %scan-degree (string start end)
  "The degree that STRING[START,END) writes: one or two ASCII digits, no leading zero.
NIL otherwise, so a long digit run never becomes a bignum."
  (and (<= 1 (- end start) 2)
       (char/= #\0 (char string start))
       (parse-integer string :start start :end end)))

(defun %scan-modifier (string start)
  "The modifier token at START in STRING, or NIL. A token is (kind start end [arg
digits]): KIND :ALTERATION (ARG the sign), :RAISED-FIFTH, :ADDITION (ARG the sign or
0), :OMISSION, :SUSPENSION (ARG 2 or 4) or :ALT; DIGITS is where its digit run starts.
The token is read first; %TOKEN-ITEM checks its digits afterwards."
  (let ((sign (%sign-at string start))
        (stop nil))
    (cond (sign
           (let ((end (%digit-end string (1+ start))))
             (if (and (= end (1+ start)) (char= #\+ (char string start)))
                 (list :raised-fifth start end)
                 (list :alteration start end sign (1+ start)))))
          ((setf stop (%text-at "add" string start))
           (let* ((add-sign (%sign-at string stop))
                  (digits (if add-sign (1+ stop) stop)))
             (list :addition start (%digit-end string digits) (or add-sign 0) digits)))
          ((setf stop (or (%text-at "omit" string start) (%text-at "no" string start)))
           (list :omission start (%digit-end string stop) nil stop))
          ((setf stop (%text-at "sus2" string start)) (list :suspension start stop 2))
          ((setf stop (%text-at "sus4" string start)) (list :suspension start stop 4))
          ((setf stop (%text-at "sus" string start)) (list :suspension start stop 4))
          ((setf stop (%text-at "alt" string start)) (list :alt start stop)))))

(defun %scan-bare-degree (string start)
  "A group's bare digit run at START in STRING as an :ADD-DEGREE token, or NIL."
  (and (< start (length string))
       (%ascii-digit-p (char string start))
       (list :add-degree start (%digit-end string start) 0 start)))

(defun %token-item (string token)
  "The item TOKEN reads as, or NIL when its digits are not a degree its kind allows.
Items: (:SUS degree), (:ALTER (degree . alter)), (:ADD (degree . alter)), (:OMIT
degree), (:ALT). An addition of a tension pair is an alteration (Cadd#11 = C(#11))."
  (destructuring-bind (kind start end &optional arg digits) token
    (declare (ignore start))
    (let ((degree (and digits (%scan-degree string digits end))))
      (ecase kind
        (:alteration
         (let ((pair (and degree (cons degree arg))))
           (and pair (member pair +chord-alterations+ :test #'equal) (list :alter pair))))
        (:raised-fifth (list :alter (cons 5 1)))
        ((:addition :add-degree)
         (and degree (%add-degree-p degree)
              (let ((pair (cons degree arg)))
                (list (if (member pair +chord-alterations+ :test #'equal) :alter :add)
                      pair))))
        (:omission (and degree (%omit-degree-p degree) (list :omit degree)))
        (:suspension (list :sus arg))
        (:alt (list :alt))))))

(defun %token-expected (token)
  "EXPECTED for a TOKEN whose digits are not an allowed degree."
  (ecase (first token)
    (:alteration (if (minusp (fourth token)) "a flat 5, 9 or 13" "a sharp 5, 9 or 11"))
    (:addition "\"add\", an optional flat or sharp, and a degree 2, 4, 6, 9, 11 or 13")
    (:omission "\"omit\" or \"no\" and a degree 3, 5, 9 or 11")
    (:add-degree "an added degree 2, 4, 6, 9, 11 or 13")))

;;; Reading: the rules --------------------------------------------------------

(defstruct (%chord-draft (:constructor %make-chord-draft (quality extensions added))
                         (:conc-name %draft-) (:copier nil) (:predicate nil))
  "The items of a chord read, or replayed by %CHECK-CHORD-SYMBOL, so far. Internal
scratch of one call; it never escapes."
  quality extensions added (suspension nil) (alterations '()) (omitted '()))

(defun %admit-item (draft item)
  "Add ITEM to DRAFT when rules R1-R6 (file header) allow it, and return NIL.
Otherwise return the EXPECTED phrase and the rule's name as two values; the caller
signals, and DRAFT is not used again. The rules are read against DRAFT's QUALITY,
which is the quality before the fold. Each pairwise rule is checked from both sides,
so the set of items admitted does not depend on their order. This is the one place
that holds the rules."
  (let* ((quality (%draft-quality draft))
         (natural (cdr (assoc quality +chord-quality-degrees+)))
         (extensions (%draft-extensions draft))
         (suspension (%draft-suspension draft))
         (alterations (%draft-alterations draft))
         (added (%draft-added draft))
         (omitted (%draft-omitted draft)))
    (destructuring-bind (kind &optional arg) item
      (ecase kind
        (:sus
         (cond (suspension (values "one suspension at most" "R1"))
               ((not (member quality +suspendable-qualities+))
                (values "a suspension on a major-third quality" "R1"))
               ((member 3 omitted) (values "a suspension with the 3 not omitted" "R1"))
               ((assoc arg added) (values "a suspension of a degree that is not added" "R1"))
               (t (setf (%draft-suspension draft) arg) nil)))
        (:alter
         (let ((degree (car arg)))
           (cond ((and (= degree 5) (not (member quality +perfect-fifth-qualities+)))
                  (values "an alteration of 5 on a quality with a perfect fifth" "R2"))
                 ((member arg alterations :test #'equal)
                  (values "an alteration not already in the chord" "R3"))
                 ((assoc degree added)
                  (values "an alteration of a degree that is not added" "R4"))
                 ((member degree omitted)
                  (values "an alteration of a degree that is not omitted" "R5"))
                 (t (push arg (%draft-alterations draft)) nil))))
        (:add
         (let ((degree (car arg)))
           (if (or (member degree natural) (member degree extensions) (eql degree suspension)
                   (assoc degree alterations) (assoc degree added))
               (values "an added degree that is not already in the chord" "R4")
               (progn (push arg (%draft-added draft)) nil))))
        (:omit
         (cond ((member arg omitted) (values "a degree not already omitted" "R5"))
               ((assoc arg alterations) (values "an omitted degree that is not altered" "R5"))
               ((not (if (member arg '(9 11))
                         (member arg extensions)
                         (and (member arg natural) (not (and (= arg 3) suspension)))))
                (values "an omitted degree that is a natural tone of the chord" "R5"))
               (t (push arg (%draft-omitted draft)) nil)))
        (:alt
         (cond ((not (and (eq quality :dominant-7) (null extensions)))
                (values "\"alt\" on a dominant seventh with no extensions" "R6"))
               ((subsetp +altered-dominant+ alterations :test #'equal)
                (values "\"alt\" once" "R6"))
               (t
                ;; Its tones join like any others (R3, R5).
                (dolist (sub (append (mapcar (lambda (pair) (list :alter pair)) +altered-dominant+)
                                     (list (list :omit 5)))
                             nil)
                  (multiple-value-bind (expected rule) (%admit-item draft sub)
                    (when expected (return (values expected rule))))))))))))

(defun %pair< (a b)
  "Order of (degree . alter) pairs: by degree, then by alter."
  (or (< (car a) (car b))
      (and (= (car a) (car b)) (< (cdr a) (cdr b)))))

(defun %fold-row (quality alterations)
  "The +FIFTH-ALTERATION-FOLDS+ row that folds the single alteration of 5 in
ALTERATIONS into QUALITY, or NIL: no alteration of 5, two of them, or no row
(C7(b5), C7(b5,#5), C(b5))."
  (let ((fifths (remove 5 alterations :key #'car :test-not #'eql)))
    (and fifths (null (rest fifths))
         (find-if (lambda (row) (and (eq quality (first row)) (equal (first fifths) (second row))))
                  +fifth-alteration-folds+))))

(defun %draft-chord (draft root bass text dialect)
  "The CHORD-SYMBOL of a finished DRAFT: the fold, then ALTERATIONS and ADDED sorted
by degree and alter, OMITTED ascending. Every sort is on a fresh list, so table
literals are never changed."
  (let* ((quality (%draft-quality draft))
         (alterations (%draft-alterations draft))
         (row (%fold-row quality alterations)))
    (when row
      (setf quality (third row)
            alterations (remove (second row) alterations :test #'equal)))
    (make-chord-symbol :root root :quality quality :extensions (%draft-extensions draft)
                       :alterations (sort (copy-list alterations) #'%pair<)
                       :suspension (%draft-suspension draft)
                       :added (sort (copy-list (%draft-added draft)) #'%pair<)
                       :omitted (sort (copy-list (%draft-omitted draft)) #'<)
                       :bass bass :text text :dialect dialect)))

;;; Reading: conditions -------------------------------------------------------

(defun %chord-parse-failure (string dialect position expected &optional reason)
  "Signal CHORD-SYMBOL-PARSE-ERROR for STRING at POSITION, inside two restarts
associated with it: USE-VALUE (its value is returned, unchecked) and
SKIP-CHORD-SYMBOL (NIL is returned). The interactive USE-VALUE reads a replacement
text from *QUERY-IO* and parses it in DIALECT."
  (restart-case (error 'chord-symbol-parse-error :text string :position position
                                                 :expected expected :reason reason)
    (use-value (value)
      :report (lambda (stream)
                (format stream "Supply a value to return instead of parsing ~S." string))
      :interactive (lambda ()
                     (format *query-io* "~&Chord symbol to parse instead: ")
                     (finish-output *query-io*)
                     (list (parse-chord-symbol (read-line *query-io*) :dialect dialect)))
      value)
    (skip-chord-symbol ()
      :report (lambda (stream)
                (format stream "Skip ~S: PARSE-CHORD-SYMBOL returns NIL." string))
      nil)))

(defun %unknown-chord-quality (run)
  "Warn UNKNOWN-CHORD-QUALITY (TEXT = RUN) inside a USE-VALUE restart, and return
the quality to read with: USE-VALUE's (a keyword of +CHORD-QUALITIES+, else
TYPE-ERROR), or :MAJOR when the warning is not handled or is muffled."
  (or (restart-case (warn 'unknown-chord-quality :text run)
        (use-value (quality)
          :report (lambda (stream)
                    (format stream "Read ~S as a quality keyword of +CHORD-QUALITIES+." run))
          :interactive (lambda ()
                         (format *query-io* "~&Quality keyword: ")
                         (finish-output *query-io*)
                         (list (intern (string-upcase (read-line *query-io*)) :keyword)))
          (unless (assoc quality +chord-qualities+)
            (error 'type-error :datum quality
                               :expected-type `(member ,@(mapcar #'first +chord-qualities+))))
          quality))
      ;; WARN returns NIL when the warning is not handled, or is muffled.
      :major))

;;; Well-formed values --------------------------------------------------------

(defun %ranks-ascend-p (list rank)
  "True when LIST is a proper list whose elements all have an integer RANK (a
function returning NIL for an element outside the allowed set), strictly
ascending: sorted and free of repeats."
  (and (listp list)
       (null (cdr (last list)))
       (let ((ranks (mapcar rank list)))
         (and (every #'integerp ranks)
              (loop for (a b) on ranks while b always (< a b))))))

(defun %check-chord-symbol (chord)
  "Signal MUSIC-THEORY-ERROR (TEXT NIL, with a REASON) unless CHORD is a well-formed
CHORD-SYMBOL (W1-W5 in the file header); TYPE-ERROR for a non-CHORD-SYMBOL. R1-R5 are
checked by replaying CHORD's items through %ADMIT-ITEM, the parser's own rules, and
W5 with the parser's own %FOLD-ROW."
  (check-type chord chord-symbol)
  (flet ((reject (reason) (error 'music-theory-error :reason reason)))
    (let ((quality (chord-symbol-quality chord))
          (extensions (chord-symbol-extensions chord))
          (suspension (chord-symbol-suspension chord))
          (alterations (chord-symbol-alterations chord))
          (added (chord-symbol-added chord))
          (omitted (chord-symbol-omitted chord)))
      (cond
        ((chord-symbol-no-chord-p chord)                                      ; W1
         (when (or (chord-symbol-root chord) quality suspension (chord-symbol-bass chord)
                   extensions alterations added omitted)
           (reject "N.C. has no root, quality, bass or tones")))
        (t
         (unless (chord-symbol-root chord)                                    ; W2
           (reject "a chord has a root"))
         (unless (assoc quality +chord-qualities+)
           (reject "the quality is not one of +chord-qualities+"))
         (unless (member extensions '(() (9) (9 11) (9 11 13)) :test #'equal) ; W3
           (reject "extensions are (), (9), (9 11) or (9 11 13)"))
         (when (and extensions (not (assoc quality +chord-seventh-stems+)))
           (reject "only a seventh quality has extensions"))
         (unless (%ranks-ascend-p alterations                                 ; W4
                                  (lambda (pair) (position pair +chord-alterations+ :test #'equal)))
           (reject "alterations are sorted, distinct pairs of +chord-alterations+"))
         (unless (%ranks-ascend-p
                  added
                  (lambda (pair)
                    (and (consp pair) (integerp (car pair)) (%add-degree-p (car pair))
                         (member (cdr pair) '(-1 0 1))
                         (not (member pair +chord-alterations+ :test #'equal))
                         ;; Monotone in (degree, alter) for alters -1..1.
                         (+ (* 3 (car pair)) (cdr pair)))))
           (reject "added tones are sorted, distinct (degree . alter) pairs of 2 4 6 9 11 13, not tension pairs"))
         (unless (%ranks-ascend-p omitted (lambda (degree) (position degree '(3 5 9 11))))
           (reject "omitted degrees are sorted and distinct, of 3 5 9 11"))
         (let ((draft (%make-chord-draft quality extensions '())))            ; R1-R5
           (dolist (item (append (and suspension (list (list :sus suspension)))
                                 (mapcar (lambda (pair) (list :alter pair)) alterations)
                                 (mapcar (lambda (pair) (list :add pair)) added)
                                 (mapcar (lambda (degree) (list :omit degree)) omitted)))
             (multiple-value-bind (expected rule) (%admit-item draft item)
               (when expected
                 (reject (format nil "breaks rule ~A: expected ~A" rule expected))))))
         (when (%fold-row quality alterations)                                ; W5
           (reject "a single fifth alteration that folds into another quality")))))))

;;; Printing: helpers ---------------------------------------------------------

(defun %print-cell (quality dialect)
  "QUALITY's cell of +CHORD-PRINT-WORDS+ in DIALECT's column."
  (nth (1+ (position dialect +chord-print-dialects+)) (assoc quality +chord-print-words+)))

(defun %print-special (dialect quality extensions alterations added omitted)
  "The first +CHORD-PRINT-SPECIALS+ row for DIALECT whose quality and extensions are
QUALITY and EXTENSIONS and whose tones are all among ALTERATIONS, ADDED and OMITTED,
or NIL."
  (find-if (lambda (row)
             (destructuring-bind (dialects q e word alt add omit) row
               (declare (ignore word))
               (and (member dialect dialects) (eq q quality) (equal e extensions)
                    (subsetp alt alterations :test #'equal)
                    (subsetp add added :test #'equal)
                    (subsetp omit omitted))))
           +chord-print-specials+))

(defun %print-word (quality extensions dialect)
  "DIALECT's word for QUALITY: its cell, or for a seventh quality its stem followed by
the number of EXTENSIONS."
  (let ((cell (%print-cell quality dialect)))
    (if (assoc quality +chord-seventh-stems+)
        (concatenate 'string cell
                     (car (rassoc extensions +chord-extension-numbers+ :test #'equal)))
        cell)))

(defun %group-text (alterations added omitted accidentals)
  "The group: \"(\", the alterations, the added tones and the omitted degrees, joined
by \",\", then \")\"; \"\" when all three are empty."
  (let ((items (append (loop for (degree . alter) in alterations
                             collect (format nil "~A~D" (%accidental-text alter accidentals) degree))
                       (loop for (degree . alter) in added
                             collect (format nil "add~A~D" (%accidental-text alter accidentals) degree))
                       (loop for degree in omitted
                             collect (format nil "omit~D" degree)))))
    (if items (format nil "(~{~A~^,~})" items) "")))

;;; Functions -----------------------------------------------------------------

(defun parse-chord-symbol (string &key (dialect :pop))
  "Parse STRING (see the file header) into a CHORD-SYMBOL read in DIALECT
(:CLASSICAL, :POP or :JAZZ). Signals CHORD-SYMBOL-PARSE-ERROR (restarts USE-VALUE and
SKIP-CHORD-SYMBOL) for text outside the grammar or an item that breaks R1-R6, and
warns UNKNOWN-CHORD-QUALITY (restart USE-VALUE) for an unknown quality."
  (check-type string string)
  (check-type dialect (member :classical :pop :jazz))
  (let ((end (length string))
        (pos 0)
        (words (cdr (assoc dialect +chord-dialect-words+)))
        (draft nil))
    (labels ((fail (position expected &optional reason)
               (return-from parse-chord-symbol
                 (%chord-parse-failure string dialect position expected reason)))
             (at-p (char)
               (and (< pos end) (char= char (char string pos))))
             (skip-space ()
               (loop while (and (< pos end) (member (char string pos) +pitch-whitespace+))
                     do (incf pos)))
             (finish (expected)
               ;; { space } and the end: space may only end the symbol.
               (let ((start pos))
                 (skip-space)
                 (when (< pos end)
                   (fail pos (if (> pos start) "the end of the symbol after a space" expected)))))
             (spelling (expected)
               ;; An uppercase letter (not %LETTER-INDEX, which takes lowercase too) and
               ;; the longest accidental token; what follows is read as a modifier.
               (let ((letter (and (< pos end) (position (char string pos) +letter-names+))))
                 (unless letter (fail pos expected))
                 ;; "" is a token, so some entry always matches.
                 (destructuring-bind (token . alter)
                     (%longest-token +accidental-tokens+ string (1+ pos))
                   (incf pos (1+ (length token)))
                   (make-pitch-class-name :letter letter :alter alter))))
             (admit (token)
               ;; The token's digits, then R1-R6; both errors at the token's start.
               (let ((start (second token))
                     (item (%token-item string token)))
                 (unless item
                   (fail start (%token-expected token) "not an allowed degree"))
                 (multiple-value-bind (expected rule) (%admit-item draft item)
                   (when expected
                     (fail start expected (format nil "breaks rule ~A" rule))))
                 (setf pos (third token))))
             (read-quality ()
               ;; The longest of the dialect's words and the modifier token here, a
               ;; tie going to the word. A winning token is returned unconsumed, for
               ;; the modifier loop.
               (let* ((word (%longest-token words string pos)) ; the "" row always matches
                      (token (%scan-modifier string pos))
                      (token-wins (and token (> (third token) (+ pos (length (first word)))))))
                 (cond (token-wins
                        (setf draft (%make-chord-draft :major '() '())))
                       ((and (string= "" (first word)) (null token) (< pos end)
                             (alpha-char-p (char string pos))) ; so not "(", "/" or space
                        (let ((stop (or (position-if-not (lambda (c)
                                                           (or (alpha-char-p c) (%ascii-digit-p c)))
                                                         string :start pos)
                                        end)))
                          (setf draft (%make-chord-draft
                                       (%unknown-chord-quality (subseq string pos stop)) '() '())
                                pos stop)))
                       (t
                        (destructuring-bind (text quality extensions added) word
                          (setf draft (%make-chord-draft quality extensions added))
                          (incf pos (length text)))))
                 (and token-wins token)))
             (read-item ()
               ;; A group item, admitted; NIL when none starts here.
               (let ((token (or (%scan-modifier string pos) (%scan-bare-degree string pos))))
                 (when token
                   (admit token)
                   t)))
             (read-group ()
               ;; "(" item { [","] item } ")"
               (incf pos)
               (unless (read-item)
                 (fail pos "a group item: an alteration, add, omit, sus, alt or a degree"))
               (loop (cond ((at-p #\,)
                            (incf pos)
                            (unless (read-item) (fail pos "a group item after \",\"")))
                           ((at-p #\))
                            (incf pos)
                            (return t))
                           ((read-item))
                           (t (fail pos "\",\" or \")\""))))))
      (skip-space)
      (let ((no-chord (%longest-token +no-chord-tokens+ string pos)))
        (when no-chord
          (incf pos (length (car no-chord)))
          (finish "the end of the symbol after N.C.")
          (return-from parse-chord-symbol
            (make-chord-symbol :no-chord-p t :text string :dialect dialect))))
      (let ((root (spelling "a root letter A-G or N.C.")))
        (loop for token = (or (read-quality) (%scan-modifier string pos))
                then (%scan-modifier string pos)
              while token
              do (admit token))
        (let* ((grouped (and (at-p #\() (read-group)))
               (bass (and (at-p #\/)
                          (progn (incf pos) (spelling "a bass letter A-G")))))
          (finish (cond (bass "the end of the symbol")
                        (grouped "\"/\" and a bass letter, or the end of the symbol")
                        (t "a modifier, \"(\", \"/\" or the end of the symbol")))
          (%draft-chord draft root bass string dialect))))))

(defun print-chord-symbol (chord &key dialect (accidentals :ascii))
  "Canonical text of CHORD in DIALECT (default: CHORD's, else :POP); ACCIDENTALS
is :ASCII or :UNICODE (see the file header). MUSIC-THEORY-ERROR for a CHORD that is
not well formed."
  (check-type chord chord-symbol)
  (let ((dialect (or dialect (chord-symbol-dialect chord) :pop)))
    (check-type dialect (member :classical :pop :jazz))
    (check-type accidentals (member :ascii :unicode))
    (%check-chord-symbol chord)
    (if (chord-symbol-no-chord-p chord)
        (first +no-chord-words+)
        (let* ((cell (%print-cell (chord-symbol-quality chord) dialect))
               ;; Unfold: (quality (5 . alter)) prints as that quality and alteration.
               (quality (if (consp cell) (first cell) (chord-symbol-quality chord)))
               (alterations (if (consp cell)
                                (merge 'list (list (second cell))
                                       (copy-list (chord-symbol-alterations chord)) #'%pair<)
                                (chord-symbol-alterations chord)))
               (extensions (chord-symbol-extensions chord))
               (added (chord-symbol-added chord))
               (omitted (chord-symbol-omitted chord))
               (special (%print-special dialect quality extensions alterations added omitted))
               (word (if special (fourth special) (%print-word quality extensions dialect)))
               (bass (chord-symbol-bass chord)))
          (when special
            (destructuring-bind (dialects q e w alt add omit) special
              (declare (ignore dialects q e w))
              (setf alterations (remove-if (lambda (pair) (member pair alt :test #'equal)) alterations)
                    added (remove-if (lambda (pair) (member pair add :test #'equal)) added)
                    omitted (remove-if (lambda (degree) (member degree omit)) omitted))))
          (format nil "~A~A~@[sus~D~]~A~@[/~A~]"
                  (pitch-class-string (chord-symbol-root chord) :accidentals accidentals)
                  word
                  (chord-symbol-suspension chord)
                  (%group-text alterations added omitted accidentals)
                  (and bass (pitch-class-string bass :accidentals accidentals)))))))
