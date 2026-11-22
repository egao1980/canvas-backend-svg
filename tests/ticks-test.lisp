(in-package #:canvas-backend-svg/tests)

;;; NICE-TICKS (Heckbert), FORMAT-TICK, FORMAT-NUMBER. Expected values are exact
;;; rationals: compare with EQUAL.

(defun nice (lo hi &rest keys)
  (multiple-value-list (apply #'nice-ticks lo hi keys)))

(deftest nice-ticks-basic
  (ok (equal (nice 0 10) '((0 2 4 6 8 10) 0 10 2)))
  (ok (equal (nice 0 4) '((0 1 2 3 4) 0 4 1)))
  (ok (equal (nice 0 3) '((0 1 2 3) 0 3 1)))
  (ok (equal (nice 1/2 5/2) '((1/2 1 3/2 2 5/2) 1/2 5/2 1/2)))
  (ok (equal (nice 0.5d0 2.5d0) (nice 1/2 5/2)) "floats are rationalized"))

(deftest nice-ticks-negative
  (ok (equal (nice -3 7) '((-4 -2 0 2 4 6 8) -4 8 2)))
  (ok (equal (nice -100 -20) '((-100 -80 -60 -40 -20) -100 -20 20)))
  (ok (equal (nice -1 -1/2) (nice -1 -0.5d0))))

(deftest nice-ticks-tiny
  (ok (equal (nice 0.001d0 0.002d0)
             '((1/1000 3/2500 7/5000 1/625 9/5000 1/500) 1/1000 1/500 1/5000)))
  (destructuring-bind (ticks lo hi step) (nice 1d-9 5d-9)
    (ok (equal ticks '(1/1000000000 2/1000000000 3/1000000000 4/1000000000 5/1000000000)))
    (ok (= lo 1/1000000000))
    (ok (= hi 5/1000000000))
    (ok (= step 1/1000000000))))

(deftest nice-ticks-huge
  (ok (equal (nice 0 1d12)
             '((0 200000000000 400000000000 600000000000 800000000000 1000000000000)
               0 1000000000000 200000000000)))
  (ok (every #'integerp (first (nice 0 1d12)))))

(deftest nice-ticks-single-value
  (ok (equal (nice 5 5) '((22/5 23/5 24/5 5 26/5 27/5 28/5) 22/5 28/5 1/5)))
  (ok (equal (nice 0 0) '((-1 -1/2 0 1/2 1) -1 1 1/2)))
  (ok (equal (nice -5 -5) '((-28/5 -27/5 -26/5 -5 -24/5 -23/5 -22/5) -28/5 -22/5 1/5))))

(deftest nice-ticks-empty-and-options
  (ok (equal (nice nil nil) '((0 1/5 2/5 3/5 4/5 1) 0 1 1/5)) "no data -> [0,1]")
  (ok (equal (nice nil 10) (nice 10 10)) "one NIL -> as the other")
  (ok (equal (nice 10 0) (nice 0 10)) "swapped")
  (ok (equal (nice 0 100 :count 3) '((0 50 100) 0 100 50)))
  (ok (signals (nice-ticks "0" 1) 'type-error))
  (ok (signals (nice-ticks 0 1 :count 1) 'type-error)))

(deftest format-tick-fixed
  (ok (string= (format-tick 4 2) "4"))
  (ok (string= (format-tick 0 2) "0"))
  (ok (string= (format-tick -4 2) "-4"))
  (ok (string= (format-tick 1/2 1/2) "0.5"))
  (ok (string= (format-tick -1/2 1/2) "-0.5"))
  (ok (string= (format-tick 1 1/2) "1.0"))
  (ok (string= (format-tick 3/2500 1/5000) "0.0012"))
  (ok (string= (format-tick 1/1000 1/5000) "0.0010"))
  (ok (string= (format-tick 22/5 1/5) "4.4"))
  (ok (string= (format-tick 200000 100000) "200000"))
  (ok (equal (mapcar (lambda (v) (format-tick v 1/5)) (first (nice nil nil)))
             '("0.0" "0.2" "0.4" "0.6" "0.8" "1.0"))))

(deftest format-tick-scientific
  (ok (string= (format-tick 200000000000 200000000000) "2e11"))
  (ok (string= (format-tick 1000000000000 200000000000) "1e12"))
  (ok (string= (format-tick 0 200000000000) "0"))
  (ok (string= (format-tick -3000000 1000000) "-3e6"))
  (ok (string= (format-tick 15/1000000000 5/1000000000) "1.5e-8"))
  (ok (string= (format-tick 2/1000000000 1/1000000000) "2e-9"))
  (ok (string= (format-tick 12/100000 1/100000) "1.2e-4"))
  (ok (signals (format-tick 1 0) 'type-error)))

(deftest format-number-cases
  (ok (string= (format-number 3) "3"))
  (ok (string= (format-number -42) "-42"))
  (ok (string= (format-number 1.5d0) "1.5"))
  (ok (string= (format-number 0.1) "0.1"))
  (ok (string= (format-number 1/3) "0.333333"))
  (ok (string= (format-number 2/3) "0.666667"))
  (ok (string= (format-number -1/2) "-0.5"))
  (ok (string= (format-number -1d-7) "0"))
  (ok (string= (format-number 1d20) "100000000000000000000"))
  (ok (string= (let ((*print-base* 16) (*print-radix* t)) (format-number 255)) "255"))
  (ok (signals (format-number "1") 'type-error)))
