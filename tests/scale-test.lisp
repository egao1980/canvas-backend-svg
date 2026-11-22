(in-package #:canvas-backend-svg/tests)

;;; Log and time scales, axis bounds, explicit ticks, axis FORMAT.

(deftest log-ticks-cases
  (ok (equal (multiple-value-list (log-ticks 3 2000)) '((1 10 100 1000 10000) 1 10000)))
  (ok (equal (multiple-value-list (log-ticks 1/1000 1/10)) '((1/1000 1/100 1/10) 1/1000 1/10)))
  (ok (equal (multiple-value-list (log-ticks 100 100)) '((100 1000) 100 1000)))
  (ok (equal (multiple-value-list (log-ticks nil nil)) '((1 10) 1 10)))
  (ok (equal (multiple-value-list (log-ticks 2000 3)) (multiple-value-list (log-ticks 3 2000))))
  (ok (equal (first (multiple-value-list (log-ticks 0.5d0 50))) '(1/10 1 10 100))))

(deftest log-labels
  (ok (equal (mapcar #'format-log-tick '(1 10 100 1000 1000000))
             '("1" "10" "100" "1000" "1000000")))
  (ok (equal (mapcar #'format-log-tick '(1/10 1/100 1/10000))
             '("0.1" "0.01" "0.0001")))
  (ok (string= (format-log-tick 10000000) "1e7"))
  (ok (string= (format-log-tick 1/100000) "1e-5"))
  (ok (string= (format-log-tick 0.001d0) "0.001"))
  (ok (string= (format-log-tick 2) "2") "not a power of ten -> FORMAT-NUMBER"))

(deftest log-scale-chart
  ;; y values 1..1000 -> LOG-TICKS 1 1000 -> decades 1 10 100 1000, evenly spaced.
  ;; Plot YB 60, YT 16 (H 100): decade k at 60 - 44 k / 3 -> 60 45 31 16.
  (let* ((c (chart :scatter :series (list (series "s" '((1 . 1) (2 . 10) (3 . 100) (4 . 1000))))
                            :y-axis (axis :scale :log) :x-axis (axis :ticks '(1 4))
                            :width 160 :height 100))
         (html (svg c)))
    (ok (equal (text-labels html) '("1" "4" "1" "10" "100" "1000")))
    (ok (contains (q "<text x='47' y='64' text-anchor='end'>1</text>") html))
    (ok (contains (q "<text x='47' y='49' text-anchor='end'>10</text>") html))
    (ok (contains (q "<text x='47' y='35' text-anchor='end'>100</text>") html))
    (ok (contains (q "<text x='47' y='20' text-anchor='end'>1000</text>") html))
    (ok (contains (q "cy='31'") html) "the point at 100 sits on its decade")
    (ok (equal (tooltips html) '("1, 1" "2, 10" "3, 100" "4, 1000")))))

(defun tt (lo hi &rest keys)
  (multiple-value-list (apply #'time-ticks lo hi keys)))

(deftest time-ticks-days
  (let ((lo (ut 2026 1 1)))
    (destructuring-bind (ticks nlo nhi unit step) (tt lo (+ lo (* 3 86400)))
      (ok (eq unit :day))
      (ok (= step 1))
      (ok (= nlo lo))
      (ok (= nhi (ut 2026 1 4)))
      (ok (equal ticks (list (ut 2026 1 1) (ut 2026 1 2) (ut 2026 1 3) (ut 2026 1 4))))
      (ok (equal (mapcar (lambda (v) (format-time-tick v unit)) ticks)
                 '("2026-01-01" "2026-01-02" "2026-01-03" "2026-01-04"))))))

(deftest time-ticks-months-years
  (destructuring-bind (ticks nlo nhi unit step) (tt (ut 2026 1 1) (ut 2026 12 1))
    (ok (eq unit :month))
    (ok (= step 3))
    (ok (= nlo (ut 2026 1 1)))
    (ok (= nhi (ut 2027 1 1)))
    (ok (equal (mapcar (lambda (v) (format-time-tick v unit)) ticks)
               '("2026-01" "2026-04" "2026-07" "2026-10" "2027-01"))))
  (destructuring-bind (ticks nlo nhi unit step) (tt (ut 2000 1 1) (ut 2026 6 1))
    (ok (eq unit :year))
    (ok (= step 10))
    (ok (= nlo (ut 2000 1 1)))
    (ok (= nhi (ut 2030 1 1)))
    (ok (equal (mapcar (lambda (v) (format-time-tick v unit)) ticks)
               '("2000" "2010" "2020" "2030")))))

(deftest time-ticks-sub-day
  (let ((lo (ut 2026 3 15 1)))
    (destructuring-bind (ticks nlo nhi unit step) (tt lo (+ lo 10800))
      (ok (and (eq unit :hour) (= step 1)))
      (ok (= nlo lo))
      (ok (= nhi (ut 2026 3 15 4)))
      (ok (equal (mapcar (lambda (v) (format-time-tick v unit)) ticks)
                 '("01:00" "02:00" "03:00" "04:00")))))
  ;; Midnight ticks of a sub-day unit print the date.
  (destructuring-bind (ticks nlo nhi unit step) (tt (ut 2026 3 15) (ut 2026 3 16))
    (declare (ignore nlo nhi))
    (ok (and (eq unit :hour) (= step 6)))
    (ok (equal (mapcar (lambda (v) (format-time-tick v unit)) ticks)
               '("2026-03-15" "06:00" "12:00" "18:00" "2026-03-16"))))
  ;; Unaligned start: floored to the 12 h boundary, ceiled at the end.
  (destructuring-bind (ticks nlo nhi unit step) (tt (ut 2026 1 1 5 17) (ut 2026 1 3 5 17))
    (ok (and (eq unit :hour) (= step 12)))
    (ok (= nlo (ut 2026 1 1)))
    (ok (= nhi (ut 2026 1 3 12)))
    (ok (equal (mapcar (lambda (v) (format-time-tick v unit)) ticks)
               '("2026-01-01" "12:00" "2026-01-02" "12:00" "2026-01-03" "12:00"))))
  (let ((lo (ut 2026 3 15 10 0 0)))
    (destructuring-bind (ticks nlo nhi unit step) (tt lo (+ lo 20))
      (declare (ignore nlo nhi))
      (ok (and (eq unit :second) (= step 5)))
      (ok (equal (mapcar (lambda (v) (format-time-tick v unit)) ticks)
                 '("10:00:00" "10:00:05" "10:00:10" "10:00:15" "10:00:20"))))))

(deftest time-ticks-weeks
  ;; 1900-01-01 was a Monday, so weeks start on Mondays: 2025-12-29 is one.
  (destructuring-bind (ticks nlo nhi unit step) (tt (ut 2026 1 1) (ut 2026 1 22))
    (ok (and (eq unit :week) (= step 1)))
    (ok (= nlo (ut 2025 12 29)))
    (ok (= nhi (ut 2026 1 26)))
    (ok (equal (mapcar (lambda (v) (format-time-tick v unit)) ticks)
               '("2025-12-29" "2026-01-05" "2026-01-12" "2026-01-19" "2026-01-26")))))

(deftest time-ticks-empty-and-single
  (ok (equal (tt nil nil) '((0 21600 43200 64800 86400) 0 86400 :hour 6)))
  (ok (equal (mapcar (lambda (v) (format-time-tick v :hour)) '(0 21600 86400))
             '("1900-01-01" "06:00" "1900-01-02")))
  (let ((t0 (ut 2026 1 1)))
    (ok (equal (tt t0 t0) (tt t0 (+ t0 86400))) "a single instant -> one day")
    (ok (equal (tt (+ t0 86400) t0) (tt t0 (+ t0 86400))) "swapped"))
  (ok (string= (format-time (ut 2026 3 15 14 5 9)) "2026-03-15 14:05:09"))
  (ok (string= (format-time 0) "1900-01-01 00:00:00")))

(deftest time-scale-chart
  (let* ((t0 (ut 2026 1 1))
         (c (chart :line :series (list (series "t" (list (cons t0 5) (cons (+ t0 (* 3 86400)) 7))))
                         :x-axis (axis :scale :time)))
         (html (svg c)))
    (ok (equal (subseq (text-labels html) 0 4)
               '("2026-01-01" "2026-01-02" "2026-01-03" "2026-01-04")))
    (ok (equal (tooltips html) '("2026-01-01 00:00:00, 5" "2026-01-04 00:00:00, 7")))))

(deftest axis-bounds-honoured
  ;; MIN/MAX given: the domain is exactly [0, 100]; ticks from NICE-TICKS 0 100.
  (let* ((c (chart :line :series (list (series "a" '((0 . 10) (1 . 20) (2 . 150))))
                         :y-axis (axis :min 0 :max 100)
                         :x-axis (axis :ticks '(0 2))
                         :width 160 :height 100))
         (html (svg c)))
    (ok (equal (text-labels html) '("0" "2" "0" "20" "40" "60" "80" "100")))
    ;; YB 60, YT 16: 150 is clamped to the top.
    (ok (contains (q "points='56,56 100,51 144,16'") html)))
  ;; Only MIN: the other side is niced from the data.
  (let ((html (svg (chart :scatter :series (list (series "a" '((0 . 3) (1 . 7))))
                                   :y-axis (axis :min 1)))))
    (ok (equal (last (text-labels html) 4) '("2" "4" "6" "8")))))

(deftest explicit-ticks
  (let ((html (svg (chart :scatter :series (list (series "a" '((0 . 0) (10 . 10))))
                                   :x-axis (axis :ticks '(10 0 2.5d0 5 5 99))
                                   :y-axis (axis :ticks '(1/3))))))
    ;; Sorted, de-duplicated, outside-the-domain dropped, FORMAT-NUMBER labels.
    (ok (equal (text-labels html) '("0" "2.5" "5" "10" "0.333333")))))

(deftest axis-format
  (let ((html (svg (chart :scatter :series (list (series "a" '((0 . 0) (10 . 10))))
                                   :x-axis (axis :ticks '(0 10) :format "~D%")
                                   :y-axis (axis :ticks '(0 10)
                                                 :format (lambda (v) (format nil "<~D>" v)))))))
    (ok (equal (text-labels html) '("0%" "10%" "&lt;0&gt;" "&lt;10&gt;")))
    (ok (equal (tooltips html) '("0%, &lt;0&gt;" "10%, &lt;10&gt;")) "tooltips use FORMAT too"))
  (ok (signals (svg (chart :scatter :series (list (series "a" '((0 . 0))))
                                    :x-axis (axis :format (lambda (v) v))))
               'canvas:canvas-error)))
