(defsystem "canvas-backend-svg"
  :version "0.0.0"
  :description "Pure-Lisp SVG chart backend for canvas-protocol (H4h-1)"
  :author "egao1980"
  :license "MIT"
  :depends-on ()
  :serial t
  :pathname "src"
  :components ((:file "package"))
  :in-order-to ((test-op (test-op "canvas-backend-svg/tests"))))

(defsystem "canvas-backend-svg/tests"
  :depends-on ("canvas-backend-svg" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
