;;;; MT1 meters and the metric hierarchy.
;;;;
;;;; Durations and positions are CL rationals in whole notes (1/4 = a quarter).
;;;; A METER is NUMERATORS (a list: (4) for 4/4, (2 3) for the additive 2+3/8)
;;;; over DENOMINATOR (a power of two, 1..64).
;;;;
;;;; PARSE-METER reads "4/4", "6/8", "2+3/8", "3+2+2/8", "C" (= 4/4) and "C|"
;;;; (= 2/2), surrounding whitespace trimmed. Numerators are integers 1..64.
;;;; Anything else signals INVALID-METER (TEXT = the input) inside a USE-VALUE
;;;; restart. METER-STRING prints "4/4" or "2+3/8" (never "C").
;;;;
;;;; Beats (METER-BEATS, a list of beat durations summing to the bar):
;;;;   compound  = a single numerator n > 3 with n mod 3 = 0 (6/8, 9/8, 12/8, 6/4):
;;;;               n/3 beats of 3/denominator.
;;;;   additive  = several numerators: one beat per numerator, numerator/denominator
;;;;               ((2 3)/8 → (1/4 3/8)).
;;;;   simple    = otherwise: n beats of 1/denominator (3/8 → three eighths, 5/4 → five quarters).
;;;; BEAT-UNIT is the common beat duration, or NIL when the beats differ.
;;;;
;;;; METRIC-WEIGHT meter offset → an integer level, 0 strongest. OFFSET is first
;;;; reduced modulo the bar length (so pickups and later bars work).
;;;;   0  the downbeat (offset 0).
;;;;   1  a beat-group start other than the downbeat. Groups: when all beats are
;;;;      equal and there are 4 or more of an even count, beats pair up
;;;;      (4/4: beat 3; 12/8: beat 3); in an additive meter every beat starts a group.
;;;;   2  any other beat start.
;;;;   3+j  inside a beat of duration D starting at b: the smallest j in 0..5 with
;;;;      (offset - b) a multiple of D / (s * 2^j), where s is D's numerator in
;;;;      lowest terms when it is greater than 1, else 2. A dotted beat (3/8)
;;;;      splits in three, a five-eighth beat of an additive meter (3+5/8) in five
;;;;      eighths, a plain beat (1/4) in halves (music-theory#7).
;;;;   9  off every grid above (e.g. a triplet position in 4/4).

(in-package #:music-theory)

(defstruct (meter (:constructor make-meter))
  (numerators '(4) :type list :read-only t)
  (denominator 4 :type (integer 1 64) :read-only t))

(defparameter +meter-denominators+ '(1 2 4 8 16 32 64)
  "Allowed denominators. Data.")

(defparameter +meter-symbols+ '(("C" (4) 4) ("C|" (2) 2))
  "Time-signature symbols PARSE-METER reads: (text numerators denominator). Data.")

(defparameter +max-meter-numerator+ 64
  "Largest numerator PARSE-METER reads. Data.")

(defparameter +off-grid-weight+ 9
  "METRIC-WEIGHT of a point on no subdivision grid. The grids weigh 3+j for
j in 0..5, i.e. 3..8. Data.")

;;; Kernel: beats -------------------------------------------------------------

(defun %meter-kind (meter)
  "The beat classification of the file header: :ADDITIVE, :COMPOUND or :SIMPLE.
The only place that tells the three apart."
  (let ((numerators (meter-numerators meter)))
    (cond ((rest numerators) :additive)
          ((let ((n (first numerators))) (and (> n 3) (zerop (mod n 3)))) :compound)
          (t :simple))))

(defun meter-measure-duration (meter)
  "Bar length in whole notes: (sum of numerators) / denominator."
  (/ (reduce #'+ (meter-numerators meter)) (meter-denominator meter)))

(defun compound-p (meter)
  "True for a single numerator n > 3 with n mod 3 = 0 (6/8, 9/8, 12/8, 6/4)."
  (eq :compound (%meter-kind meter)))

(defun meter-beats (meter)
  "Beat durations of one bar (file header), summing to METER-MEASURE-DURATION."
  (let ((numerators (meter-numerators meter))
        (denominator (meter-denominator meter)))
    (ecase (%meter-kind meter)
      (:additive (mapcar (lambda (n) (/ n denominator)) numerators))
      (:compound (make-list (/ (first numerators) 3) :initial-element (/ 3 denominator)))
      (:simple (make-list (first numerators) :initial-element (/ denominator))))))

(defun beat-unit (meter)
  "The common beat duration, or NIL when the beats differ (2+3/8)."
  (let ((beats (meter-beats meter)))
    (and (every (lambda (beat) (= beat (first beats))) beats)
         (first beats))))

;;; Kernel: the metric tree ---------------------------------------------------
;;;
;;; The hierarchy of the file header is a tree of spans. A node is
;;; (START DURATION LEVEL) in bar positions. Its children tile it in time order,
;;; and the start of every child but the first weighs LEVEL. A tier is
;;; (WEIGHT . NODES): the children of one node and the weight of their starts.
;;;   bar             → beat groups, tier weight 1 (an additive meter's beats, or
;;;                     pairs of 4 or more equal beats of an even count), else
;;;                     the beats, tier weight 2
;;;   group, level 2  → its 2 beats
;;;   beat, level 3   → s parts, s = the beat's numerator in lowest terms when
;;;                     it is > 1 (3 for a dotted beat, 5 for 5/8), else 2
;;;   cell, level 4-8 → 2 halves
;;;   cell, level 9   → a leaf
;;; Below a beat of duration D at b, the starts that first appear in the tier of
;;; weight 3+j are the multiples of D / (s * 2^j) after b on no coarser grid,
;;; which is the header's 3+j. A point that is no node's start weighs 9.
;;; METRIC-WEIGHT and the tie splitter's search both descend this tree, so
;;; %BAR-TIER and %NODE-TIER are the only definition of the hierarchy.

(defun %bar-tier (meter)
  "The children of the bar of METER as a tier (see the comment above)."
  (let* ((beats (meter-beats meter))
         (count (length beats))
         (additive (eq :additive (%meter-kind meter)))
         ;; Only non-additive beats pair up, and those are always equal.
         (paired (and (not additive) (>= count 4) (evenp count))))
    (cons (if (or additive paired) 1 2)
          (loop with start = 0
                for duration in (if paired
                                    (make-list (/ count 2)
                                               :initial-element (* 2 (first beats)))
                                    beats)
                collect (list start duration (if paired 2 3))
                do (incf start duration)))))

(defun %node-tier (node)
  "The children of NODE as a tier, or NIL when NODE is a leaf."
  (destructuring-bind (start duration level) node
    (when (< level +off-grid-weight+)
      (let* ((parts (if (and (= level 3) (> (numerator duration) 1)) (numerator duration) 2))
             (step (/ duration parts)))
        (cons level
              (loop for k below parts
                    collect (list (+ start (* k step)) step (1+ level))))))))

(defun %node-at (tier p)
  "The node of TIER that contains P: the last one starting at or before P."
  (find-if (lambda (node) (<= (first node) p)) (rest tier) :from-end t))

(defun %tier-weight (tier p)
  "METRIC-WEIGHT of the bar position P, 0 <= P < bar, where TIER is the bar tier."
  (if (zerop p)
      0
      (loop (let ((node (%node-at tier p)))
              (when (= p (first node))
                (return (car tier)))
              (setf tier (or (%node-tier node)
                             (return +off-grid-weight+)))))))

(defun %lowest-interior (tier s e)
  "The earliest point p with S < p < E whose weight is the lowest among the
points of weight 8 or less there, and that weight; NIL when there is none.
0 <= S < E <= bar, and TIER is the bar tier.
No boundary inside a node weighs less than the starts of its children, so the
answer is the first child start after S of the deepest node containing [S, E]."
  (loop (let ((next (find-if (lambda (node) (< s (first node))) (rest tier))))
          (when (and next (< (first next) e))
            (return (values (first next) (car tier))))
          (setf tier (or (%node-tier (%node-at tier s))
                         (return nil))))))

(defun %beat-start-weight-p (weight)
  "True for the weight of a beat start: 0 downbeat, 1 group start, 2 other beat.
Every other point weighs 3 or more."
  (<= weight 2))

(defun metric-weight (meter offset)
  "Integer level of OFFSET in METER, 0 = downbeat, larger = weaker (file
header). OFFSET is reduced modulo the bar first."
  (check-type offset rational)
  (%tier-weight (%bar-tier meter) (mod offset (meter-measure-duration meter))))

;;; Text ----------------------------------------------------------------------

(defun %scan-natural (text start fail)
  "The ASCII-digit run at START in TEXT as an integer, and the index after it.
FAIL never returns."
  (let ((stop (or (position-if-not #'%ascii-digit-p text :start start)
                  (length text))))
    (when (= start stop)
      (funcall fail "expected digits"))
    ;; Only validated ASCII digits reach PARSE-INTEGER: no sign, no blanks.
    (values (parse-integer text :start start :end stop) stop)))

(defun %scan-meter (text fail)
  "Read numerator {\"+\" numerator} \"/\" denominator, the whole of TEXT.
Returns the numerators and the denominator. FAIL never returns."
  (let ((numerators '())
        (index 0))
    (loop (multiple-value-bind (n next) (%scan-natural text index fail)
            (unless (<= 1 n +max-meter-numerator+)
              (funcall fail "numerator out of range"))
            (push n numerators)
            (when (= next (length text))
              (funcall fail "missing /"))
            (setf index (1+ next))
            (case (char text next)
              (#\+ nil)
              (#\/ (return))
              (t (funcall fail "expected + or /")))))
    (multiple-value-bind (denominator next) (%scan-natural text index fail)
      (unless (= next (length text))
        (funcall fail "trailing characters"))
      (unless (member denominator +meter-denominators+)
        (funcall fail "unsupported denominator"))
      (values (nreverse numerators) denominator))))

(defun parse-meter (string)
  "Parse STRING (see the file header) into a METER."
  (check-type string string)
  (flet ((fail (reason)
           (return-from parse-meter
             (%parse-failure 'invalid-meter string reason #'parse-meter))))
    (let* ((text (string-trim +pitch-whitespace+ string))
           (symbol (assoc text +meter-symbols+ :test #'string=)))
      (if symbol
          (destructuring-bind (numerators denominator) (rest symbol)
            (make-meter :numerators (copy-list numerators) :denominator denominator))
          (multiple-value-bind (numerators denominator) (%scan-meter text #'fail)
            (make-meter :numerators numerators :denominator denominator))))))

(defun meter-string (meter)
  "Print METER as \"4/4\" or \"2+3/8\": the numerators joined by +, then / and
the denominator. Never \"C\"."
  (format nil "~{~D~^+~}/~D" (meter-numerators meter) (meter-denominator meter)))
