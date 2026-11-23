(defpackage #:music-theory/tests
  (:use #:cl #:rove))

(in-package #:music-theory/tests)

(deftest skeleton-loads
  (ok (find-package '#:music-theory)))
