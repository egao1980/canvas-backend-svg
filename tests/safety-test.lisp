(in-package #:canvas-backend-svg/tests)

;;; Escaping, CSP, freeze, accessibility, ids.

(defparameter +hostile+ "<script>alert(1)</script> & \"q\" 'a'")

(defun gallery ()
  "One chart per kind plus the scale and degenerate cases, for the scans."
  (list (line-chart) (scatter-chart) (bar-chart) (histogram-chart)
        (chart :line :title +hostile+ :description +hostile+
                     :series (list (series +hostile+ '((0 . 1) (1 . 2)) :labels (list +hostile+ "</title>"))
                                   (series "b" '((0 . 2))))
                     :x-axis (axis :label +hostile+) :y-axis (axis :label "</text><script>"))
        (chart :bar :series (list (series "s" (list (cons +hostile+ 1) (cons "</text>" 2)))))
        (chart :scatter :series (list (series "s" '((1 . 1) (2 . 1000)))) :y-axis (axis :scale :log))
        (chart :line :series (list (series "t" (list (cons (ut 2026 1 1) 1) (cons (ut 2026 2 1) 2))))
                     :x-axis (axis :scale :time))
        (chart :histogram :series (list (series "h" '())))
        (chart :line :series (list (series "e" '())) :width 1 :height 1)))

(deftest hostile-title-and-description
  (let* ((c (chart :line :title +hostile+ :description +hostile+
                         :series (list (series "a" '((0 . 1) (1 . 2))))))
         (html (svg c)))
    (ok (not (contains "<script" html)))
    (ok (contains "&lt;script&gt;alert(1)&lt;/script&gt; &amp; \"q\" 'a'</title>" html))
    (ok (contains "&lt;script&gt;alert(1)&lt;/script&gt; &amp; \"q\" 'a'</desc>" html))
    (ok (contains "<figcaption>&lt;script&gt;" html))
    (ok (string= (chart-id c) "chart-script-alert-1-script-q-a"))
    (ok (contains (q "id='chart-script-alert-1-script-q-a'") html))))

(deftest hostile-labels
  (let ((html (svg (fifth (gallery)))))
    (ok (not (contains "<script" html)))
    (ok (= (occurrences "<text" html) (occurrences "</text>" html)))
    (ok (= (occurrences "<title" html) (occurrences "</title>" html)))
    (ok (contains "<title>&lt;/title&gt;</title>" html) "series label escaped")
    (ok (contains "&lt;/text&gt;&lt;script&gt;</text>" html) "axis label escaped")
    ;; Legend (two series) shows the hostile series name as text.
    (ok (contains "&lt;script&gt;alert(1)&lt;/script&gt; &amp; \"q\" 'a'</text>" html)))
  (let ((html (svg (sixth (gallery)))))
    (ok (not (contains "<script" html)))
    (ok (contains ">&lt;/text&gt;</text>" html) "category escaped")
    (ok (contains "<title>&lt;/text&gt;, 2</title>" html))))

(deftest csp-clean
  (dolist (c (gallery))
    (let ((n (node c))
          (html (svg c)))
      (ok (null (canvas:csp-violations n)) (format nil "~(~A~) chart: no CSP violation" (canvas:chart-kind c)))
      (ok (not (contains " style=" html)))
      (ok (not (contains "<style" html)))
      (ok (not (contains "href" html)))
      (ok (not (contains "<script" html)))
      (ok (not (contains "http" html)) "no URL at all (not even xmlns)"))))

(defun frozen-charts ()
  (canvas:render (list (line-chart) (bar-chart))))

(deftest freeze-keeps-svg
  (let ((doc (let ((canvas:*chart-backend* *svg-backend*))
               (canvas:freeze 'frozen-charts :title "charts"))))
    (ok (contains "<body data-canvas-frozen" doc))
    (ok (= 2 (occurrences "<svg " doc)))
    (ok (search (q "viewBox='0 0 200 120'") doc :test #'char-equal) "viewBox kept (case aside)")
    (ok (contains (q "points='72,64 128,16 184,40'") doc))
    (ok (contains "<title id=\"chart-sales-title\">Sales</title>" doc))
    (ok (contains "data-series=\"2\"" doc))
    (ok (not (contains "http:" doc)))
    (ok (not (contains "https:" doc)))
    (ok (not (contains "<script" doc)))
    (ok (string= doc (let ((canvas:*chart-backend* *svg-backend*))
                       (canvas:freeze 'frozen-charts :title "charts"))))))

(deftest accessibility
  (dolist (c (gallery))
    (let* ((figure (node c))
           (svg (first (child-elements figure)))
           (kids (child-elements svg))
           (id (attr svg "id")))
      (ok (string-equal "figure" (stack-html:html-element-name figure)))
      (ok (string= (attr figure "data-chart") (string-downcase (canvas:chart-kind c))))
      (ok (string-equal "svg" (stack-html:html-element-name svg)))
      (ok (string= (attr svg "role") "img"))
      (ok (string= (attr svg "aria-labelledby") (s+ id "-title " id "-desc")))
      (ok (string-equal "title" (stack-html:html-element-name (first kids))) "title first")
      (ok (string= (attr (first kids) "id") (s+ id "-title")))
      (ok (string-equal "desc" (stack-html:html-element-name (second kids))) "desc second")
      (ok (string= (attr (second kids) "id") (s+ id "-desc")))
      (ok (null (attr svg "width")) "responsive: no width attribute")
      (ok (null (attr svg "height")))
      (ok (string= (attr svg "viewBox")
                   (format nil "0 0 ~D ~D" (canvas:chart-width c) (canvas:chart-height c))))
      ;; Every mark carries its tooltip.
      (dolist (mark (append (elements-named svg "circle") (elements-named svg "rect")))
        (unless (attr mark "data-series")       ; legend swatches are not marks
          (ok (let ((k (child-elements mark)))
                (and (= 1 (length k))
                     (string-equal "title" (stack-html:html-element-name (first k)))))))))))

(deftest default-title-and-description
  (let ((html (svg (chart :bar :series (list (series "only" '(("a" . 1))))))))
    (ok (contains "<title id=\"chart-bar-title\">Bar chart</title>" html))
    (ok (contains "<desc id=\"chart-bar-desc\">Bar chart of 1 series: only (1 bar).</desc>" html))
    (ok (not (contains "<figcaption" html)) "no title -> no figcaption")))

(deftest chart-ids
  (ok (string= (chart-id (line-chart)) "chart-temps"))
  (ok (string= (chart-id (scatter-chart)) "chart-scatter"))
  (ok (string= (chart-id (chart :line :title "  Été ++ 2026 Q1!  " :series (list (series "a" '()))))
               "chart-t-2026-q1"))
  (ok (string= (chart-id (chart :line :title "???" :series (list (series "a" '()))))
               "chart-line"))
  (ok (string= (chart-id (chart :line :title (make-string 50 :initial-element #\x)
                                :series (list (series "a" '()))))
               (s+ "chart-" (make-string 32 :initial-element #\x))))
  (let ((html (svg (bar-chart) :id "sales_q1")))
    (ok (contains "<svg id=\"sales_q1\"" html))
    (ok (contains "aria-labelledby=\"sales_q1-title sales_q1-desc\"" html)))
  (ok (signals (svg (bar-chart) :id "1bad") 'canvas:canvas-error))
  (ok (signals (svg (bar-chart) :id "a b") 'canvas:canvas-error))
  (ok (signals (svg (bar-chart) :id "") 'canvas:canvas-error)))
