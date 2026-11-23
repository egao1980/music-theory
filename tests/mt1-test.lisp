;;;; MT1: meters, the metric hierarchy, dots and tuplets, tie splitting, tempo.
;;;; Expected values follow the rules in src/meter.lisp, src/time.lisp and
;;;; src/tempo.lisp. They were cross-checked against an independent reference
;;;; implementation of those rules (5120 split cases, no mismatches).

(in-package #:music-theory/tests)

(defun m (s) (parse-meter s))

;;; Meters --------------------------------------------------------------------

(deftest-parametrize parse-meter-accepts
    ((text numerators denominator)
     ("4/4" '(4) 4) ("3/4" '(3) 4) ("6/8" '(6) 8) ("12/8" '(12) 8) ("5/4" '(5) 4)
     ("2/2" '(2) 2) ("9/8" '(9) 8) ("2+3/8" '(2 3) 8) ("3+2+2/8" '(3 2 2) 8)
     ("C" '(4) 4) ("C|" '(2) 2) (" 3/4 " '(3) 4) ("1/1" '(1) 1) ("64/64" '(64) 64))
  (ok (equalp (make-meter :numerators numerators :denominator denominator)
              (parse-meter text))))

(deftest-parametrize parse-meter-rejects
    ((text)
     ("") ("4") ("4/3") ("4/0") ("0/4") ("x/4") ("4/4/4") ("2+/8") ("+3/8")
     ("65/4") ("4/128") ("c") ("C |") ("-4/4") ("4 /4"))
  (ok (signals-with-text (lambda () (parse-meter text)) 'invalid-meter text)))

(deftest parse-meter-use-value-restart
  (let ((fallback (make-meter :numerators '(3) :denominator 4)))
    (ok (equalp fallback
                (handler-bind ((invalid-meter (lambda (c) (use-value fallback c))))
                  (parse-meter "4/3"))))))

(deftest-parametrize meter-strings
    ((text expected)
     ("4/4" "4/4") ("C" "4/4") ("C|" "2/2") ("2+3/8" "2+3/8") ("12/8" "12/8"))
  (ok (string= expected (meter-string (m text)))))

(deftest-parametrize meter-shape
    ((text bar compound beats unit)
     ("4/4" 1 nil '(1/4 1/4 1/4 1/4) 1/4)
     ("3/4" 3/4 nil '(1/4 1/4 1/4) 1/4)
     ("2/2" 1 nil '(1/2 1/2) 1/2)
     ("5/4" 5/4 nil '(1/4 1/4 1/4 1/4 1/4) 1/4)
     ("3/8" 3/8 nil '(1/8 1/8 1/8) 1/8)
     ("6/8" 3/4 t '(3/8 3/8) 3/8)
     ("9/8" 9/8 t '(3/8 3/8 3/8) 3/8)
     ("12/8" 3/2 t '(3/8 3/8 3/8 3/8) 3/8)
     ("6/4" 3/2 t '(3/4 3/4) 3/4)
     ("2+3/8" 5/8 nil '(1/4 3/8) nil)
     ("3+2+2/8" 7/8 nil '(3/8 1/4 1/4) nil))
  (ok (eql bar (meter-measure-duration (m text))))
  (ok (eq compound (and (compound-p (m text)) t)))
  (ok (equal beats (meter-beats (m text))))
  (ok (eql unit (beat-unit (m text)))))

(deftest-parametrize metric-weights
    ((text step weights)
     ("4/4" 1/16 '(0 4 3 4 2 4 3 4 1 4 3 4 2 4 3 4))
     ("3/4" 1/8 '(0 3 2 3 2 3))
     ("2/2" 1/8 '(0 4 3 4 2 4 3 4))
     ("5/4" 1/8 '(0 3 2 3 2 3 2 3 2 3))
     ("6/8" 1/16 '(0 4 3 4 3 4 2 4 3 4 3 4))
     ("9/8" 1/8 '(0 3 3 2 3 3 2 3 3))
     ("12/8" 1/8 '(0 3 3 2 3 3 1 3 3 2 3 3))
     ("2+3/8" 1/8 '(0 3 1 3 3)))
  (ok (equal weights
             (loop for k below (length weights) collect (metric-weight (m text) (* k step))))))

(deftest-parametrize additive-beat-subdivision
    ((text step weights)
     ;; music-theory#7: a beat of n/den with n > 1 splits into its n units.
     ("3+5/8" 1/8 '(0 3 3 1 3 3 3 3))
     ("2+2+3/8" 1/8 '(0 3 1 3 1 3 3))
     ("5+2/8" 1/16 '(0 4 3 4 3 4 3 4 3 4 1 4 3 4)))
  (ok (equal weights
             (loop for k below (length weights) collect (metric-weight (m text) (* k step))))))

(deftest-parametrize additive-five-eighth-splits
    ((duration offset pieces)
     (1/8 1/2 '(1/8)) (1/4 3/8 '(1/4)) (1/4 1/2 '(1/4)) (3/8 1/2 '(3/8)) (5/8 3/8 '(1/8 1/2)))
  (ok (equal pieces (split-duration duration :meter (m "3+5/8") :offset offset))))

(deftest metric-weight-edges
  (ok (= 9 (metric-weight (m "4/4") 1/12)) "a triplet position is off every grid")
  (ok (= 2 (metric-weight (m "4/4") -1/4)) "a pickup quarter is beat 4")
  (ok (= 1 (metric-weight (m "4/4") 3/2)) "offsets reduce modulo the bar")
  (ok (= 0 (metric-weight (m "6/8") 3/4)))
  (ok (loop for text in '("4/4" "3/4" "6/8" "12/8" "2+3/8" "5/4")
            for meter = (m text)
            always (loop for k below 64
                         for w = (metric-weight meter (/ k 64))
                         always (and (integerp w) (<= 0 w 9))))))

;;; Dots and tuplets --------------------------------------------------------

(deftest-parametrize dots
    ((duration max-dots tuplet base n)
     (1/4 3 nil 1/4 0) (3/8 3 nil 1/4 1) (7/16 3 nil 1/4 2) (15/32 3 nil 1/4 3)
     (7/16 1 nil nil nil) (5/16 3 nil nil nil) (2 3 nil 2 0) (3 3 nil 2 1)
     (1/128 3 nil 1/128 0) (1/256 3 nil nil nil) (1/12 3 nil nil nil)
     (1/12 3 3/2 1/8 0) (1/6 3 3/2 1/4 0) (1/20 3 5/4 1/16 0) (1/8 3 3/2 1/8 1))
  (multiple-value-bind (b k) (duration-dots duration :max-dots max-dots :tuplet tuplet)
    (ok (eql base b))
    (ok (eql n k))))

(deftest-parametrize tuplets
    ((base ratio dots expected)
     (1/8 3/2 0 1/12) (1/4 3/2 0 1/6) (1/16 5/4 0 1/20) (1/8 3/2 1 1/8) (1/2 3/2 0 1/3))
  (ok (eql expected (tuplet-duration base ratio :dots dots))))

;;; Tie splitting -------------------------------------------------------------

(deftest-parametrize split-durations
    ((meter duration offset max-dots pieces)
     ("4/4" 1 0 1 '(1))
     ("4/4" 3/4 0 1 '(3/4))
     ("4/4" 1/2 1/4 1 '(1/4 1/4))
     ("4/4" 3/8 1/4 1 '(1/4 1/8))
     ("4/4" 3/8 0 1 '(3/8))
     ("4/4" 1/2 1/8 1 '(1/8 1/4 1/8))
     ("4/4" 5/8 0 1 '(1/2 1/8))
     ("4/4" 5/4 0 1 '(1 1/4))
     ("4/4" 1/4 7/8 1 '(1/8 1/8))
     ("4/4" 7/16 0 1 '(1/4 3/16))
     ("4/4" 7/16 0 2 '(7/16))
     ("4/4" 3/4 1/4 1 '(1/4 1/2))
     ("4/4" 1/4 3/8 1 '(1/8 1/8))
     ("4/4" 1/8 1/16 1 '(1/16 1/16))
     ("4/4" 2 1/2 1 '(1/2 1 1/2))
     ("6/8" 3/4 0 1 '(3/4))
     ("6/8" 1/2 0 1 '(3/8 1/8))
     ("6/8" 1/4 1/8 1 '(1/4))
     ("6/8" 1/4 1/4 1 '(1/8 1/8))
     ("6/8" 3/8 3/8 1 '(3/8))
     ("6/8" 9/8 0 1 '(3/4 3/8))
     ("6/8" 3/16 1/16 1 '(1/16 1/8))
     ("3/4" 1/2 1/4 1 '(1/2))
     ("3/4" 3/4 0 1 '(3/4))
     ("3/4" 1/2 1/8 1 '(1/8 3/8))
     ("3/4" 1 1/2 1 '(1/4 3/4))
     ("2/2" 1/2 1/4 1 '(1/4 1/4))
     ("2/2" 3/4 0 1 '(3/4))
     ("2+3/8" 5/8 0 1 '(1/4 3/8))
     ("2+3/8" 1/4 1/8 1 '(1/8 1/8))
     ("2+3/8" 3/8 1/4 1 '(3/8))
     ("12/8" 3/4 3/8 1 '(3/8 3/8))
     ("12/8" 1/2 3/8 1 '(3/8 1/8)))
  (ok (equal pieces (split-duration duration :meter (m meter) :offset offset :max-dots max-dots))))

(deftest split-duration-defaults-to-4/4
  (ok (equal '(1/4 1/4) (split-duration 1/2 :offset 1/4)))
  (ok (equal '(1/2 1/8) (split-duration 5/8))))

(deftest split-duration-properties
  ;; For every meter, duration k/16 (k = 1..40) and offset on the 1/16 grid:
  ;; the pieces sum to the duration, each is notatable with one dot, and none
  ;; crosses a barline.
  (let ((bad '()))
    (dolist (text '("4/4" "3/4" "6/8" "2+3/8" "12/8" "2/2" "5/4" "9/8"))
      (let* ((meter (m text)) (bar (meter-measure-duration meter)))
        (loop for k from 1 to 40
              for d = (/ k 16)
              do (loop for o from 0 below (* bar 16)
                       for offset = (/ o 16)
                       for pieces = (ignore-errors (split-duration d :meter meter :offset offset))
                       do (unless (and pieces
                                       (= d (reduce #'+ pieces))
                                       (every (lambda (p) (duration-dots p :max-dots 1)) pieces)
                                       (loop with at = offset
                                             for p in pieces
                                             always (= (floor at bar) (1- (ceiling (+ at p) bar)))
                                             do (incf at p)))
                            (push (list text d offset pieces) bad))))))
    (ok (null bad) (report bad))))

(deftest split-duration-errors
  (ok (typep (handler-case (split-duration 1/12) (condition (c) c)) 'music-theory-error)
      "a tuplet length can't be notated by splitting")
  (ok (not (typep (handler-case (split-duration 1/12) (condition (c) c)) 'invalid-meter)))
  (ok (music-theory-error-reason (handler-case (split-duration 1/12) (music-theory-error (c) c))))
  (dolist (bad '(0 -1/4 0.25))
    (ok (typep (handler-case (split-duration bad) (condition (c) c)) 'type-error))))

;;; Tempo -----------------------------------------------------------------------

(deftest-parametrize durations-to-seconds
    ((duration bpm beat-unit seconds)
     (1/4 60 1/4 1) (1 120 1/4 2) (3/8 60 3/8 1) (1/8 90 1/4 1/3) (3/4 72 3/8 5/3)
     (1/2 100 1/2 3/5))
  (ok (eql seconds (duration-seconds duration (make-tempo :bpm bpm :beat-unit beat-unit)))))

(deftest-parametrize seconds-to-durations
    ((seconds bpm beat-unit duration)
     (9.5 72 1/4 57/20) (1 60 1/4 1/4) (8 60 3/8 3) (1/3 90 1/4 1/8) (2.5 120 1/4 5/4))
  (ok (eql duration (seconds-duration seconds (make-tempo :bpm bpm :beat-unit beat-unit)))))

(deftest-parametrize phrase-windows
    ((bpm beat-unit seconds grid expected)
     (72 1/4 9.5 nil 57/20) (72 1/4 9.5 1/8 11/4) (60 1/4 8 1/4 2) (60 3/8 8 3/8 3)
     (90 1/4 10 1/2 7/2) (100 1/4 7 1 2))
  (ok (eql expected (max-window-duration (make-tempo :bpm bpm :beat-unit beat-unit) seconds
                                         :grid grid))))

(deftest tempo-round-trips-exactly
  (ok (loop for bpm from 40 to 200 by 7
            always (loop for unit in '(1/4 3/8 1/2)
                         for tempo = (make-tempo :bpm bpm :beat-unit unit)
                         always (loop for d in '(1/16 1/12 1/8 3/16 1/6 1/4 3/8 1/2 3/4 7/8 1 5/4)
                                      for s = (duration-seconds d tempo)
                                      always (and (rationalp s)
                                                  (eql d (seconds-duration s tempo))))))))
