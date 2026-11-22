(in-package #:canvas-backend-svg/tests)

;;; Colour comes from the theme: no colour literal in the SVG, series indexed by
;;; data-series, marks in currentColor, PALETTE-CSS for the themes.

(defun colour-literal-p (html)
  (or (contains "#" html) (contains "rgb(" html) (contains "hsl(" html)
      (some (lambda (name) (contains (format nil "\"~A\"" name) html))
            '("black" "white" "red" "green" "blue" "orange" "gray" "grey"))))

(defun nine-series-chart ()
  (chart :line :series (loop for i from 0 below 9
                             collect (series (format nil "s~D" i) (list (cons 0 i) (cons 1 i))))))

(deftest no-fixed-colours
  (dolist (c (list (line-chart) (scatter-chart) (bar-chart) (histogram-chart) (nine-series-chart)))
    (let ((html (svg c)))
      (ok (not (colour-literal-p html)) (format nil "~(~A~): no colour literal" (canvas:chart-kind c)))
      (ok (not (contains " color=" html)) "no color attribute without a series COLOR")
      (ok (not (contains "fill=\"#" html)))
      (ok (not (contains "stroke=\"#" html))))))

(deftest series-index-cycle
  (let* ((n (node (nine-series-chart)))
         (groups (remove-if-not (lambda (e) (and (string-equal "g" (stack-html:html-element-name e))
                                                 (attr e "data-series")))
                                (elements-named n "g")))
         (swatches (remove-if-not (lambda (e) (attr e "data-series")) (elements-named n "rect"))))
    (ok (equal (mapcar (lambda (g) (attr g "data-series")) groups)
               '("1" "2" "3" "4" "5" "6" "7" "8" "1")))
    (ok (equal (mapcar (lambda (r) (attr r "data-series")) swatches)
               '("1" "2" "3" "4" "5" "6" "7" "8" "1"))
        "legend swatches use the same index")
    (dolist (g groups)
      (dolist (mark (child-elements g))
        (ok (or (equal (attr mark "fill") "currentColor")
                (equal (attr mark "stroke") "currentColor")))))))

(deftest series-colour-override
  (let* ((c (chart :bar :series (list (series "a" '(("x" . 1)) :color "#123456")
                                      (series "b" '(("x" . 2)))
                                      (series "c" '(("x" . 3)) :color "rebeccapurple"))))
         (html (svg c)))
    (ok (contains "<g data-series=\"1\" color=\"#123456\">" html))
    (ok (contains "<g data-series=\"2\">" html))
    (ok (contains "<g data-series=\"3\" color=\"rebeccapurple\">" html))
    (ok (contains "<rect data-series=\"1\" color=\"#123456\" x=" html) "legend swatch too")
    (ok (null (canvas:csp-violations (node c)))))
  (dolist (bad '("red; x" "#12345" "#ggg" "url(#a)" "RED" ""))
    (ok (signals (svg (chart :line :series (list (series "a" '((0 . 0)) :color bad))))
                 'canvas:invalid-chart)
        (format nil "colour ~S refused" bad)))
  (ok (eq :series (handler-case (svg (chart :line :series (list (series "a" '((0 . 0)) :color "x;y"))))
                    (canvas:invalid-chart (e) (canvas:invalid-chart-field e))))))

(deftest palette-css-rules
  (let* ((css (palette-css))
         (lines (loop for start = 0 then (1+ end)
                      for end = (position #\Newline css :start start)
                      while end collect (subseq css start end))))
    (ok (= 8 (length lines)))
    (ok (char= #\Newline (char css (1- (length css)))))
    (ok (string= (first lines)
                 "figure[data-chart] [data-series=\"1\"]:not([color]) { color: var(--chart-1, #E69F00); }"))
    (loop for colour in canvas:*chart-palette*
          for n from 1
          for line in lines
          do (ok (string= line (format nil "figure[data-chart] [data-series=\"~D\"]:not([color]) { color: var(--chart-~D, ~A); }" n n colour)))))
  (ok (string= (palette-css '("#000" "#fff"))
               (format nil "figure[data-chart] [data-series=\"1\"]:not([color]) { color: var(--chart-1, #000); }~%figure[data-chart] [data-series=\"2\"]:not([color]) { color: var(--chart-2, #fff); }~%")))
  (ok (signals (palette-css '(1 2)) 'type-error)))

(deftest palette-length-follows-protocol
  ;; The index cycles with the length of canvas:*chart-palette*.
  (let ((canvas:*chart-palette* '("#000" "#111" "#222")))
    (let ((groups (remove-if-not (lambda (e) (attr e "data-series"))
                                 (elements-named (node (nine-series-chart)) "g"))))
      (ok (equal (mapcar (lambda (g) (attr g "data-series")) groups)
                 '("1" "2" "3" "1" "2" "3" "1" "2" "3"))))))
