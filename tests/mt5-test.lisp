;;;; MT5 (0.6.0): key fit with a tuning offset (music-theory#22). The takes are
;;;; MT4's 50 melodies (tests/fixtures/mt4-melodies.sexp), in tune, shifted by
;;;; whole cents or semitones, as double-floats, detuned note by note with a
;;;; pinned generator (MAKE-DRAWS), or drifting. No new fixture: the header's
;;;; in-tune consequence ties FIT-KEY to DETECT-KEY, which reproduces music21.
;;;; The hand-written rows follow the rules in src/key-fit.lisp and
;;;; src/key-detect.lisp. Each was worked out by hand where the header's
;;;; consequences decide it. All of them, and the calibrated counts of the
;;;; robustness tests, were cross-checked against two independent reference
;;;; implementations of those rules, one in Lisp and one in exact Python
;;;; fractions (no mismatches).
;;;; Uses P (mt0), K, PC, CALL and SIGNALS-TYPE (mt2), MELODIES, MELODY, EV,
;;;; RANKING-NAMES and SPELLED-NAMES (mt4).

(in-package #:music-theory/tests)

;;; Takes ------------------------------------------------------------------------

(defun take (row &key (cents 0) (semitones 0) (weight :duration))
  "(pitch . weight) for every note of the mt4-melodies.sexp ROW: its MIDI number plus
SEMITONES and CENTS/100, exactly, weighted by its duration, or by 1 for :COUNT."
  (destructuring-bind (id key names durations midis) row
    (declare (ignore id key names))
    (mapcar (lambda (midi duration)
              (cons (+ midi semitones (/ cents 100)) (if (eq weight :count) 1 duration)))
            midis durations)))

(defun row-midis (row) (fifth row))

(defun in-tune-ranking (row &key (profiles :krumhansl-kessler) (weight :duration))
  "DETECT-KEY of the in-tune take of ROW: what the header says FIT-KEY's ranking is."
  (detect-key (pitch-class-histogram (take row :weight weight)) :profiles profiles))

(defun in-tune-key (row) (car (first (in-tune-ranking row))))

(defun same-ranking-p (a b)
  "Same keys (by KEY-NAME) in the same order with the same DOUBLE-FLOAT scores."
  (and (= (length a) (length b))
       (every (lambda (x y)
                (and (key-p (car x)) (string= (key-name (car x)) (key-name (car y)))
                     (typep (cdr x) 'double-float) (= (cdr x) (cdr y))))
              a b)))

(defun near-ranking-p (a b tolerance)
  "Same keys in the same order, scores within TOLERANCE."
  (and (= (length a) (length b))
       (every (lambda (x y)
                (and (string= (key-name (car x)) (key-name (car y)))
                     (< (abs (- (cdr x) (cdr y))) tolerance)))
              a b)))

(defun moved-key-name (key semitones)
  "KEY-NAME of the candidate SEMITONES above KEY, same mode."
  (key-name (nth (+ (* 2 (mod (+ (pitch-class (key-tonic key)) semitones) 12))
                    (if (eq (key-mode key) :major) 0 1))
                 music-theory::+detect-key-keys+)))

(defun fit-summary (fit)
  "(key-name offset) of a KEY-FIT, for messages."
  (and (key-fit-p fit) (list (key-name (key-fit-key fit)) (key-fit-offset fit))))

(defun make-draws (seed)
  "The Park-Miller minimal standard generator, x ← 16807·x mod (2³¹ - 1), from SEED:
a function of K giving the next integer in -K … K, (mod x (1+ 2K)) - K. Pinned and
portable, so every implementation draws the same detuning."
  (let ((x seed))
    (lambda (k)
      (setf x (mod (* 16807 x) 2147483647))
      (- (mod x (1+ (* 2 k))) k))))

(defun detuned-take (index)
  "The INDEXth MT4 melody (from 0) sung C cents sharp, C being the first draw in
-40 … 40 of (MAKE-DRAWS (1+ INDEX)), each note then detuned by the sum of three
more draws in -10 … 10 cents (σ ≈ 10.5, at most 30): the events, weighted by
duration, and C, as two values."
  (let* ((row (nth index (melodies)))
         (draw (make-draws (1+ index)))
         (c (funcall draw 40)))
    (values (mapcar (lambda (midi duration)
                      (cons (+ midi (/ (+ c (funcall draw 10) (funcall draw 10) (funcall draw 10))
                                       100))
                            duration))
                    (row-midis row) (fourth row))
            c)))

(defun drifting-take (index)
  "The INDEXth MT4 melody starting C cents sharp, C being the first draw in -30 … 30
of (MAKE-DRAWS (+ 1000 INDEX)), and sinking evenly by 20 cents to its last note:
note j of n is C - 20j/(n - 1) cents. The events and C, as two values."
  (let* ((row (nth index (melodies)))
         (c (funcall (make-draws (+ 1000 index)) 30))
         (n (length (row-midis row))))
    (values (loop for midi in (row-midis row)
                  for duration in (fourth row)
                  for j from 0
                  collect (cons (+ midi (/ (- c (/ (* 20 j) (1- n))) 100)) duration))
            c)))

(defparameter *two-peak-profiles*
  '((4 1 0 0 0 0 0 0 0 0 0 1) (1 1 1 1 1 1 0 0 0 0 0 0))
  "A (major minor) profile pair for the tie rows: a major peak on the tonic with equal
neighbours, and a flat minor that never wins.")

(defparameter *semitone-pair-profiles*
  '((2 2 0 0 0 0 0 0 0 0 0 0) (1 1 1 1 1 1 0 0 0 0 0 0))
  "A pair whose major profile weighs the tonic and the semitone above it alike, so a
lone in-tune note ties two keys a semitone apart.")

;;; Given: the offset table and the result value --------------------------------------

(deftest key-fit-offsets-table
  (let ((offsets music-theory::+key-fit-offsets+))
    (ok (= 100 (length offsets)))
    (ok (equal (loop for d from -50 below 50 collect d) (sort (copy-list offsets) #'<))
        "-50 … 49, each once")
    (ok (equal '(0 -1 1 -2 2 -3 3) (subseq offsets 0 7)) "smaller |d| first, then the negative")
    (ok (equal '(-48 48 -49 49 -50) (last offsets 5)))))

(deftest key-fit-value
  (let ((fit (make-key-fit :key (k "C major") :offset -3 :correlation 0.5d0
                           :ranking (list (cons (k "C major") 0.5d0))
                           :midis '(60) :deviations '(7/2))))
    (ok (key-fit-p fit))
    (ok (not (key-fit-p (k "C major"))))
    (ok (equalp fit (make-key-fit :key (k "C major") :offset -3 :correlation 0.5d0
                                  :ranking (list (cons (k "C major") 0.5d0))
                                  :midis '(60) :deviations '(7/2)))
        "compared with EQUALP")
    (ok (equal '(nil nil nil nil)
               (list (key-fit-hint fit) (key-fit-hint-offset fit)
                     (key-fit-hint-correlation fit) (key-fit-hint-distance fit)))
        "no hint: four NILs")
    (ok (not (fboundp '(setf key-fit-key))) "read-only")
    (ok (equalp fit (read-from-string (prin1-to-string fit))) "printed readably")))

;;; Folding real pitches ------------------------------------------------------------

(deftest-parametrize pitch-class-histogram-real-pitches
    ((events weight expected)
     ('((60.5 . 1)) :duration #(1/2 1/2 0 0 0 0 0 0 0 0 0 0))
     ('((6137/100 . 1)) :duration #(0 63/100 37/100 0 0 0 0 0 0 0 0 0))
     ('((71.75 . 2)) :duration #(3/2 0 0 0 0 0 0 0 0 0 0 1/2))
     ('((-1/2 . 1)) :duration #(1/2 0 0 0 0 0 0 0 0 0 0 1/2))
     ('((60.0d0 . 1/4)) :duration #(1/4 0 0 0 0 0 0 0 0 0 0 0))
     ('(60.25 64 67.75) :duration #(3/4 1/4 0 0 1 0 0 1/4 3/4 0 0 0))
     ('((60.5 . 3)) :count #(1/2 1/2 0 0 0 0 0 0 0 0 0 0))
     ('((60.5 . 3)) :duration #(3/2 3/2 0 0 0 0 0 0 0 0 0 0))
     ('(("C4" . 1) (61.5 . 1) ("Db" . 1/2)) :duration #(1 1 1/2 0 0 0 0 0 0 0 0 0))
     ('((1271/20 . 2) (-3/4 . 1)) :duration #(1/4 0 0 9/10 11/10 0 0 0 0 0 0 3/4)))
  (let ((h (pitch-class-histogram (mapcar #'ev events) :weight weight)))
    (ok (and (simple-vector-p h) (= 12 (length h))))
    (ok (every #'= expected h) (format nil "~S" h))
    (ok (every #'rationalp h) "rational amounts give exact cells")))

(deftest pitch-class-histogram-real-pitch-arithmetic
  (let ((h (pitch-class-histogram '((0.1d0 . 1)))))
    (ok (and (= (svref h 0) (- 1 (rational 0.1d0))) (= (svref h 1) (rational 0.1d0)))
        "a float pitch is taken as its RATIONAL")
    (ok (and (rationalp (svref h 0)) (rationalp (svref h 1)))))
  (let ((h (pitch-class-histogram '((60.5 . 0.5d0)))))
    (ok (and (= 0.25d0 (svref h 0) (svref h 1)) (floatp (svref h 0)))
        "a float duration gives float cells, as before"))
  (ok (equalp (pitch-class-histogram '((60 . 1/4) (64 . 1/2)))
              (pitch-class-histogram '((60.0d0 . 1/4) (64.0d0 . 1/2))))
      "an integral float is its integer")
  (ok (let ((row (melody "fur-elise")))
        (equalp (pitch-class-histogram (take row :cents 30))
                (pitch-class-histogram (mapcar (lambda (e) (cons (- (car e) 3/10) (cdr e)))
                                               (take row :cents 60)))))
      "only the pitch matters, however it was reached")
  (ok (signals-type (lambda () (call #'pitch-class-histogram '((60.5 . -1)))) 'type-error)
      "a negative duration")
  (ok (signals-type (lambda () (call #'pitch-class-histogram '(#C(60 1)))) 'type-error)
      "a complex is no pitch"))

;;; In tune: DETECT-KEY at offset 0 --------------------------------------------------

(deftest-parametrize fit-key-in-tune-is-detect-key
    ((profiles weight)
     (:krumhansl-kessler :duration)
     (:temperley :duration)
     (:aarden :duration)
     (:krumhansl-kessler :count))
  (let ((bad '()))
    (dolist (row (melodies))
      (let* ((fit (fit-key (take row :weight weight) :profiles profiles))
             (want (in-tune-ranking row :profiles profiles :weight weight)))
        (unless (and (key-fit-p fit)
                     (eql 0 (key-fit-offset fit))
                     (same-ranking-p (key-fit-ranking fit) want)
                     (eq (key-fit-key fit) (car (first (key-fit-ranking fit))))
                     (eql (key-fit-correlation fit) (cdr (first (key-fit-ranking fit))))
                     (equal (key-fit-midis fit) (row-midis row))
                     (every (lambda (d) (eql 0 d)) (key-fit-deviations fit))
                     (null (key-fit-hint fit)))
          (push (list (first row) (fit-summary fit)) bad))))
    (ok (null bad) (format nil "~(~A ~A~): ~S" profiles weight bad))))

(deftest-parametrize fit-key-shifted-by-cents
    ((cents)
     (23) (-37) (1) (-1) (12) (-45) (49) (-50))
  (let ((bad '()))
    (dolist (row (melodies))
      (let ((fit (fit-key (take row :cents cents))))
        (unless (and (eql cents (key-fit-offset fit))
                     (same-ranking-p (key-fit-ranking fit) (in-tune-ranking row))
                     (equal (key-fit-midis fit) (row-midis row))
                     (every (lambda (d) (eql 0 d)) (key-fit-deviations fit)))
          (push (list (first row) (fit-summary fit)) bad))))
    (ok (null bad) (format nil "~@D cents: ~S" cents bad))))

(deftest-parametrize fit-key-shifted-past-a-half-semitone
    ((cents offset semitones)
     ;; The key absorbs whole semitones: offsets stay in -50 … 49.
     (50 -50 1)
     (100 0 1)
     (123 23 1)
     (-51 49 -1)
     (-100 0 -1)
     (-137 -37 -1)
     (150 -50 2)
     (1223 23 12)
     (-1250 -50 -12))
  (let ((bad '()))
    (dolist (row (melodies))
      (let* ((fit (fit-key (take row :cents cents)))
             (want (in-tune-ranking row)))
        (unless (and (eql offset (key-fit-offset fit))
                     (equal (mapcar (lambda (e) (moved-key-name (car e) semitones)) want)
                            (ranking-names (key-fit-ranking fit)))
                     (equal (mapcar #'cdr want) (mapcar #'cdr (key-fit-ranking fit)))
                     (equal (mapcar (lambda (m) (+ m semitones)) (row-midis row))
                            (key-fit-midis fit)))
          (push (list (first row) (fit-summary fit)) bad))))
    (ok (null bad) (format nil "~@D cents: ~S" cents bad))))

(deftest-parametrize fit-key-float-pitches
    ((id cents)
     ("twinkle" 23) ("ode-to-joy" -37) ("greensleeves" 23) ("beethoven-5" -37)
     ("oh-susanna" 41) ("largo" -12))
  ;; 61.23d0 is not 6123/100: the fold at 23 cents is crisp to about 1e-13.
  (let* ((row (melody id))
         (fit (fit-key (mapcar (lambda (midi duration)
                                 (cons (+ midi (* cents 1/100 1d0)) duration))
                               (row-midis row) (fourth row))))
         (want (in-tune-ranking row)))
    (ok (<= (abs (- (key-fit-offset fit) cents)) 1) (format nil "~S" (fit-summary fit)))
    (ok (near-ranking-p (key-fit-ranking fit) want 1d-6))
    (ok (equal (key-fit-midis fit) (row-midis row)))
    (ok (every (lambda (d) (and (rationalp d) (< (abs d) 1))) (key-fit-deviations fit)))))

;;; Relative keys: as DETECT-KEY decides them --------------------------------------

(deftest-parametrize fit-key-relative-keys
    ((id notated detected)
     ;; DETECT-KEY's first key (Krumhansl-Kessler), in tune; FIT-KEY agrees at
     ;; every offset. The first four are notated in major and detected in the
     ;; relative minor, the next two in their notated key, the last notated in
     ;; minor and detected in the parallel major.
     ("jingle-bells" "F major" "A minor")
     ("spring" "E major" "G# minor")
     ("gymnopedie" "D major" "F# minor")
     ("canon-in-d" "D major" "B minor")
     ("greensleeves" "A minor" "A minor")
     ("silent-night" "Bb major" "Bb major")
     ("toccata" "D minor" "D major"))
  (let ((row (melody id)))
    (ok (string= notated (second row)))
    (ok (string= detected (key-name (in-tune-key row))) "DETECT-KEY's choice")
    (dolist (cents '(0 23 -37))
      (let ((fit (fit-key (take row :cents cents))))
        (ok (and (string= detected (key-name (key-fit-key fit))) (eql cents (key-fit-offset fit)))
            (format nil "~@D cents: ~S" cents (fit-summary fit)))))))

;;; Weights ---------------------------------------------------------------------------

(deftest-parametrize fit-key-weights-decide-the-key
    ((id by-duration by-count)
     ;; In tune, so DETECT-KEY of the :DURATION and :COUNT histograms.
     ("beethoven-5" "C minor" "Eb major")
     ("fur-elise" "A minor" "E minor")
     ("toccata" "D major" "D minor")
     ("take-me-out" "G major" "A minor"))
  (let ((row (melody id)))
    (dolist (cents '(0 -23))
      (ok (string= by-duration (key-name (key-fit-key (fit-key (take row :cents cents)))))
          "weighted by duration")
      (ok (string= by-count
                   (key-name (key-fit-key (fit-key (take row :cents cents :weight :count)))))
          "every note 1")
      (ok (string= by-count
                   (key-name (key-fit-key (fit-key (mapcar #'car (take row :cents cents))))))
          "bare pitches count 1"))))

(deftest fit-key-weights-decide-the-offset
  ;; Twinkle's first 21 notes 20 cents sharp, its last 21 notes 20 cents flat.
  (let ((events (loop for (pitch . weight) in (take (melody "twinkle"))
                      for j from 0
                      collect (cons (+ pitch (if (< j 21) 1/5 -1/5)) weight))))
    (flet ((weighted (first-half second-half)
             (fit-key (loop for (pitch . weight) in events
                            for j from 0
                            collect (cons pitch (* weight (if (< j 21) first-half second-half)))))))
      (ok (equal '("C major" 20) (fit-summary (weighted 3 1))) "the sharp half weighs more")
      (ok (equal '("C major" -20) (fit-summary (weighted 1 3))) "the flat half weighs more")))
  ;; Amazing Grace with every note of a half or longer 25 cents sharp, the rest 15 flat.
  (let ((events (mapcar (lambda (midi duration)
                          (cons (+ midi (if (>= duration 1/2) 1/4 -3/20)) duration))
                        (row-midis (melody "amazing-grace")) (fourth (melody "amazing-grace")))))
    (ok (equal '("Eb major" 25) (fit-summary (fit-key events))) "the long notes, by duration")
    (ok (equal '("Eb major" -15) (fit-summary (fit-key (mapcar #'car events))))
        "the many short notes, by count")))

(deftest fit-key-weight-invariances
  (multiple-value-bind (events) (detuned-take 7)
    (let ((fit (fit-key events)))
      (ok (equalp fit (fit-key (mapcar (lambda (e) (cons (car e) (* 7/3 (cdr e)))) events)))
          "scaling every weight changes nothing")
      (let ((more (fit-key (append events '((61.5 . 0) (70 . 0) (62.25 . 0))))))
        (ok (and (eq (key-fit-key fit) (key-fit-key more))
                 (eql (key-fit-offset fit) (key-fit-offset more))
                 (same-ranking-p (key-fit-ranking fit) (key-fit-ranking more)))
            "zero weights change no score")
        (ok (= (+ 3 (length events)) (length (key-fit-midis more)) (length (key-fit-deviations more)))
            "but have MIDIs and deviations"))
      (let ((up (fit-key (mapcar (lambda (e) (cons (+ 12 (car e)) (cdr e))) events)))
            (down (fit-key (mapcar (lambda (e) (cons (- (car e) 24) (cdr e))) events))))
        (ok (and (eq (key-fit-key fit) (key-fit-key up)) (eq (key-fit-key fit) (key-fit-key down))
                 (eql (key-fit-offset fit) (key-fit-offset up) )
                 (eql (key-fit-offset fit) (key-fit-offset down))
                 (same-ranking-p (key-fit-ranking fit) (key-fit-ranking up))
                 (same-ranking-p (key-fit-ranking fit) (key-fit-ranking down))
                 (equal (key-fit-deviations fit) (key-fit-deviations up))
                 (equal (mapcar (lambda (m) (+ 12 m)) (key-fit-midis fit)) (key-fit-midis up))
                 (equal (mapcar (lambda (m) (- m 24)) (key-fit-midis fit)) (key-fit-midis down)))
            "octaves change only the MIDIs"))
      (let ((backwards (fit-key (reverse events))))
        (ok (and (eql (key-fit-offset fit) (key-fit-offset backwards))
                 (same-ranking-p (key-fit-ranking fit) (key-fit-ranking backwards))
                 (equal (reverse (key-fit-midis fit)) (key-fit-midis backwards))
                 (equal (reverse (key-fit-deviations fit)) (key-fit-deviations backwards)))
            "event order changes only the order of MIDIs and deviations")))))

;;; Ranking, scores and ties --------------------------------------------------------------

(deftest fit-key-ranking-shape
  (multiple-value-bind (events) (detuned-take 3)
    (let* ((fit (fit-key events))
           (ranking (key-fit-ranking fit)))
      (ok (= 24 (length ranking)))
      (ok (null (set-exclusive-or (ranking-names ranking) music-theory::+detect-key-candidates+
                                  :test #'string=))
          "every candidate once")
      (ok (every (lambda (e) (member (car e) music-theory::+detect-key-keys+)) ranking)
          "the candidates' own KEYs")
      (ok (every (lambda (a b) (>= (cdr a) (cdr b))) ranking (rest ranking)) "best first")
      (ok (every (lambda (e) (and (typep (cdr e) 'double-float) (<= -1d0 (cdr e) 1d0))) ranking))
      (ok (and (eq (key-fit-key fit) (car (first ranking)))
               (eql (key-fit-correlation fit) (cdr (first ranking)))))
      (ok (typep (key-fit-offset fit) '(integer -50 49)))
      (ok (equalp fit (fit-key events)) "deterministic")))
  (let ((fit (fit-key (take (melody "twinkle")))))
    (ok (equalp fit (fit-key (take (melody "twinkle")) :profiles
                             (let ((table (rest (assoc :krumhansl-kessler music-theory::+key-profiles+))))
                               (list (mapcar (lambda (x) (* 3 x)) (second table)) (third table)))))
        "scaling a profile changes nothing")))

(deftest fit-key-scores-share-one-normaliser
  ;; Off the crispest fold, a score is the fold's Pearson r scaled by
  ;; sqrt(variance/H), the same factor for all 24 keys; the order is DETECT-KEY's
  ;; for that fold. These three detuned takes fit best 5 to 12 cents from their
  ;; crispest fold (factors 0.981 to 0.987).
  (dolist (index '(23 26 30))
    (multiple-value-bind (events) (detuned-take index)
      (flet ((fold (d)
               (pitch-class-histogram (mapcar (lambda (e) (cons (- (rational (car e)) (/ d 100))
                                                                (rational (cdr e))))
                                              events)))
             (variance (cells)
               (let ((mean (/ (reduce #'+ cells) 12)))
                 (reduce #'+ cells :key (lambda (x) (expt (- x mean) 2))))))
        (let* ((fit (fit-key events))
               (d (key-fit-offset fit))
               (pearson (detect-key (fold d)))
               (h (loop for e from -50 below 50 maximize (variance (fold e))))
               (factor (sqrt (float (/ (variance (fold d)) h) 1d0)))
               (ratios (mapcar (lambda (got want) (/ (cdr got) (cdr want)))
                               (key-fit-ranking fit) pearson)))
          (ok (equal (ranking-names pearson) (ranking-names (key-fit-ranking fit)))
              "DETECT-KEY's order for the fold at the offset")
          (ok (< factor 0.99d0) "not the crispest fold")
          (ok (every (lambda (r) (< (abs (- r factor)) 1d-12)) ratios)
              (format nil "every score is r·~,6F, sqrt(variance/H)" factor)))))))

(deftest-parametrize fit-key-ties
    ((events profiles key offset hint hint-offset)
     ;; 60.3 and 60.7: C major fits best at +30 and Db major at -30, equally.
     ;; Equal |d|: the negative offset.
     ('(603/10 607/10) *two-peak-profiles* "Db major" -30 "C major" 30)
     ;; A semitone lower: B major at +30 against C major at -30.
     ('(593/10 597/10) *two-peak-profiles* "C major" -30 "B major" 30)
     ;; 61 alone: C major ties at every d in 0 … 49 and Db major at every d in
     ;; -50 … 0. The smaller |d|, then the candidate order: C major at 0.
     ('(61) *semitone-pair-profiles* "C major" 0 "Db major" 0)
     ('((61 . 5/2)) *semitone-pair-profiles* "C major" 0 "C major" 0))
  (let ((fit (fit-key events :profiles profiles :hint (k hint))))
    (ok (equal (list key offset) (fit-summary fit)) (format nil "~S" (fit-summary fit)))
    (ok (eql hint-offset (key-fit-hint-offset fit)) (format nil "hint offset ~S" (key-fit-hint-offset fit)))
    (ok (eql (key-fit-correlation fit) (key-fit-hint-correlation fit)) "the hint ties the best")))

(deftest fit-key-tie-orders
  (let ((names (ranking-names (key-fit-ranking (fit-key '(61) :profiles *semitone-pair-profiles*)))))
    (ok (equal '("C major" "Db major") (subseq names 0 2)) "equal scores in candidate order"))
  (let ((fit (fit-key '(60) :profiles :aarden)))
    (ok (eql 0 (key-fit-offset fit)))
    (ok (equal (ranking-names (detect-key #(1 0 0 0 0 0 0 0 0 0 0 0) :profiles :aarden))
               (ranking-names (key-fit-ranking fit)))
        "Aarden's exact ties keep DETECT-KEY's candidate order (E major before B major)")))

;;; Hints ------------------------------------------------------------------------------

(deftest-parametrize fit-key-hint-rows
    ((id cents semitones hint key offset hint-offset distance)
     ;; Twinkle is C major; its own key and the keys a semitone around it.
     ("twinkle" 0 0 "C major" "C major" 0 0 0)
     ("twinkle" 0 0 "Db major" "C major" 0 -50 -1)
     ("twinkle" 0 0 "B major" "C major" 0 49 1)
     ("twinkle" -30 0 "C major" "C major" -30 -30 0)
     ("twinkle" 30 0 "C major" "C major" 30 30 0)
     ("twinkle" -70 0 "C major" "B major" 30 -50 -1)
     ("twinkle" 70 0 "C major" "Db major" -30 49 1)
     ("twinkle" 0 -2 "C major" "Bb major" 0 0 -2)
     ("twinkle" 0 0 "F# major" "C major" 0 49 6)
     ;; A take sung a semitone below or above the hint, in minor.
     ("greensleeves" 0 -1 "A minor" "G# minor" 0 -50 -1)
     ("beethoven-5" 12 1 "C minor" "C# minor" 12 49 1)
     ;; The hint's mode decides: Jingle Bells and Spring rank the relative minor
     ;; first and read 0 against their notated keys; Canon in D ranks B minor
     ;; first and A major (the dominant) above D major: -5.
     ("jingle-bells" 0 0 "F major" "A minor" 0 0 0)
     ("spring" -15 0 "E major" "G# minor" -15 -15 0)
     ("canon-in-d" 0 0 "D major" "B minor" 0 0 -5)
     ;; Enharmonic hints: the candidate is matched by tonic pitch class and mode.
     ("oh-susanna" 0 0 "Gb major" "F# major" 0 0 0)
     ("largo" 21 0 "C# major" "Db major" 21 21 0))
  (let* ((fit (fit-key (take (melody id) :cents cents :semitones semitones) :hint (k hint))))
    (ok (equal (list key offset) (fit-summary fit)) (format nil "~S" (fit-summary fit)))
    (ok (eql hint-offset (key-fit-hint-offset fit)) (format nil "hint offset ~S" (key-fit-hint-offset fit)))
    (ok (eql distance (key-fit-hint-distance fit)) (format nil "distance ~S" (key-fit-hint-distance fit)))
    (ok (equalp (k hint) (key-fit-hint fit)) "the hint as given")
    (ok (and (typep (key-fit-hint-correlation fit) 'double-float)
             (<= (key-fit-hint-correlation fit) (key-fit-correlation fit))))
    (when (call #'string= key hint)      ; CALL: constant rows fold no branch away
      (ok (and (eql 0 (key-fit-hint-distance fit))
               (eql (key-fit-offset fit) (key-fit-hint-offset fit))
               (eql (key-fit-hint-correlation fit) (key-fit-correlation fit)))
          "the hint is the best"))))

(deftest fit-key-hint-a-semitone-away
  ;; Every melody, in tune and 23 cents flat, against hints a semitone above and
  ;; below its in-tune key and against that key itself. In tune, the hint a
  ;; semitone up fits best 50 cents flat and the one a semitone down 49 sharp
  ;; (each score mixes the hint's and its neighbour's, the sung key). At -23 the
  ;; take lies 123 or 77 cents from those hints, and their own offsets are whatever
  ;; scores best in the window: not asserted.
  (let ((bad '()))
    (dolist (row (melodies))
      (let ((key (in-tune-key row)))
        (dolist (cents '(0 -23))
          (loop for (semitones distance hint-offset) in '((1 -1 -50) (-1 1 49) (0 0 nil))
                for hint = (k (moved-key-name key semitones))
                for fit = (fit-key (take row :cents cents) :hint hint)
                unless (and (eq key (key-fit-key fit))
                            (eql cents (key-fit-offset fit))
                            (eql distance (key-fit-hint-distance fit))
                            (typep (key-fit-hint-offset fit) '(integer -50 49))
                            (cond ((null hint-offset) (eql cents (key-fit-hint-offset fit)))
                                  ((zerop cents) (eql hint-offset (key-fit-hint-offset fit)))
                                  (t t))
                            (<= (key-fit-hint-correlation fit) (key-fit-correlation fit))
                            (or hint-offset
                                (eql (key-fit-hint-correlation fit) (key-fit-correlation fit))))
                  do (push (list (first row) cents (key-name hint) (fit-summary fit)
                                 (key-fit-hint-offset fit) (key-fit-hint-distance fit))
                           bad)))))
    (ok (null bad) (format nil "~D: ~S" (length bad) (subseq bad 0 (min 6 (length bad)))))))

(deftest fit-key-hint-outside-the-thirty
  (let* ((hint (make-key :tonic (pc "G#") :mode :major))
         (fit (fit-key (take (melody "auld-lang-syne")) :hint hint)))
    (ok (eq hint (key-fit-hint fit)) "kept as given")
    (ok (string= "Ab major" (key-name (key-fit-key fit))))
    (ok (eql 0 (key-fit-hint-distance fit)))
    (ok (eql (key-fit-correlation fit) (key-fit-hint-correlation fit)))))

;;; MIDI numbers and deviations ------------------------------------------------------------

(deftest-parametrize fit-key-midis-and-deviations
    ((events offset midis deviations)
     ;; C D E F G 23 cents sharp; two silent notes show the rounding: 64.73 is
     ;; 64.5 after the offset and rounds up, 63.72 is 63.49 and rounds down.
     ('(6023/100 6223/100 6423/100 6523/100 6723/100 (6473/100 . 0) (6372/100 . 0))
      23 '(60 62 64 65 67 65 63) '(0 0 0 0 0 -50 49))
     ;; 49 cents sharp: G stays G at offset 49.
     ('(6049/100 6449/100 6749/100 (5550/100 . 0)) 49 '(60 64 67 55) '(0 0 0 1))
     ;; 50 cents sharp reads as a semitone up, 50 flat.
     ('(6050/100 6450/100 6750/100) -50 '(61 65 68) '(0 0 0))
     ('((-1/2 . 1) (7/2 . 1) (13/2 . 1)) -50 '(0 4 7) '(0 0 0)))
  (let ((fit (fit-key events)))
    (ok (eql offset (key-fit-offset fit)) (format nil "~S" (fit-summary fit)))
    (ok (equal midis (key-fit-midis fit)) (format nil "~S" (key-fit-midis fit)))
    (ok (and (every #'rationalp (key-fit-deviations fit))
             (every #'= deviations (key-fit-deviations fit)))
        (format nil "~S" (key-fit-deviations fit)))))

(deftest fit-key-deviations-are-the-detuning
  (multiple-value-bind (events c) (detuned-take 0)
    (let* ((fit (fit-key events))
           (d (key-fit-offset fit)))
      (ok (equal (row-midis (nth 0 (melodies))) (key-fit-midis fit)) "nothing detuned past a half semitone")
      (ok (every (lambda (event midi dev)
                   (= dev (* 100 (- (car event) (/ d 100) midi))))
                 events (key-fit-midis fit) (key-fit-deviations fit)))
      (ok (every (lambda (dev) (and (<= -50 dev) (< dev 50))) (key-fit-deviations fit)))
      (ok (<= (abs (- d c)) 10) (format nil "offset ~D, sung ~D" d c)))))

(deftest-parametrize fit-key-midis-spell-the-take
    ((id cents)
     ("ode-to-joy" 23) ("amazing-grace" -37) ("funeral-march" 12) ("largo" -45)
     ("la-donna-e-mobile" 31) ("swan-lake" -8))
  ;; These six are detected in their notated key, so SPELL-SEQUENCE with the fitted
  ;; key spells them as notated (MT4 spells all 1699 notes with the key).
  (let* ((row (melody id))
         (fit (fit-key (take row :cents cents))))
    (ok (string= (second row) (key-name (key-fit-key fit))))
    (ok (equal (third row) (spelled-names (spell-sequence (key-fit-midis fit) :key (key-fit-key fit)))))))

;;; Robustness -------------------------------------------------------------------------------

(deftest fit-key-detuned-takes
  ;; Each melody sung at its own offset with every note detuned (DETUNED-TAKE).
  ;; Counts as computed by the reference implementations; any implementation of
  ;; the header computes the same, as the takes and the rules are exact.
  (let ((same-key 0) (in-top-two 0) (within-5 0) (within-10 0) (worst 0))
    (dotimes (index 50)
      (multiple-value-bind (events c) (detuned-take index)
        (let* ((row (nth index (melodies)))
               (clean (in-tune-ranking row))
               (fit (fit-key events))
               (error (abs (- (key-fit-offset fit) c))))
          (when (eq (key-fit-key fit) (car (first clean))) (incf same-key))
          (when (member (key-fit-key fit) (subseq clean 0 2) :key #'car) (incf in-top-two))
          (when (<= error 5) (incf within-5))
          (when (<= error 10) (incf within-10))
          (setf worst (max worst error)))))
    (ok (>= same-key 48) (format nil "the in-tune key ~D/50" same-key))
    (ok (= in-top-two 50) (format nil "in the in-tune top two ~D/50" in-top-two))
    (ok (>= within-5 40) (format nil "offset within 5 cents ~D/50" within-5))
    (ok (>= within-10 47) (format nil "offset within 10 cents ~D/50" within-10))
    (ok (<= worst 15) (format nil "worst offset error ~D cents" worst))))

(deftest fit-key-drifting-takes
  ;; Each melody sinking by 20 cents from its first note to its last (DRIFTING-TAKE).
  (let ((same-key 0) (inside 0))
    (dotimes (index 50)
      (multiple-value-bind (events c) (drifting-take index)
        (let ((fit (fit-key events)))
          (when (eq (key-fit-key fit) (in-tune-key (nth index (melodies)))) (incf same-key))
          (when (<= (- c 20) (key-fit-offset fit) c) (incf inside)))))
    (ok (>= same-key 48) (format nil "the in-tune key ~D/50" same-key))
    (ok (= inside 50) (format nil "offset within the drift ~D/50" inside))))

;;; No evidence ----------------------------------------------------------------------------

(deftest-parametrize fit-key-no-evidence
    ((events reason)
     ('() "zero total weight")
     ('((60 . 0) (64.5 . 0)) "zero total weight")
     ((loop for p from 60 below 72 collect p) "constant histogram at every offset")
     ((loop for p from 60 below 72 collect (cons (+ p 17/100) 2/3)) "constant histogram at every offset")
     ((loop for p from 0 below 24 collect (+ 48 (/ p 2))) "constant histogram at every offset"))
  (let ((seen (handler-case (progn (fit-key events) nil)
                (condition (c) c))))
    (ok (typep seen 'no-key-evidence) (format nil "~S" seen))
    (ok (typep seen 'music-theory-error))
    (ok (and seen (equal reason (music-theory-error-reason seen))))
    (ok (and seen (null (music-theory-error-text seen))))
    (ok (and seen (search reason (princ-to-string seen))) "the report names the reason"))
  (let ((value (handler-bind ((no-key-evidence (lambda (c) (use-value :silence c))))
                 (fit-key events))))
    (ok (eq :silence value) "USE-VALUE: FIT-KEY returns the value")))

(deftest fit-key-no-evidence-restart
  (let* ((stand-in (make-key-fit :key (k "C major") :offset 0 :correlation 0d0))
         (value (handler-bind ((no-key-evidence (lambda (c) (use-value stand-in c))))
                  (fit-key '() :hint (k "C major")))))
    (ok (eq stand-in value) "a KEY-FIT of the caller's"))
  (let ((restarts '()))
    (handler-case (handler-bind ((no-key-evidence
                                   (lambda (c)
                                     (setf restarts (mapcar #'restart-name (compute-restarts c))))))
                    (fit-key '((60 . 0))))
      (no-key-evidence () nil))
    (ok (member 'use-value restarts) "USE-VALUE is offered"))
  (ok (key-fit-p (fit-key '(61.37))) "one note is evidence")
  (ok (key-fit-p (fit-key (loop for p from 60 below 71 collect p))) "eleven chromatic notes are evidence"))

;;; Argument errors --------------------------------------------------------------------------

(deftest fit-key-argument-errors
  (ok (signals-type (lambda () (call #'fit-key #(60 64 67))) 'type-error) "a list, not a vector")
  (ok (signals-type (lambda () (call #'fit-key '(60 . 64))) 'type-error) "a proper list")
  (ok (signals-type (lambda () (call #'fit-key '(c4 e4))) 'type-error) "a symbol is no pitch")
  (ok (signals-type (lambda () (call #'fit-key (list (p "C4")))) 'type-error) "a spelled pitch is no pitch centre")
  (ok (signals-type (lambda () (call #'fit-key '("60.5"))) 'type-error))
  (ok (signals-type (lambda () (call #'fit-key '(#C(60 1)))) 'type-error))
  (ok (signals-type (lambda () (call #'fit-key '((60 . -1/4)))) 'type-error) "a negative weight")
  (ok (signals-type (lambda () (call #'fit-key '((60 . :long)))) 'type-error) "a non-real weight")
  (ok (signals-type (lambda () (call #'fit-key '(60 64) :hint "C major")) 'type-error) "a KEY, not its name")
  (ok (signals-type (lambda () (call #'fit-key '(60 64) :hint :c-major)) 'type-error))
  (ok (signals-type (lambda () (call #'fit-key '(60 64) :profiles :bellman)) 'type-error))
  (ok (signals-type (lambda () (call #'fit-key '(60 64) :profiles '(1 2 3))) 'type-error))
  (let ((constant (list (make-list 12 :initial-element 1) (make-list 12 :initial-element 2))))
    (let ((seen (handler-case (progn (fit-key '(60 64 67) :profiles constant) nil)
                  (condition (c) c))))
      (ok (and (typep seen 'music-theory-error) (not (typep seen 'no-key-evidence))
               (equal "constant key profile" (music-theory-error-reason seen)))
          "a constant profile, as DETECT-KEY"))
    (let ((seen (handler-case (progn (fit-key '() :profiles constant) nil)
                  (condition (c) c))))
      (ok (and (typep seen 'music-theory-error) (not (typep seen 'no-key-evidence)))
          "the profile before the evidence"))
    (ok (signals-type (lambda () (call #'fit-key #(60) :profiles constant)) 'type-error)
        "the arguments before the profile")
    (ok (signals-type (lambda () (call #'fit-key '() :hint "C")) 'type-error)
        "the arguments before the evidence")))

(deftest fit-key-store-value
  ;; CHECK-TYPE's STORE-VALUE supplies a replacement argument.
  (let ((fit (handler-bind ((type-error (lambda (c) (store-value '(60 64 67 72) c))))
               (call #'fit-key #(60 64 67 72)))))
    (ok (and (key-fit-p fit) (string= "C major" (key-name (key-fit-key fit)))) "new events"))
  (let ((fit (handler-bind ((type-error (lambda (c) (store-value (k "G major") c))))
               (call #'fit-key '(60 64 67 72) :hint "G major"))))
    (ok (and (key-fit-p fit) (equalp (k "G major") (key-fit-hint fit))) "a new hint")
    (ok (and (key-fit-p fit) (eql 5 (key-fit-hint-distance fit))) "G up to C")))
