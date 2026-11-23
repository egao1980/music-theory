(defpackage #:music-theory/tests
  (:use #:cl #:rove #:music-theory))

(in-package #:music-theory/tests)

(defun fixture (name)
  "Read the single top-level list in tests/fixtures/NAME (strings, integers, NIL)."
  (with-open-file (in (asdf:system-relative-pathname "music-theory/tests"
                                                     (format nil "tests/fixtures/~A" name))
                      :external-format :utf-8)
    (with-standard-io-syntax
      (let ((*read-eval* nil)
            (*package* (find-package '#:music-theory/tests)))
        (read in)))))

(defmacro collect-mismatches ((row rows) &body checks)
  "Run CHECKS (forms returning true when the ROW passes) over ROWS; return the
failing rows, each paired with the list of failed check indices."
  (let ((bad (gensym)) (fails (gensym)))
    `(let ((,bad '()))
       (dolist (,row ,rows (nreverse ,bad))
         (let ((,fails '()))
           ,@(loop for c in checks for i from 0
                   collect `(unless (ignore-errors ,c) (push ,i ,fails)))
           (when ,fails (push (list ,row (nreverse ,fails)) ,bad)))))))

(defun report (bad)
  (format nil "~D mismatches~@[, first: ~S~]" (length bad)
          (and bad (subseq bad 0 (min 8 (length bad))))))

(defun signals-with-text (thunk type text)
  "True when THUNK signals a condition of TYPE whose MUSIC-THEORY-ERROR-TEXT is TEXT."
  (handler-case (progn (funcall thunk) nil)
    (condition (c) (and (typep c type) (equal (music-theory-error-text c) text)))))
