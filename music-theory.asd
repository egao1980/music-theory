(defsystem "music-theory"
  :version "0.6.0"
  :description "Music theory for cl-stack: spelled pitch, intervals, keys, meter, chord symbols, Roman numerals, spelling, key detection and key fit with a tuning offset"
  :author "egao1980"
  :license "MIT"
  :pathname "src"
  :serial t
  :components ((:file "package")
               (:file "conditions")
               (:file "pitch")
               (:file "fifths")
               (:file "interval")
               (:file "meter")
               (:file "time")
               (:file "tempo")
               (:file "key")
               (:file "chord")
               (:file "roman")
               (:file "chord-symbol")
               (:file "chord-tones")
               (:file "key-detect")
               (:file "key-fit")
               (:file "spell")
               (:file "transpose"))
  :in-order-to ((test-op (test-op "music-theory/tests"))))

(defsystem "music-theory/tests"
  :depends-on ("music-theory" (:version "rove" "0.11.1"))
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "mt0-test")
               (:file "mt1-test")
               (:file "mt2-test")
               (:file "mt3-test")
               (:file "mt4-test")
               (:file "mt51-test")
               (:file "mt52-test")
               (:file "mt5-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
