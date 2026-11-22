(in-package #:canvas-backend-svg/tests)

;;; One byte-exact golden per kind. Each is worked out by hand from the rules in
;;; src/render.lisp and src/ticks.lisp; the comments give the arithmetic.

(defun line-chart ()
  ;; Margins: left 72 (y label), top 16, bottom 56 (x label) -> X0 72, X1 184,
  ;; YB 64, YT 16. Domains [0,10] both ways (NICE-TICKS 0 10), explicit ticks.
  ;; x = 72 + 11.2 v, y = 64 - 4.8 v.
  (chart :line :title "Temps"
               :series (list (series "a" '((0 . 0) (5 . 10) (10 . 5))))
               :x-axis (axis :label "Day" :ticks '(0 10))
               :y-axis (axis :label "C" :ticks '(0 10))
               :width 200 :height 120))

(defparameter +line-golden+
  (q (s+ "<figure data-chart='line'><svg id='chart-temps' viewBox='0 0 200 120' role='img' aria-labelledby='chart-temps-title chart-temps-desc' fill='currentColor' font-family='sans-serif' font-size='12'>"
         "<title id='chart-temps-title'>Temps</title>"
         "<desc id='chart-temps-desc'>Line chart of 1 series: a (3 points).</desc>"
         "<g><line x1='72' y1='64' x2='184' y2='64' stroke='currentColor'></line>"
         "<line x1='72' y1='64' x2='72' y2='70' stroke='currentColor'></line><text x='72' y='84' text-anchor='middle'>0</text>"
         "<line x1='184' y1='64' x2='184' y2='70' stroke='currentColor'></line><text x='184' y='84' text-anchor='middle'>10</text>"
         "<text x='128' y='108' text-anchor='middle'>Day</text></g>"
         "<g><line x1='72' y1='64' x2='72' y2='16' stroke='currentColor'></line>"
         "<line x1='66' y1='64' x2='72' y2='64' stroke='currentColor'></line><text x='63' y='68' text-anchor='end'>0</text>"
         "<line x1='66' y1='16' x2='72' y2='16' stroke='currentColor'></line><text x='63' y='20' text-anchor='end'>10</text>"
         "<text transform='translate(16,40) rotate(-90)' text-anchor='middle'>C</text></g>"
         "<g data-series='1'><polyline points='72,64 128,16 184,40' fill='none' stroke='currentColor' stroke-width='2'></polyline>"
         "<circle cx='72' cy='64' r='3' fill='currentColor'><title>0, 0</title></circle>"
         "<circle cx='128' cy='16' r='3' fill='currentColor'><title>5, 10</title></circle>"
         "<circle cx='184' cy='40' r='3' fill='currentColor'><title>10, 5</title></circle></g>"
         "</svg><figcaption>Temps</figcaption></figure>")))

(defun scatter-chart ()
  ;; No title, no axis labels: X0 56, X1 144, YB 60, YT 16. Domains [0,4]
  ;; (NICE-TICKS 0 4: range 5, step 1). x = 56 + 22 v, y = 60 - 11 v.
  ;; Series LABELS replace the default tooltips.
  (chart :scatter
         :series (list (series "s" '((0 . 0) (2 . 4) (4 . 2))
                               :labels '("first" "second" "third")))
         :x-axis (axis :ticks '(0 4))
         :y-axis (axis :ticks '(0 4))
         :width 160 :height 100))

(defparameter +scatter-golden+
  (q (s+ "<figure data-chart='scatter'><svg id='chart-scatter' viewBox='0 0 160 100' role='img' aria-labelledby='chart-scatter-title chart-scatter-desc' fill='currentColor' font-family='sans-serif' font-size='12'>"
         "<title id='chart-scatter-title'>Scatter chart</title>"
         "<desc id='chart-scatter-desc'>Scatter chart of 1 series: s (3 points).</desc>"
         "<g><line x1='56' y1='60' x2='144' y2='60' stroke='currentColor'></line>"
         "<line x1='56' y1='60' x2='56' y2='66' stroke='currentColor'></line><text x='56' y='80' text-anchor='middle'>0</text>"
         "<line x1='144' y1='60' x2='144' y2='66' stroke='currentColor'></line><text x='144' y='80' text-anchor='middle'>4</text></g>"
         "<g><line x1='56' y1='60' x2='56' y2='16' stroke='currentColor'></line>"
         "<line x1='50' y1='60' x2='56' y2='60' stroke='currentColor'></line><text x='47' y='64' text-anchor='end'>0</text>"
         "<line x1='50' y1='16' x2='56' y2='16' stroke='currentColor'></line><text x='47' y='20' text-anchor='end'>4</text></g>"
         "<g data-series='1'>"
         "<circle cx='56' cy='60' r='4' fill='currentColor'><title>first</title></circle>"
         "<circle cx='100' cy='16' r='4' fill='currentColor'><title>second</title></circle>"
         "<circle cx='144' cy='38' r='4' fill='currentColor'><title>third</title></circle></g>"
         "</svg></figure>")))

(defun bar-chart ()
  ;; Two series -> legend (:auto): top 40. X0 56, X1 184, YB 80, YT 40.
  ;; y domain [0,4], y = 80 - 10 v. Two categories: BW 64, inset 6.4, share 25.6.
  ;; x: a 62.4..88 -> 62..88, b 88..113.6 -> 88..114; y: a 126.4..152, b 152..177.6.
  ;; Legend: a at 56 (text 70), next 56 + 14 + 7 + 16 = 93 (text 107).
  (chart :bar :title "Sales"
              :series (list (series "a" '(("x" . 2) ("y" . 4)))
                            (series "b" '(("x" . 4) ("y" . 1))))
              :y-axis (axis :ticks '(0 4))
              :width 200 :height 120))

(defparameter +bar-golden+
  (q (s+ "<figure data-chart='bar'><svg id='chart-sales' viewBox='0 0 200 120' role='img' aria-labelledby='chart-sales-title chart-sales-desc' fill='currentColor' font-family='sans-serif' font-size='12'>"
         "<title id='chart-sales-title'>Sales</title>"
         "<desc id='chart-sales-desc'>Bar chart of 2 series: a (2 bars), b (2 bars).</desc>"
         "<g><line x1='56' y1='80' x2='184' y2='80' stroke='currentColor'></line>"
         "<line x1='88' y1='80' x2='88' y2='86' stroke='currentColor'></line><text x='88' y='100' text-anchor='middle'>x</text>"
         "<line x1='152' y1='80' x2='152' y2='86' stroke='currentColor'></line><text x='152' y='100' text-anchor='middle'>y</text></g>"
         "<g><line x1='56' y1='80' x2='56' y2='40' stroke='currentColor'></line>"
         "<line x1='50' y1='80' x2='56' y2='80' stroke='currentColor'></line><text x='47' y='84' text-anchor='end'>0</text>"
         "<line x1='50' y1='40' x2='56' y2='40' stroke='currentColor'></line><text x='47' y='44' text-anchor='end'>4</text></g>"
         "<g data-series='1'>"
         "<rect x='62' y='60' width='26' height='20' fill='currentColor'><title>x, 2</title></rect>"
         "<rect x='126' y='40' width='26' height='40' fill='currentColor'><title>y, 4</title></rect></g>"
         "<g data-series='2'>"
         "<rect x='88' y='40' width='26' height='40' fill='currentColor'><title>x, 4</title></rect>"
         "<rect x='152' y='70' width='26' height='10' fill='currentColor'><title>y, 1</title></rect></g>"
         "<g><rect data-series='1' x='56' y='6' width='10' height='10' fill='currentColor'></rect><text x='70' y='16'>a</text>"
         "<rect data-series='2' x='93' y='6' width='10' height='10' fill='currentColor'></rect><text x='107' y='16'>b</text></g>"
         "</svg><figcaption>Sales</figcaption></figure>")))

(defun histogram-chart ()
  ;; X0 56, X1 144, YB 60, YT 16. x domain exactly [0,4] (data), 2 bins of 2.
  ;; Counts 3 (0 1 1) and 2 (3 4). y: NICE-TICKS 0 3 -> 0 1 2 3 by 1 (automatic,
  ;; FORMAT-TICK), y = 60 - 44 c / 3 -> 60 45 31 16.
  (chart :histogram
         :series (list (series "h" '(0 1 1 3 4)))
         :bins 2
         :x-axis (axis :ticks '(0 4))
         :width 160 :height 100))

(defparameter +histogram-golden+
  (q (s+ "<figure data-chart='histogram'><svg id='chart-histogram' viewBox='0 0 160 100' role='img' aria-labelledby='chart-histogram-title chart-histogram-desc' fill='currentColor' font-family='sans-serif' font-size='12'>"
         "<title id='chart-histogram-title'>Histogram</title>"
         "<desc id='chart-histogram-desc'>Histogram of 1 series: h (5 values).</desc>"
         "<g><line x1='56' y1='60' x2='144' y2='60' stroke='currentColor'></line>"
         "<line x1='56' y1='60' x2='56' y2='66' stroke='currentColor'></line><text x='56' y='80' text-anchor='middle'>0</text>"
         "<line x1='144' y1='60' x2='144' y2='66' stroke='currentColor'></line><text x='144' y='80' text-anchor='middle'>4</text></g>"
         "<g><line x1='56' y1='60' x2='56' y2='16' stroke='currentColor'></line>"
         "<line x1='50' y1='60' x2='56' y2='60' stroke='currentColor'></line><text x='47' y='64' text-anchor='end'>0</text>"
         "<line x1='50' y1='45' x2='56' y2='45' stroke='currentColor'></line><text x='47' y='49' text-anchor='end'>1</text>"
         "<line x1='50' y1='31' x2='56' y2='31' stroke='currentColor'></line><text x='47' y='35' text-anchor='end'>2</text>"
         "<line x1='50' y1='16' x2='56' y2='16' stroke='currentColor'></line><text x='47' y='20' text-anchor='end'>3</text></g>"
         "<g data-series='1'>"
         "<rect x='56' y='16' width='44' height='44' fill='currentColor'><title>0 to 2: 3</title></rect>"
         "<rect x='100' y='31' width='44' height='29' fill='currentColor'><title>2 to 4: 2</title></rect></g>"
         "</svg></figure>")))

(deftest golden-line
  (ok (string= +line-golden+ (svg (line-chart)))))

(deftest golden-scatter
  (ok (string= +scatter-golden+ (svg (scatter-chart)))))

(deftest golden-bar
  (ok (string= +bar-golden+ (svg (bar-chart)))))

(deftest golden-histogram
  (ok (string= +histogram-golden+ (svg (histogram-chart)))))

(deftest determinism
  (dolist (make '(line-chart scatter-chart bar-chart histogram-chart))
    (let ((a (svg (funcall make)))
          (b (svg (funcall make))))
      (ok (string= a b) (format nil "~(~A~) twice" make))
      ;; Printer variables never leak into the output.
      (ok (string= a (let ((*print-base* 16) (*print-radix* t) (*print-pretty* t)
                           (*read-default-float-format* 'double-float))
                       (svg (funcall make))))
          (format nil "~(~A~) under odd printer settings" make)))))
