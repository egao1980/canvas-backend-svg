(in-package #:canvas-backend-svg/tests)

;;; Empty and degenerate data never signal; they render something sensible.

(deftest empty-series
  (let ((html (svg (chart :line :series (list (series "e" '()))))))
    (ok (not (contains "<polyline" html)))
    (ok (not (contains "<circle" html)))
    (ok (contains "<g data-series=\"1\"></g>" html))
    (ok (contains "Line chart of 1 series: e (0 points)." html))
    ;; Both domains default to [0, 1].
    (ok (equal (text-labels html) '("0.0" "0.2" "0.4" "0.6" "0.8" "1.0"
                                    "0.0" "0.2" "0.4" "0.6" "0.8" "1.0")))))

(deftest single-point
  (let ((html (svg (chart :line :series (list (series "p" '((3 . 4))))))))
    (ok (not (contains "<polyline" html)) "a line needs two points")
    (ok (= 1 (occurrences "<circle" html)))
    (ok (equal (tooltips html) '("3, 4")))
    (ok (contains "(1 point)." html))))

(deftest equal-values
  (let ((html (svg (chart :scatter :series (list (series "s" '((1 . 5) (2 . 5))))
                                   :x-axis (axis :ticks '(1 2))))))
    (ok (equal (text-labels html) '("1" "2" "4.4" "4.6" "4.8" "5.0" "5.2" "5.4" "5.6")))))

(deftest tiny-canvas
  (let ((html (svg (chart :scatter :series (list (series "s" '((0 . 0) (1 . 1))))
                                   :width 1 :height 1))))
    (ok (contains "viewBox=\"0 0 1 1\"" html))
    (ok (= 2 (occurrences "<circle" html)))))

(deftest negative-bars
  ;; Domain [-2, 3] (0 included); H 360: YB 320, YT 16, y = 320 - 304 (v + 2) / 5,
  ;; base 0 -> 198. W 640: X0 56, X1 624, two bands of 284, inset 28.4.
  (let ((html (svg (chart :bar :series (list (series "v" '(("neg" . -2) ("pos" . 3))))))))
    (ok (contains "<rect x=\"84\" y=\"198\" width=\"228\" height=\"122\" fill=\"currentColor\"><title>neg, -2</title></rect>" html))
    (ok (contains "<rect x=\"368\" y=\"16\" width=\"228\" height=\"182\" fill=\"currentColor\"><title>pos, 3</title></rect>" html))))

(deftest bar-missing-category
  (let* ((c (chart :bar :series (list (series "a" '(("x" . 1) ("y" . 2)))
                                      (series "b" '(("y" . 3))))))
         (n (node c))
         (groups (remove-if-not (lambda (e) (attr e "data-series")) (elements-named n "g"))))
    (ok (= 2 (length (elements-named (first groups) "rect"))))
    (ok (= 1 (length (elements-named (second groups) "rect"))))
    (ok (equal (tooltips (svg c)) '("x, 1" "y, 2" "y, 3")))))

(deftest histogram-degenerate
  (ok (equal (tooltips (svg (chart :histogram :series (list (series "h" '(3 3 3))) :bins 4)))
             '("2.5 to 2.75: 0" "2.75 to 3: 0" "3 to 3.25: 3" "3.25 to 3.5: 0")))
  (let ((tips (tooltips (svg (chart :histogram :series (list (series "h" '())))))))
    (ok (= 10 (length tips)))
    (ok (string= (first tips) "0 to 0.1: 0"))
    (ok (string= (car (last tips)) "0.9 to 1: 0")))
  ;; The maximum lands in the last bin; values outside MIN/MAX are not counted.
  (ok (equal (tooltips (svg (chart :histogram :series (list (series "h" '(-5 0 1 2 2 9)))
                                              :bins 2 :x-axis (axis :min 0 :max 2))))
             '("0 to 1: 1" "1 to 2: 3"))))

(deftest legend-modes
  (flet ((swatches (c) (remove-if-not (lambda (e) (attr e "data-series")) (elements-named (node c) "rect"))))
    (ok (null (swatches (chart :line :series (list (series "a" '((0 . 0))))))) ":auto, one series")
    (ok (= 1 (length (swatches (chart :line :legend t :series (list (series "a" '((0 . 0)))))))) "T")
    (ok (null (swatches (chart :line :legend nil
                                     :series (list (series "a" '((0 . 0))) (series "b" '((0 . 1)))))))
        "NIL")
    (ok (= 2 (length (swatches (chart :scatter :series (list (series "a" '((0 . 0)))
                                                             (series "b" '((0 . 1)))))))))))
