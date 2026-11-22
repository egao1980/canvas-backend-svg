(in-package #:canvas-backend-svg/tests)

;;; Loading the system registers the backend with canvas-protocol.

(deftest backend-class
  (ok (typep *svg-backend* 'svg-backend))
  (ok (typep *svg-backend* 'canvas:chart-backend))
  (ok (typep (make-svg-backend) 'svg-backend))
  (ok (find-method #'canvas:render-chart '() (list (find-class 'svg-backend) (find-class t)) nil)))

(deftest registered-by-load
  (ok (eq canvas:*chart-backend* *svg-backend*)))

(deftest render-chart-dispatch
  (let ((n (canvas:render-chart (make-svg-backend) (line-chart))))
    (ok (typep n 'stack-html:html-element))
    (ok (string-equal "figure" (stack-html:html-element-name n)))
    (ok (string= +line-golden+ (canvas:to-html n)))))

(deftest render-through-protocol
  (let ((canvas:*chart-backend* *svg-backend*))
    (ok (string= +bar-golden+ (canvas:to-html (canvas:chart-node (bar-chart)))))
    (ok (string= +bar-golden+ (canvas:to-html (bar-chart))) "RENDER of a chart")
    (ok (string= +bar-golden+ (canvas:to-html (canvas:chart-node (bar-chart) :backend (make-svg-backend))))))
  (ok (signals (canvas:render-chart *svg-backend* (make-instance 'canvas:chart :kind :pie :series '()))
               'canvas:invalid-chart)
      "the chart is validated"))
