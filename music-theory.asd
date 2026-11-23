(defsystem "music-theory"
  :version "0.1.0"
  :description "Music theory for cl-stack: spelled pitch, intervals, keys, meter, chord symbols, Roman numerals"
  :author "egao1980"
  :license "MIT"
  :pathname "src"
  :serial t
  :components ((:file "package")
               (:file "conditions")
               (:file "pitch")
               (:file "fifths")
               (:file "interval"))
  :in-order-to ((test-op (test-op "music-theory/tests"))))

(defsystem "music-theory/tests"
  :depends-on ("music-theory" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "mt0-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
