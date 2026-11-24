;;;; MT3 chord symbols: realisation, essential-tone priorities, transposition.
;;;;
;;;; Every function here takes a well-formed CHORD-SYMBOL (rules W1-W5 in
;;;; src/chord-symbol.lisp) and signals MUSIC-THEORY-ERROR (TEXT NIL, with a
;;;; REASON) for any other.
;;;;
;;;; CHORD-TONES chord → the chord's tones as (degree . PITCH-CLASS-NAME) pairs,
;;;; ascending by degree, then by alter (b9 before #9):
;;;;   C7 → ((1 . C) (3 . E) (5 . G) (7 . Bb)).
;;;;   1            the root.
;;;;   quality      each interval of the quality's +CHORD-QUALITIES+ row above the
;;;;                root, at the degree that is its interval number: M3 → 3,
;;;;                d5 → 5, M6 → 6, d7 → 7. C°7 is C Eb Gb Bbb, C6 C E G A.
;;;;   EXTENSIONS   9, 11, 13 at M9, P11, M13 above the root, whatever the
;;;;                quality: Cm9 and C°9 have D; C13 is C E G Bb D F A (the 11 is
;;;;                a chord tone, as in MusicXML's dominant-13th; the priorities
;;;;                leave it out).
;;;;   SUSPENSION   2 or 4 replaces the 3 by M2 or P4: C7sus4 is C F G Bb.
;;;;   ALTERATIONS  (d . a) replaces the tone of degree d, if the chord has one,
;;;;                by d's natural interval moved by A semitones, else adds it:
;;;;                C13(b9) has Db and no D, C7(b9) adds Db, C7(b5) is C E Gb Bb.
;;;;                b5 is d5, #5 A5, b9 m9, #9 A9, #11 A11, b13 m13 above the root.
;;;;   ADDED        (d . a) adds d's natural interval moved by A semitones:
;;;;                Cadd9 adds D, C5(add#4,addb6,omit5) is C F# Ab.
;;;;   OMITTED      degrees removed: C7(omit3) is C G Bb, C7alt has no 5.
;;;; The natural intervals of the degrees are +CHORD-DEGREE-INTERVALS+. Spelling
;;;; is exact, by line-of-fifths arithmetic as in TRANSPOSE-PITCH: E7#9 has
;;;; F##, Bb7b9 Cb, Ab°7 Gbb. A tone needing more than two accidentals signals
;;;; INVALID-PITCH (E## major: G###). The bass is a tone only when it is a chord
;;;; tone anyway: C/F# has the tones C E G, and its F# is (CHORD-SYMBOL-BASS c).
;;;; N.C. has no tones: ().
;;;;
;;;; CHORD-ESSENTIAL-TONES chord n → at most N of CHORD-TONES' pairs, the most
;;;; important first, for consumers with fewer voices than chord tones. N is a
;;;; non-negative integer (else TYPE-ERROR); N.C. gives (). The order comes from
;;;; the chord's row in +CHORD-TONE-PRIORITIES+, keyed by QUALITY and
;;;; EXTENSIONS, a list of degrees with one :COLOUR marker, changed in this
;;;; order:
;;;;   P1  a SUSPENSION degree takes the 3's place, if the row lists 3.
;;;;   P2  OMITTED degrees are removed.
;;;;   P3  every degree that is altered loses its natural entry (5 in C7(b5),
;;;;       9 in C13(b9)).
;;;;   P4  :COLOUR becomes the altered tones (ascending by degree, then alter),
;;;;       then the added tones (likewise).
;;;; Each remaining degree stands for the chord tone of that degree; the result
;;;; is the first N. The rows follow one principle, written out as data:
;;;;   With a seventh or a sixth: the third and the seventh (or sixth); the top
;;;;   extension; a fifth the quality alters (ø, °7, +7, +M7); :COLOUR; the root;
;;;;   the lower extensions, ascending; a perfect fifth last. In an eleventh
;;;;   chord with a major third the 11 takes the third's place and the 3 is left
;;;;   out; in a thirteenth chord with a major third the 11 is left out.
;;;;   Triads and the power chord: the root, the third, a fifth the quality
;;;;   alters, :COLOUR, a perfect fifth last.
;;;; So the dominant thirteenth gives 3, 7, 13, then the root, 9 and 5 (no 11):
;;;; C13 with n 4 is ((3 . E) (7 . Bb) (13 . A) (1 . C)); C7alt is 3 7 b9 #9 #11
;;;; b13 1; C13(#11) is 3 7 13 #11 1 9 5; C7sus4 is 4 7 1 5; Cadd9 is 1 3 9 5.
;;;;
;;;; TRANSPOSE-CHORD-SYMBOL chord interval-or-keys → a new CHORD-SYMBOL whose
;;;; ROOT and BASS move on the line of fifths; every other slot is kept, but
;;;; TEXT is NIL. INTERVAL-OR-KEYS is
;;;;   an INTERVAL  the shift is how far it moves a pitch on the line of fifths,
;;;;                octaves ignored (P5 +1, M2 +2, -M2 -2, m2 -5, A1 +7, d2 -12,
;;;;                P8 and P12 as P1 and P5): G7/B up m2 is Ab7/C, up A1
;;;;                G#7/B#, down M2 (-M2) F7/A.
;;;;   (from to)    a list of two KEYs: the shift is (pitch-fifths to-tonic) -
;;;;                (pitch-fifths from-tonic), the modes ignored. G7/B from C
;;;;                major to Db major is Ab7/C, to C# major G#7/B#, to Cb major
;;;;                Gb7/Bb. The spelling follows the target key's tonic.
;;;; Anything else is a TYPE-ERROR. A root or bass that would need more than two
;;;; accidentals signals INVALID-PITCH; the other tones are relative to the root,
;;;; so they are checked only by CHORD-TONES. N.C. gives N.C. (TEXT NIL, DIALECT
;;;; kept). Transposing by an interval and then by its REVERSE-INTERVAL gives
;;;; the chord back (TEXT aside).

(in-package #:music-theory)

(defparameter +chord-degree-intervals+
  '((2 . "M2") (4 . "P4") (5 . "P5") (6 . "M6") (9 . "M9") (11 . "P11") (13 . "M13"))
  "The natural interval above the root of each degree that a suspension, an
extension, an alteration or an added tone names. Data.")

(defparameter +chord-tone-priorities+
  '(((:major) 1 3 :colour 5)
    ((:minor) 1 3 :colour 5)
    ((:diminished) 1 3 5 :colour)
    ((:augmented) 1 3 5 :colour)
    ((:major-6) 3 6 :colour 1 5)
    ((:minor-6) 3 6 :colour 1 5)
    ((:power) 1 :colour 5)
    ((:dominant-7) 3 7 :colour 1 5)
    ((:dominant-7 9) 3 7 9 :colour 1 5)
    ((:dominant-7 9 11) 11 7 :colour 1 9 5)
    ((:dominant-7 9 11 13) 3 7 13 :colour 1 9 5)
    ((:major-7) 3 7 :colour 1 5)
    ((:major-7 9) 3 7 9 :colour 1 5)
    ((:major-7 9 11) 11 7 :colour 1 9 5)
    ((:major-7 9 11 13) 3 7 13 :colour 1 9 5)
    ((:minor-7) 3 7 :colour 1 5)
    ((:minor-7 9) 3 7 9 :colour 1 5)
    ((:minor-7 9 11) 3 7 11 :colour 1 9 5)
    ((:minor-7 9 11 13) 3 7 13 :colour 1 9 11 5)
    ((:minor-major-7) 3 7 :colour 1 5)
    ((:minor-major-7 9) 3 7 9 :colour 1 5)
    ((:minor-major-7 9 11) 3 7 11 :colour 1 9 5)
    ((:minor-major-7 9 11 13) 3 7 13 :colour 1 9 11 5)
    ((:half-diminished-7) 3 7 5 :colour 1)
    ((:half-diminished-7 9) 3 7 9 5 :colour 1)
    ((:half-diminished-7 9 11) 3 7 11 5 :colour 1 9)
    ((:half-diminished-7 9 11 13) 3 7 13 5 :colour 1 9 11)
    ((:diminished-7) 3 7 5 :colour 1)
    ((:diminished-7 9) 3 7 9 5 :colour 1)
    ((:diminished-7 9 11) 3 7 11 5 :colour 1 9)
    ((:diminished-7 9 11 13) 3 7 13 5 :colour 1 9 11)
    ((:augmented-7) 3 7 5 :colour 1)
    ((:augmented-7 9) 3 7 9 5 :colour 1)
    ((:augmented-7 9 11) 11 7 5 :colour 1 9)
    ((:augmented-7 9 11 13) 3 7 13 5 :colour 1 9)
    ((:augmented-major-7) 3 7 5 :colour 1)
    ((:augmented-major-7 9) 3 7 9 5 :colour 1)
    ((:augmented-major-7 9 11) 11 7 5 :colour 1 9)
    ((:augmented-major-7 9 11 13) 3 7 13 5 :colour 1 9))
  "Essential-tone priority, one row per quality and extensions: ((quality .
extensions) . degrees), most important first, with :COLOUR where the altered and
added tones go (see the file header). Data.")

;;; Derived tables ------------------------------------------------------------

(defparameter +chord-degree-fifths+
  (loop for (degree . name) in +chord-degree-intervals+
        collect (cons degree (%interval-fifths (parse-interval name))))
  "Per degree of +CHORD-DEGREE-INTERVALS+, the line-of-fifths offset of its natural
interval above the root: 2 → 2, 4 → -1, 5 → 1, 6 → 3, 9 → 2, 11 → -1, 13 → 3.
Derived at load time.")

(defparameter +chord-quality-tones+
  (loop for (quality . offsets) in +quality-tone-fifths+
        collect (cons quality (mapcar #'cons (cdr (assoc quality +chord-quality-degrees+))
                                      offsets)))
  "Per quality, its tones above the root as (degree . fifths offset): M3 is (3 . 4),
d7 (7 . -9). Derived at load time from +QUALITY-TONE-FIFTHS+ (src/roman.lisp) and
+CHORD-QUALITY-DEGREES+.")

;;; Kernel --------------------------------------------------------------------

(defun %interval-shift (interval)
  "How far INTERVAL moves a pitch on the line of fifths, octaves ignored. An interval
of S steps and T semitones is D fifths and K octaves, S = 4D + 7K and T = 7D + 12K, so
D = 7T - 12S (P5 1, M2 2, m2 -5, A1 7, d2 -12, P8 0, P12 1). Equal to
%INTERVAL-FIFTHS, but never spells, so no interval overflows."
  (- (* 7 (interval-semitones interval)) (* 12 (interval-steps interval))))

(defun %degree-offset (degree)
  "The fifths offset of DEGREE's natural interval (+CHORD-DEGREE-FIFTHS+)."
  (cdr (assoc degree +chord-degree-fifths+)))

(defun %tone< (a b)
  "Order of tone-plan entries: by degree, then by fifths offset, which is by alter
for two tones of one degree."
  (or (< (first a) (first b))
      (and (= (first a) (first b)) (< (second a) (second b)))))

(defun %tone-plan (chord)
  "The tones of a well-formed CHORD (not N.C.) as (degree fifths-offset source)
entries, SOURCE :NATURAL, :ALTERED or :ADDED, ascending by degree, then alter (file
header). Nothing is spelled."
  (let* ((suspension (chord-symbol-suspension chord))
         (alterations (chord-symbol-alterations chord))
         (omitted (chord-symbol-omitted chord))
         (natural (append (list (cons 1 0))
                          (loop for (degree . offset)
                                  in (cdr (assoc (chord-symbol-quality chord) +chord-quality-tones+))
                                collect (if (and suspension (= degree 3))
                                            (cons suspension (%degree-offset suspension))
                                            (cons degree offset)))
                          (loop for degree in (chord-symbol-extensions chord)
                                collect (cons degree (%degree-offset degree))))))
    (stable-sort
     (nconc (loop for (degree . offset) in natural
                  unless (or (assoc degree alterations) (member degree omitted))
                    collect (list degree offset :natural))
            (loop for (degree . alter) in alterations
                  collect (list degree (+ (%degree-offset degree) (* 7 alter)) :altered))
            (loop for (degree . alter) in (chord-symbol-added chord)
                  collect (list degree (+ (%degree-offset degree) (* 7 alter)) :added)))
     #'%tone<)))

(defun %spelled-plan (chord)
  "%TONE-PLAN of CHORD with each entry's PITCH-CLASS-NAME appended. FIFTHS-PITCH-CLASS
signals INVALID-PITCH for a tone beyond two accidentals."
  (let ((root (pitch-fifths (chord-symbol-root chord))))
    (mapcar (lambda (entry)
              (append entry (list (fifths-pitch-class (+ root (second entry))))))
            (%tone-plan chord))))

(defun %transposition-shift (interval-or-keys)
  "The line-of-fifths shift of an INTERVAL, or of a list of two KEYs (to-tonic minus
from-tonic, modes ignored). Anything else is a TYPE-ERROR."
  (cond ((interval-p interval-or-keys)
         (%interval-shift interval-or-keys))
        ((typep interval-or-keys '(cons key (cons key null)))
         (- (pitch-fifths (key-tonic (second interval-or-keys)))
            (pitch-fifths (key-tonic (first interval-or-keys)))))
        (t
         (error 'type-error :datum interval-or-keys
                            :expected-type '(or interval (cons key (cons key null)))))))

;;; Functions -----------------------------------------------------------------

(defun chord-tones (chord)
  "The tones of CHORD as (degree . PITCH-CLASS-NAME) pairs, ascending by degree,
then by alter (see the file header). INVALID-PITCH for a tone beyond two
accidentals; MUSIC-THEORY-ERROR for a CHORD that is not well formed."
  (%check-chord-symbol chord)
  (if (chord-symbol-no-chord-p chord)
      '()
      (loop for (degree nil nil class) in (%spelled-plan chord)
            collect (cons degree class))))

(defun chord-essential-tones (chord n)
  "At most N (degree . PITCH-CLASS-NAME) pairs of CHORD, most important first: its
row of +CHORD-TONE-PRIORITIES+ changed by P1-P4 (see the file header)."
  (check-type chord chord-symbol)
  (check-type n (integer 0 *))
  (%check-chord-symbol chord)
  (if (chord-symbol-no-chord-p chord)
      '()
      (let* ((plan (%spelled-plan chord))
             (suspension (chord-symbol-suspension chord))
             (alterations (chord-symbol-alterations chord))
             (omitted (chord-symbol-omitted chord))
             (row (cdr (assoc (cons (chord-symbol-quality chord) (chord-symbol-extensions chord))
                              +chord-tone-priorities+ :test #'equal)))
             ;; P1: a suspension takes the 3's place.
             (row (if (and suspension (member 3 row)) (substitute suspension 3 row) row))
             ;; P2: omitted degrees go; P3: so do the natural entries of altered ones.
             (row (remove-if (lambda (entry) (or (member entry omitted) (assoc entry alterations)))
                             row))
             (picked (loop for entry in row
                           append (flet ((tones (test) (remove-if-not test plan)))
                                    (if (eq entry :colour)
                                        ;; P4: the altered tones, then the added ones.
                                        (append (tones (lambda (tone) (eq :altered (third tone))))
                                                (tones (lambda (tone) (eq :added (third tone)))))
                                        ;; A degree stands for its natural tone.
                                        (tones (lambda (tone)
                                                 (and (eql entry (first tone))
                                                      (eq :natural (third tone))))))))))
        (loop for (degree nil nil class) in (subseq picked 0 (min n (length picked)))
              collect (cons degree class)))))

(defun transpose-chord-symbol (chord interval-or-keys)
  "CHORD with ROOT and BASS moved by an INTERVAL, or from the first to the
second of a list of two KEYs; TEXT is NIL (see the file header). INVALID-PITCH when
the root or bass would need more than two accidentals."
  (check-type chord chord-symbol)
  (let ((shift (%transposition-shift interval-or-keys)))
    (%check-chord-symbol chord)
    (flet ((move (class)
             (and class (fifths-pitch-class (+ (pitch-fifths class) shift)))))
      (if (chord-symbol-no-chord-p chord)
          (make-chord-symbol :no-chord-p t :dialect (chord-symbol-dialect chord))
          (make-chord-symbol :root (move (chord-symbol-root chord))
                             :quality (chord-symbol-quality chord)
                             :extensions (chord-symbol-extensions chord)
                             :alterations (chord-symbol-alterations chord)
                             :suspension (chord-symbol-suspension chord)
                             :added (chord-symbol-added chord)
                             :omitted (chord-symbol-omitted chord)
                             :bass (move (chord-symbol-bass chord))
                             :dialect (chord-symbol-dialect chord))))))
