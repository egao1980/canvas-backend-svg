(defsystem "canvas-backend-svg"
  :version "0.1.0"
  :description "Pure-Lisp SVG chart backend for canvas-protocol (H4h-1)"
  :author "egao1980"
  :license "MIT"
  :depends-on ((:version "canvas-protocol" "0.1.0")
               (:version "html-protocol" "0.1.1")
               (:version "datetime-protocol" "0.1.3"))
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "conditions")
               (:file "format")
               (:file "ticks")
               (:file "palette")
               (:file "render"))
  :in-order-to ((test-op (test-op "canvas-backend-svg/tests"))))

(defsystem "canvas-backend-svg/tests"
  :depends-on ("canvas-backend-svg" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "golden-test")
               (:file "ticks-test")
               (:file "scale-test")
               (:file "safety-test")
               (:file "theme-test")
               (:file "degenerate-test")
               (:file "registration-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
