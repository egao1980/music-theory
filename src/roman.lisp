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

;;; Derived tables, computed at load time from the data above. The scanner
;;; reads the token alists by longest match (%LONGEST-TOKEN), so their order
;;; carries no meaning.

(defparameter +roman-numeral-tokens+
  (loop for numeral across +roman-numerals+
        for degree from 1
        collect (list* numeral degree :upper)
        collect (list* (string-downcase numeral) degree :lower))
  "(text degree . case) for every numeral of +ROMAN-NUMERALS+ in both cases.")

(defparameter +roman-marker-tokens+
  (remove-duplicates (loop for (nil nil ascii unicode) in +roman-qualities+
                           collect (list ascii)
                           collect (list unicode))
                     :test #'equal)
  "(marker) for every marker of +ROMAN-QUALITIES+, ASCII and Unicode, \"\" included.")

(defparameter +roman-figure-tokens+
  (loop for (seventh-p inversion . spellings) in +roman-figures+
        nconc (loop for figure in spellings
                    collect (list* figure seventh-p inversion)))
  "(figure seventh-p . inversion) for every spelling of +ROMAN-FIGURES+, \"\" included.")

(defparameter +quality-tone-fifths+
  (loop for (quality nil intervals) in +chord-qualities+
        collect (cons quality (mapcar (lambda (name) (%interval-fifths (parse-interval name)))
                                      intervals)))
  "Per quality of +CHORD-QUALITIES+, the fifths offsets of its tones above the
root, third first. Derived at load time.")

;;; Kernel --------------------------------------------------------------------

(defun %roman-quality (case marker seventh-p)
  "The quality of +ROMAN-QUALITIES+ for a numeral CASE, a MARKER from either
column and SEVENTH-P, or NIL when there is none (\"IM\", \"Vo\")."
  (first (find-if (lambda (row)
                    (destructuring-bind (quality row-case ascii unicode row-seventh-p) row
                      (declare (ignore quality))
                      (and (eq case row-case)
                           (eq seventh-p row-seventh-p)
                           (or (string= marker ascii) (string= marker unicode)))))
                  +roman-qualities+)))

(defun %figure-row (seventh-p inversion)
  "The +ROMAN-FIGURES+ row for SEVENTH-P and INVERSION, or NIL (a triad in third
inversion)."
  (find-if (lambda (row) (and (eq seventh-p (first row)) (eql inversion (second row))))
           +roman-figures+))

(defun %malformed-roman (reason)
  "Signal INVALID-ROMAN-NUMERAL for a malformed ROMAN-NUMERAL value (TEXT NIL)."
  (error 'invalid-roman-numeral :reason reason))

(defun %check-target (target)
  "Signal INVALID-ROMAN-NUMERAL (TEXT NIL) unless TARGET is what the grammar's
target reads: an accidental and a numeral, with no marker, no figure and no
target of its own, i.e. a root-position major or minor triad."
  (check-type target roman-numeral)
  (let ((row (assoc (roman-numeral-quality target) +roman-qualities+)))
    (unless (and row (string= "" (third row)) (not (fifth row)))
      (%malformed-roman "a target is a major or minor triad"))
    (unless (zerop (roman-numeral-inversion target))
      (%malformed-roman "a target is in root position"))
    (when (roman-numeral-applied-to target)
      (%malformed-roman "a target has no target of its own"))))

(defun %check-roman (roman)
  "Signal INVALID-ROMAN-NUMERAL (TEXT NIL) unless ROMAN is well formed: its
quality has a row in +ROMAN-QUALITIES+, its inversion a figure in
+ROMAN-FIGURES+, and its target, if any, passes %CHECK-TARGET."
  (check-type roman roman-numeral)
  (let ((row (assoc (roman-numeral-quality roman) +roman-qualities+)))
    (unless row
      (%malformed-roman "quality outside +roman-qualities+"))
    (unless (%figure-row (fifth row) (roman-numeral-inversion roman))
      (%malformed-roman "a triad has no third inversion")))
  (let ((target (roman-numeral-applied-to roman)))
    (when target (%check-target target))))

(defun %default-root-fifths (key degree quality)
  "Fifths position of the default root of DEGREE for QUALITY in KEY: the
natural scale degree, raised a semitone in a minor key for the degrees of
+MINOR-RAISED-DEGREES+ when QUALITY is lowercase."
  (+ (%degree-fifths key degree :natural)
     (if (and (eq (key-mode key) :minor)
              (member degree +minor-raised-degrees+)
              (eq :lower (second (assoc quality +roman-qualities+))))
         7
         0)))

(defun %root-fifths (roman key)
  "Fifths position of ROMAN's root in KEY: the default root moved by ALTERATION."
  (+ (%default-root-fifths key (roman-numeral-degree roman) (roman-numeral-quality roman))
     (* 7 (roman-numeral-alteration roman))))

(defun %chord-tone-fifths (root quality)
  "Fifths positions of the tones of QUALITY on ROOT (a fifths position): root,
third, fifth [, seventh]. Unbounded integers; nothing is spelled."
  (cons root (mapcar (lambda (offset) (+ root offset))
                     (cdr (assoc quality +quality-tone-fifths+)))))

(defun %tonicized-key (target key)
  "The key TARGET tonicizes in KEY: its tonic is the ROOT of (CHORD-FOR target
key), its mode the target's quality (:MAJOR uppercase, :MINOR lowercase)."
  (make-key :tonic (chord-symbol-root (chord-for target key))
            :mode (roman-numeral-quality target)))

(defun %reading-key (roman key)
  "The key ROMAN is read in: KEY, or the key its target tonicizes."
  (let ((target (roman-numeral-applied-to roman)))
    (if target (%tonicized-key target key) key)))

(defun %check-chord (chord)
  "Signal MUSIC-THEORY-ERROR (TEXT NIL) unless CHORD is a triad or seventh chord
a Roman numeral can name (see ROMAN-FOR)."
  (check-type chord chord-symbol)
  (flet ((reject (reason) (error 'music-theory-error :reason reason)))
    (when (or (chord-symbol-no-chord-p chord) (null (chord-symbol-root chord)))
      (reject "N.C. has no Roman numeral"))
    (unless (assoc (chord-symbol-quality chord) +roman-qualities+)
      (reject "the quality has no Roman numeral"))
    (when (chord-symbol-extensions chord) (reject "a Roman numeral has no extensions"))
    (when (chord-symbol-alterations chord) (reject "a Roman numeral has no altered tones"))
    (when (chord-symbol-suspension chord) (reject "a Roman numeral has no suspension"))
    (when (chord-symbol-added chord) (reject "a Roman numeral has no added tones"))
    (when (chord-symbol-omitted chord) (reject "a Roman numeral has no omitted tones"))))

(defun %chord-inversion (chord)
  "0 for no BASS or the root, else the index of BASS among CHORD's tones (spelling
must match). MUSIC-THEORY-ERROR (TEXT NIL) when BASS is not a chord tone."
  (let ((bass (chord-symbol-bass chord)))
    (if (null bass)
        0
        (or (position (pitch-fifths bass)
                      (%chord-tone-fifths (pitch-fifths (chord-symbol-root chord))
                                          (chord-symbol-quality chord)))
            (error 'music-theory-error :reason "the bass is not a chord tone")))))

(defun %roman-text (roman accidentals)
  "Canonical text of ROMAN's own numeral, without its target: accidental,
numeral, marker and figure, in the ACCIDENTALS style."
  (destructuring-bind (case ascii unicode seventh-p)
      (rest (assoc (roman-numeral-quality roman) +roman-qualities+))
    (let ((numeral (aref +roman-numerals+ (1- (roman-numeral-degree roman)))))
      (concatenate 'string
                   (%accidental-text (roman-numeral-alteration roman) accidentals)
                   (if (eq case :lower) (string-downcase numeral) numeral)
                   (ecase accidentals (:ascii ascii) (:unicode unicode))
                   (third (%figure-row seventh-p (roman-numeral-inversion roman)))))))

;;; Text and chords -----------------------------------------------------------

(defun parse-roman (string)
  "Parse STRING (see the file header) into a ROMAN-NUMERAL."
  (check-type string string)
  (let* ((text (string-trim +pitch-whitespace+ string))
         (end (length text))
         (pos 0))
    (labels ((fail (reason)
               (return-from parse-roman
                 (%parse-failure 'invalid-roman-numeral string reason #'parse-roman)))
             (scan (alist)
               ;; The longest token of ALIST at POS, consumed; NIL when none matches.
               (let ((entry (%longest-token alist text pos)))
                 (when entry (incf pos (length (car entry))))
                 entry))
             (at (char)
               (and (< pos end) (char= char (char text pos))))
             (numeral ()
               ;; accidental numeral → (values alteration degree case)
               (let ((alteration (cdr (scan +accidental-tokens+)))
                     (entry (or (scan +roman-numeral-tokens+) (fail "expected a numeral"))))
                 (values alteration (second entry) (cddr entry))))
             (chord ()
               ;; → (values degree alteration quality inversion)
               (if (at #\N)
                   ;; "N" triad-figure is bII: degree 2, a flat, uppercase.
                   (destructuring-bind (seventh-p . inversion)
                       (progn (incf pos) (cdr (scan +roman-figure-tokens+)))
                     (when seventh-p (fail "the Neapolitan is a triad"))
                     (values 2 -1 (%roman-quality :upper "" nil) inversion))
                   (multiple-value-bind (alteration degree case) (numeral)
                     ;; "" is a marker and a figure, so both scans match.
                     (let ((marker (car (scan +roman-marker-tokens+))))
                       (destructuring-bind (seventh-p . inversion)
                           (cdr (scan +roman-figure-tokens+))
                         (values degree alteration
                                 (or (%roman-quality case marker seventh-p)
                                     (fail "no quality for this case, marker and figure"))
                                 inversion)))))))
      (when (zerop end) (fail "empty"))
      (multiple-value-bind (degree alteration quality inversion) (chord)
        (let ((target (when (at #\/)
                        (incf pos)
                        (multiple-value-bind (alteration degree case) (numeral)
                          (make-roman-numeral :degree degree :alteration alteration
                                              :quality (%roman-quality case "" nil))))))
          (unless (= pos end) (fail "trailing characters"))
          (make-roman-numeral :degree degree :alteration alteration :quality quality
                              :inversion inversion :applied-to target))))))

(defun roman-name (roman &key (accidentals :ascii))
  "Canonical text of ROMAN (\"V65/V\"); ACCIDENTALS is :ASCII or :UNICODE."
  (check-type accidentals (member :ascii :unicode))
  (%check-roman roman)
  (let ((target (roman-numeral-applied-to roman)))
    (format nil "~A~@[/~A~]"
            (%roman-text roman accidentals)
            (and target (%roman-text target accidentals)))))

(defun chord-for (roman key)
  "The CHORD-SYMBOL (ROOT, QUALITY, BASS) that ROMAN names in KEY."
  (%check-roman roman)
  (check-type key key)
  (let* ((quality (roman-numeral-quality roman))
         (inversion (roman-numeral-inversion roman))
         ;; Every tone is spelled, so a root-position chord with an unspellable
         ;; third (#III in C# major: G###) signals INVALID-PITCH too.
         (tones (mapcar #'fifths-pitch-class
                        (%chord-tone-fifths (%root-fifths roman (%reading-key roman key))
                                            quality))))
    (make-chord-symbol :root (first tones) :quality quality
                       :bass (and (plusp inversion) (nth inversion tones)))))

(defun roman-for (chord key &key applied-to)
  "The ROMAN-NUMERAL naming CHORD (a CHORD-SYMBOL) in KEY, read literally, or
as an applied chord of APPLIED-TO when that target is given."
  (when applied-to (%check-target applied-to))
  (%check-chord chord)
  (check-type key key)
  (let* ((home (if applied-to (%tonicized-key applied-to key) key))
         (root (chord-symbol-root chord))
         (quality (chord-symbol-quality chord))
         (degree (1+ (mod (- (pitch-class-name-letter root)
                             (pitch-class-name-letter (key-tonic home)))
                          7)))
         (alteration (%alter-difference (%default-root-fifths home degree quality)
                                        (pitch-fifths root)))
         (inversion (%chord-inversion chord)))
    ;; Checked before the constructor, whose slot type would signal TYPE-ERROR.
    (unless (assoc alteration +accidentals+)
      (error 'music-theory-error :reason "the root needs more than two accidentals"))
    (make-roman-numeral :degree degree :alteration alteration :quality quality
                        :inversion inversion :applied-to applied-to)))

(defparameter +diatonic-romans+
  (loop for (mode . texts) in +diatonic-numerals+
        collect (cons mode (mapcar #'parse-roman texts)))
  "+DIATONIC-NUMERALS+ parsed: per mode, its diatonic ROMAN-NUMERALs. Derived at
load time, after PARSE-ROMAN is defined.")

(defun roman-mixture-p (roman key)
  "True when ROMAN's chord in KEY is diatonic to the parallel key but not to KEY."
  ;; CHORD-FOR first: it validates ROMAN and spells the chord (INVALID-PITCH).
  (let* ((chord (chord-for roman key))
         (home (%reading-key roman key))
         (root (pitch-fifths (chord-symbol-root chord)))
         (quality (chord-symbol-quality chord)))
    (flet ((diatonic-p (mode)
             ;; Compared as (fifths position, quality): integers, so a chord of a
             ;; theoretical parallel key never needs spelling.
             (let ((in-mode (make-key :tonic (key-tonic home) :mode mode)))
               (some (lambda (numeral)
                       (and (eq quality (roman-numeral-quality numeral))
                            (= root (%root-fifths numeral in-mode))))
                     (cdr (assoc mode +diatonic-romans+))))))
      (and (not (diatonic-p (key-mode home)))
           (some (lambda (row)
                   (and (not (eq (car row) (key-mode home))) (diatonic-p (car row))))
                 +diatonic-romans+)
           t))))
