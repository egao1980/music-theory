;;;; MT0 spelled pitches.
;;;;
;;;; Values are immutable structs (read-only slots, no SETF accessors), compared
;;;; with EQUALP and printed readably (#S(...)).
;;;;
;;;; LETTER is 0..6 for C D E F G A B. ALTER is -2..2 (bb b natural # ##).
;;;; OCTAVE is scientific: C4 = MIDI 60, and the octave belongs to the letter,
;;;; so B#3 is MIDI 60 and Cb4 is MIDI 59. OCTAVE is any integer, in values
;;;; and in text alike (0.5.1, music-theory#15): PARSE-PITCH reads every octave
;;;; PITCH-NAME prints ("C10", "B#-2", "G-12"). The MIDI numbers 0..127 are
;;;; the octaves -1..9 (C-1 to G9); a function that needs a MIDI number checks
;;;; that range itself (SPELL-MIDI's argument is an (INTEGER 0 127)), while
;;;; PITCH-MIDI and TRANSPOSE-PITCH work beyond it. SPELL-MIDI and
;;;; TRANSPOSE-PITCH can return such pitches: 0 in C# major is B#-2.
;;;; Why not the other direction of music-theory#15, a constructor limited to
;;;; -1..9: it changes no test row, but it makes errors of values the library
;;;; builds today (B#-2 above, G10 from TRANSPOSE-PITCH of G9 by P8), and
;;;; SPELL-MIDI would need a new candidate rule at MIDI 0 and 1. Widening the
;;;; parser changes only the two parse-pitch-rejects rows that tested the range
;;;; (C10, C-2 in tests/mt0-test.lisp), now parse-pitch-accepts rows.
;;;;
;;;; Text syntax, read by PARSE-PITCH (surrounding whitespace is trimmed):
;;;;   pitch      = letter accidental octave
;;;;   letter     = "A".."G" | "a".."g"
;;;;   accidental = "" | "#" | "##" | "x" | "b" | "bb"
;;;;              | "♯" | "♯♯" | "𝄪" | "♭" | "♭♭" | "𝄫"
;;;;   octave     = ["-"] digit+          ; any integer (0.5.1; was -1..9)
;;;; Anything else signals INVALID-PITCH with TEXT = the original string, inside
;;;; a USE-VALUE restart. "-" is never a flat: "B-1" is B in octave -1.
;;;; PARSE-PITCH-CLASS reads letter accidental with no octave.
;;;;
;;;; PITCH-NAME prints ASCII by default ("F#4", "Bbb3", "C##5"), so
;;;; (pitch-name (parse-pitch s)) = s for canonical ASCII input (no leading
;;;; zero, no "-0"). With :ACCIDENTALS :UNICODE it prints ♯ ♭ 𝄪 𝄫 ("F♯4",
;;;; "B𝄫3", "C𝄪5").
;;;; Round trip: for every SPELLED-PITCH p and either ACCIDENTALS style,
;;;;   (equalp (parse-pitch (pitch-name p :accidentals style)) p).

(in-package #:music-theory)

(defstruct (spelled-pitch (:constructor make-spelled-pitch))
  (letter 0 :type (integer 0 6) :read-only t)
  (alter 0 :type (integer -2 2) :read-only t)
  (octave 4 :type integer :read-only t))

(defstruct (pitch-class-name (:constructor make-pitch-class-name))
  (letter 0 :type (integer 0 6) :read-only t)
  (alter 0 :type (integer -2 2) :read-only t))

(defparameter +letter-names+ "CDEFGAB"
  "Letter index → name. Data, not a rule.")

(defparameter +letter-semitones+ #(0 2 4 5 7 9 11)
  "Semitones above C of each natural letter, in letter order.")

(defparameter +accidentals+
  '((-2 "bb" "𝄫" "♭♭")
    (-1 "b" "♭")
    (0 "" "")
    (1 "#" "♯")
    (2 "##" "𝄪" "x" "♯♯"))
  "Accidental facts, one row per ALTER: (alter ascii unicode . other-spellings).
The printers use the ASCII or Unicode column; the parsers accept every string in
a row. Data, read in both directions.")

(defparameter +accidental-tokens+
  (loop for (alter . spellings) in +accidentals+
        nconc (loop for token in (remove-duplicates spellings :test #'string=)
                    collect (cons token alter)))
  "(token . alter) for every accidental spelling in +ACCIDENTALS+. Scanned by
longest match, so the order carries no meaning.")

(defparameter +pitch-whitespace+
  '(#\Space #\Tab #\Newline #\Return #\Linefeed #\Page)
  "Characters PARSE-PITCH and PARSE-PITCH-CLASS trim from both ends.")

;;; Kernel --------------------------------------------------------------------

(defun %letter-alter (pitch-or-class)
  "LETTER and ALTER of a SPELLED-PITCH or PITCH-CLASS-NAME, as two values."
  (etypecase pitch-or-class
    (spelled-pitch
     (values (spelled-pitch-letter pitch-or-class) (spelled-pitch-alter pitch-or-class)))
    (pitch-class-name
     (values (pitch-class-name-letter pitch-or-class) (pitch-class-name-alter pitch-or-class)))))

(defun pitch-midi (pitch)
  "MIDI number of a SPELLED-PITCH: 12 * (octave + 1) + letter semitones + alter."
  (+ (* 12 (1+ (spelled-pitch-octave pitch)))
     (aref +letter-semitones+ (spelled-pitch-letter pitch))
     (spelled-pitch-alter pitch)))

(defun pitch-class (pitch)
  "Unspelled pitch class 0..11 of a SPELLED-PITCH or PITCH-CLASS-NAME (Cb → 11)."
  (multiple-value-bind (letter alter) (%letter-alter pitch)
    (mod (+ (aref +letter-semitones+ letter) alter) 12)))

(defun pitch-diatonic-index (pitch)
  "LETTER + 7 * OCTAVE: the staff position, ignoring accidentals (C4 → 28)."
  (+ (spelled-pitch-letter pitch) (* 7 (spelled-pitch-octave pitch))))

(defun pitch-spelling (pitch)
  "The PITCH-CLASS-NAME of a SPELLED-PITCH (its letter and alter)."
  (make-pitch-class-name :letter (spelled-pitch-letter pitch)
                         :alter (spelled-pitch-alter pitch)))

(defun pitch-enharmonic-p (p q)
  "True when P and Q sound the same: equal MIDI numbers when both are
SPELLED-PITCHes, equal pitch classes otherwise (two PITCH-CLASS-NAMEs, or one
of each). F#4 and Gb4 are enharmonic but not EQUALP."
  (if (and (spelled-pitch-p p) (spelled-pitch-p q))
      (= (pitch-midi p) (pitch-midi q))
      (= (pitch-class p) (pitch-class q))))

;;; Text ----------------------------------------------------------------------

(defun %parse-failure (type text reason reparse)
  "Signal the condition TYPE for TEXT, inside a USE-VALUE restart.
Returns the value given to USE-VALUE, unchecked. The interactive restart reads
a replacement string from *QUERY-IO* and parses it with REPARSE."
  (restart-case (error type :text text :reason reason)
    (use-value (value)
      :report (lambda (stream)
                (format stream "Supply a value to return instead of parsing ~S." text))
      :interactive (lambda ()
                     (format *query-io* "~&Text to parse instead: ")
                     (finish-output *query-io*)
                     (list (funcall reparse (read-line *query-io*))))
      value)))

(defun %letter-index (char)
  "Letter index 0..6 of CHAR (A..G or a..g), or NIL."
  (or (position char +letter-names+)
      (position char +letter-names+ :key #'char-downcase)))

(defun %ascii-digit-p (char)
  (char<= #\0 char #\9))

(defun %longest-token (alist string start)
  "The entry of ALIST whose car is the longest string found at START in STRING, or NIL."
  (let ((best nil))
    (dolist (entry alist best)
      (let* ((token (car entry))
             (end (+ start (length token))))
        (when (and (<= end (length string))
                   (string= token string :start2 start :end2 end)
                   (or (null best) (> (length token) (length (car best)))))
          (setf best entry))))))

(defun %scan-spelling (text fail)
  "Scan letter + accidental at the start of TEXT.
Returns LETTER, ALTER and the index after the accidental. FAIL never returns."
  (let ((letter (and (plusp (length text)) (%letter-index (char text 0)))))
    (unless letter
      (funcall fail (if (plusp (length text)) "unknown letter" "empty")))
    ;; "" is a token, so some entry always matches.
    (destructuring-bind (token . alter) (%longest-token +accidental-tokens+ text 1)
      (let* ((next (+ 1 (length token)))
             (more (%longest-token +accidental-tokens+ text next)))
        ;; Another accidental right after the longest one: three or more, or a
        ;; mix such as "#b" (music-theory#4).
        (when (plusp (length (car more)))
          (funcall fail "too many or mixed accidentals"))
        (values letter alter next)))))

(defun %scan-octave (text start fail)
  "Read [\"-\"] ASCII-digit+ from START to the end of TEXT: any integer (0.5.1).
FAIL never returns."
  (let* ((end (length text))
         (negative (and (< start end) (char= #\- (char text start))))
         (digits (if negative (1+ start) start))
         (stop (or (position-if-not #'%ascii-digit-p text :start digits) end)))
    (cond ((= digits stop) (funcall fail "missing octave"))
          ((< stop end) (funcall fail "trailing characters")))
    ;; Only validated ASCII digits reach PARSE-INTEGER.
    (let ((octave (parse-integer text :start digits :end stop)))
      (when negative (setf octave (- octave)))
      octave)))

(defun parse-pitch (string)
  "Parse STRING (see the file header) into a SPELLED-PITCH."
  (check-type string string)
  (flet ((fail (reason)
           (return-from parse-pitch
             (%parse-failure 'invalid-pitch string reason #'parse-pitch))))
    (let ((text (string-trim +pitch-whitespace+ string)))
      (multiple-value-bind (letter alter next) (%scan-spelling text #'fail)
        (make-spelled-pitch :letter letter :alter alter
                            :octave (%scan-octave text next #'fail))))))

(defun parse-pitch-class (string)
  "Parse letter + accidental (no octave) into a PITCH-CLASS-NAME."
  (check-type string string)
  (flet ((fail (reason)
           (return-from parse-pitch-class
             (%parse-failure 'invalid-pitch string reason #'parse-pitch-class))))
    (let ((text (string-trim +pitch-whitespace+ string)))
      (multiple-value-bind (letter alter next) (%scan-spelling text #'fail)
        (unless (= next (length text)) (fail "trailing characters"))
        (make-pitch-class-name :letter letter :alter alter)))))

(defun %accidental-text (alter accidentals)
  "Printed accidental for ALTER in the ACCIDENTALS style (:ASCII or :UNICODE)."
  (check-type accidentals (member :ascii :unicode))
  (let ((row (assoc alter +accidentals+)))
    (ecase accidentals
      (:ascii (second row))
      (:unicode (third row)))))

(defun pitch-name (pitch &key (accidentals :ascii))
  "Print PITCH as text. ACCIDENTALS is :ASCII (default) or :UNICODE."
  (format nil "~C~A~D"
          (char +letter-names+ (spelled-pitch-letter pitch))
          (%accidental-text (spelled-pitch-alter pitch) accidentals)
          (spelled-pitch-octave pitch)))

(defun pitch-class-string (pitch-class &key (accidentals :ascii))
  "Print a PITCH-CLASS-NAME (\"F#\", or \"F♯\" with :UNICODE)."
  (format nil "~C~A"
          (char +letter-names+ (pitch-class-name-letter pitch-class))
          (%accidental-text (pitch-class-name-alter pitch-class) accidentals)))
