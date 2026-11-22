(in-package #:canvas-backend-svg)

;;; Ticks and domains. All exact (rationals), so every implementation produces
;;; the same numbers. Floats are RATIONALIZEd first (see format.lisp).
;;;
;;; NICE-TICKS lo hi &key (count 5) -> (values ticks nice-lo nice-hi step)
;;;   Heckbert's loose labelling ("Nice numbers for graph labels", Graphics
;;;   Gems 1990). LO / HI reals or NIL (CHECK-TYPE (or null real)); COUNT an
;;;   integer >= 2 (else TYPE-ERROR).
;;;   - LO and HI both NIL (no data) -> as LO 0, HI 1. One NIL -> as the other.
;;;   - LO > HI -> swapped.
;;;   - LO = HI = v -> widened to [v - d, v + d], d = |v|/10, or 1 when v = 0.
;;;   - NICENUM(x, round) for x > 0: e = exponent of x, f = x / 10^e;
;;;     round:   f < 3/2 -> 1, f < 3 -> 2, f < 7 -> 5, else 10;
;;;     ceiling: f <= 1 -> 1, f <= 2 -> 2, f <= 5 -> 5, else 10; result nf * 10^e.
;;;   - range = NICENUM(hi - lo, ceiling); step = NICENUM(range / (count - 1), round);
;;;     nice-lo = (floor lo step) * step; nice-hi = (ceiling hi step) * step;
;;;     ticks = nice-lo, nice-lo + step, ..., nice-hi (exact rationals).
;;;   Examples (the tests): (0 10) -> (0 2 4 6 8 10) 0 10 2;
;;;   (-3 7) -> (-4 -2 0 2 4 6 8); (-100 -20) -> (-100 -80 -60 -40 -20), step 20;
;;;   (0.001d0 0.002d0) -> (1/1000 3/2500 7/5000 1/625 9/5000 1/500), step 1/5000;
;;;   (0 1d12) -> (0 2e11 ... 1e12) as integers; (5 5) -> 22/5 .. 28/5 by 1/5;
;;;   (0 0) -> (-1 -1/2 0 1/2 1); (nil nil) -> (0 1/5 2/5 3/5 4/5 1);
;;;   (0 100 :count 3) -> (0 50 100).
;;;
;;; LOG-TICKS lo hi -> (values ticks nice-lo nice-hi)   ; base 10
;;;   LO / HI positive reals or NIL (both NIL -> 1 and 10; one NIL -> as the
;;;   other); LO > HI swapped. nice-lo = the greatest 10^k <= lo, nice-hi = the
;;;   least 10^k >= hi (exact), and when they are equal nice-hi = nice-lo * 10.
;;;   ticks = every 10^k from nice-lo to nice-hi.
;;;   (3 2000) -> (1 10 100 1000 10000) 1 10000; (1/1000 1/10) -> (1/1000 1/100 1/10);
;;;   (100 100) -> (100 1000); (nil nil) -> (1 10).
;;;
;;; TIME-TICKS lo hi &key (count 5) -> (values ticks nice-lo nice-hi unit step)
;;;   LO / HI non-negative integers (universal time, UTC) or NIL. Both NIL ->
;;;   LO 0, HI 86400; one NIL -> as the other; LO > HI swapped; LO = HI ->
;;;   HI = LO + 86400. span = HI - LO.
;;;   Candidates, in this order, each (unit step approximate-seconds):
;;;     :second 1 2 5 10 15 30;  :minute 1 2 5 10 15 30;  :hour 1 3 6 12;
;;;     :day 1 2;  :week 1;  :month 1 3 6  (a month counts 2629746 s);
;;;   the first with span / seconds <= COUNT wins. If none does, :year with the
;;;   first step n in 1 2 5 10 20 50 100 200 500 ... such that
;;;   (Y1 - Y0) / n <= COUNT, where Y0 = year of LO and Y1 = year of HI, plus 1
;;;   unless HI is exactly 00:00:00 on 1 January.
;;;   Boundaries (all UTC; universal time 0 = 1900-01-01T00:00, a Monday):
;;;     :second / :minute / :hour / :day 1 and 2 -- ut mod (step seconds) = 0;
;;;     :week -- ut mod 604800 = 0 (Mondays);
;;;     :month -- 00:00 on the 1st of a month whose (year*12 + month - 1) mod n = 0;
;;;     :year -- 00:00 on 1 January of a year with year mod n = 0.
;;;   nice-lo = the greatest boundary <= LO; nice-hi = the least boundary >= HI;
;;;   ticks = every boundary from nice-lo to nice-hi. Calendar conversion through
;;;   datetime-protocol (format.lisp, +RD-1900-01-01+; STACK-DATETIME:MAKE-DATE +
;;;   DATE-RD for the first of a month / year).
;;;   Examples (the tests, T(y m d h mi s) = encode-universal-time in zone 0):
;;;   T(2026 1 1) .. +3 days -> :day 1, 4 ticks;
;;;   T(2026 1 1) .. T(2026 12 1) -> :month 3, ticks 2026-01 04 07 10 2027-01;
;;;   T(2000 1 1) .. T(2026 6 1) -> :year 10, ticks 2000 2010 2020 2030;
;;;   T(2026 1 1 5 17) .. +2 days -> :hour 12, 6 ticks from 2026-01-01 00:00;
;;;   21 days from T(2026 1 1) -> :week 1, ticks from Monday 2025-12-29 to 2026-01-26;
;;;   (nil nil) -> :hour 6, ticks 0 21600 43200 64800 86400.
;;;
;;; How the renderer builds an axis domain (render.lisp uses these):
;;;   values = the chart's real values on that axis (see render.lisp per kind).
;;;   lo / hi = min / max of the values (NIL when none). An axis MIN replaces
;;;   lo and MAX replaces hi. When exactly one bound is given and then
;;;   lo >= hi (the bound lies on or beyond the data), the free side becomes
;;;   bound +/- d (d as in NICE-TICKS' widening; for :log bound*10 or bound/10;
;;;   for :time bound +/- 86400). lo = hi with no bound is left to the tick
;;;   function's own widening.
;;;   :linear -> NICE-TICKS lo hi; :log -> LOG-TICKS; :time -> TIME-TICKS.
;;;   Domain d0 = MIN if given else nice-lo; d1 = MAX if given else nice-hi.
;;;   Tick values = the computed ticks within [d0, d1]; when the axis has
;;;   explicit TICKS, those instead (RATIONALIZEd, duplicates removed, sorted
;;;   ascending, only those within [d0, d1]). For :log with no automatic tick
;;;   inside [d0, d1], the ticks are d0 and d1.

;;; ---------------------------------------------------------------- shared

(defun %range (lo hi default-lo default-hi)
  "LO / HI with NIL handling (both NIL -> the defaults, one NIL -> the other)
and swapped into ascending order."
  (let ((l (or lo hi default-lo))
        (h (or hi lo default-hi)))
    (if (> l h) (values h l) (values l h))))

(defun %widen-d (v)
  "NICE-TICKS' widening distance for the single value V."
  (if (zerop v) 1 (/ (abs v) 10)))

;;; ---------------------------------------------------------------- linear

(defparameter +nice-round+ '((3/2 . 1) (3 . 2) (7 . 5))
  "NICENUM with rounding: the first row whose bound F is below gives NF.")

(defparameter +nice-ceiling+ '((1 . 1) (2 . 2) (5 . 5))
  "NICENUM as a ceiling: the first row whose bound F is at or below gives NF.")

(defun %nicenum (x roundp)
  (let* ((e (%exponent x))
         (p (expt 10 e))
         (f (/ x p))
         (row (if roundp
                  (find-if (lambda (b) (< f (car b))) +nice-round+)
                  (find-if (lambda (b) (<= f (car b))) +nice-ceiling+))))
    (* (if row (cdr row) 10) p)))

(defun nice-ticks (lo hi &key (count 5))
  (check-type lo (or null real))
  (check-type hi (or null real))
  (check-type count (integer 2))
  (multiple-value-bind (lo hi) (%range (and lo (%rat lo)) (and hi (%rat hi)) 0 1)
    (when (= lo hi)
      (let ((d (%widen-d lo)))
        (setf lo (- lo d) hi (+ hi d))))
    (let* ((step (%nicenum (/ (%nicenum (- hi lo) nil) (1- count)) t))
           (nice-lo (* (floor lo step) step))
           (nice-hi (* (ceiling hi step) step)))
      (values (loop for v = nice-lo then (+ v step)
                    while (<= v nice-hi) collect v)
              nice-lo nice-hi step))))

;;; ---------------------------------------------------------------- log

(defun log-ticks (lo hi)
  (check-type lo (or null (real (0))))
  (check-type hi (or null (real (0))))
  (multiple-value-bind (lo hi) (%range (and lo (%rat lo)) (and hi (%rat hi)) 1 10)
    (let* ((nice-lo (expt 10 (%exponent lo)))
           (nice-hi (let ((p (expt 10 (%exponent hi))))
                      (if (= p hi) p (* p 10)))))
      (when (= nice-lo nice-hi)
        (setf nice-hi (* nice-lo 10)))
      (values (loop for v = nice-lo then (* v 10)
                    while (<= v nice-hi) collect v)
              nice-lo nice-hi))))

;;; ---------------------------------------------------------------- time

(defparameter +time-candidates+
  '((:second 1 1) (:second 2 2) (:second 5 5) (:second 10 10) (:second 15 15)
    (:second 30 30)
    (:minute 1 60) (:minute 2 120) (:minute 5 300) (:minute 10 600)
    (:minute 15 900) (:minute 30 1800)
    (:hour 1 3600) (:hour 3 10800) (:hour 6 21600) (:hour 12 43200)
    (:day 1 86400) (:day 2 172800)
    (:week 1 604800)
    (:month 1 2629746) (:month 3 7889238) (:month 6 15778476))
  "(unit step approximate-seconds), tried in order; the first whose tick count
fits wins.")

(defun %year-steps (span)
  "1 2 5 10 20 50 ... up to the first step >= SPAN (so the last one always fits)."
  (loop for k from 0
        nconc (loop for m in '(1 2 5) collect (* m (expt 10 k))) into steps
        until (>= (* 5 (expt 10 k)) (max 1 span))
        finally (return steps)))

(defun %ut-year (ut) (stack-datetime:date-year (%ut-date ut)))

(defun %ut-month-index (ut)
  (let ((date (%ut-date ut)))
    (+ (* 12 (stack-datetime:date-year date)) (stack-datetime:date-month date) -1)))

(defun %month-index-ut (i)
  (multiple-value-bind (year m0) (floor i 12)
    (%date-ut year (1+ m0))))

(defun %year-ut (year) (%date-ut year 1))

(defun %month-start-p (ut)
  (= ut (%month-index-ut (%ut-month-index ut))))

(defun %year-start-p (ut)
  (= ut (%year-ut (%ut-year ut))))

(defun %calendar-ticks (lo hi n ut->index index->ut start-p)
  "Boundaries every N indices (months or years) from the greatest <= LO to the
least >= HI."
  (let* ((i0 (* n (floor (funcall ut->index lo) n)))
         (j (if (funcall start-p hi)
                (funcall ut->index hi)
                (1+ (funcall ut->index hi))))
         (i1 (* n (ceiling j n)))
         (ticks (loop for i from i0 to i1 by n collect (funcall index->ut i))))
    (values ticks (first ticks) (car (last ticks)))))

(defun time-ticks (lo hi &key (count 5))
  (check-type lo (or null (integer 0)))
  (check-type hi (or null (integer 0)))
  (check-type count (integer 2))
  (multiple-value-bind (lo hi) (%range lo hi 0 86400)
    (when (= lo hi)
      (setf hi (+ lo 86400)))
    (let* ((span (- hi lo))
           (row (find-if (lambda (r) (<= (/ span (third r)) count)) +time-candidates+)))
      (cond
        ((null row)
         (let* ((y0 (%ut-year lo))
                (y1 (if (%year-start-p hi) (%ut-year hi) (1+ (%ut-year hi))))
                (n (find-if (lambda (n) (<= (/ (- y1 y0) n) count))
                            (%year-steps (- y1 y0)))))
           (multiple-value-bind (ticks nice-lo nice-hi)
               (%calendar-ticks lo hi n #'%ut-year #'%year-ut #'%year-start-p)
             (values ticks nice-lo nice-hi :year n))))
        ((eq (first row) :month)
         (let ((n (second row)))
           (multiple-value-bind (ticks nice-lo nice-hi)
               (%calendar-ticks lo hi n #'%ut-month-index #'%month-index-ut #'%month-start-p)
             (values ticks nice-lo nice-hi :month n))))
        (t
         (destructuring-bind (unit step seconds) row
           (let ((nice-lo (* seconds (floor lo seconds)))
                 (nice-hi (* seconds (ceiling hi seconds))))
             (values (loop for v from nice-lo to nice-hi by seconds collect v)
                     nice-lo nice-hi unit step))))))))

;;; ---------------------------------------------------------------- axis domain

(defun %axis-domain (scale values amin amax &key exact)
  "The renderer's axis domain (header rules above).
-> (values d0 d1 automatic-ticks automatic-labeller). EXACT: the histogram's
x axis, [lo, hi] from MIN / MAX or the data, not niced (linear)."
  (let* ((vals (mapcar #'%rat values))
         (amin (and amin (%rat amin)))
         (amax (and amax (%rat amax)))
         (lo (or amin (and vals (reduce #'min vals))))
         (hi (or amax (and vals (reduce #'max vals)))))
    ;; Exactly one bound, on or beyond the data: widen the free side from it.
    (when (and (if amin (not amax) amax)
               (or (null lo) (null hi) (>= lo hi)))
      (let ((b (or amin amax))
            (up (and amin t)))
        (ecase (if exact :linear scale)
          (:linear (if up (setf hi (+ b (%widen-d b))) (setf lo (- b (%widen-d b)))))
          (:log (if up (setf hi (* b 10)) (setf lo (/ b 10))))
          (:time (if up (setf hi (+ b 86400)) (setf lo (max 0 (- b 86400))))))))
    (if exact
        (let ((lo (or lo 0))
              (hi (or hi 1)))
          (when (= lo hi)
            (setf lo (- lo 1/2) hi (+ hi 1/2)))
          (multiple-value-bind (ticks nice-lo nice-hi step) (nice-ticks lo hi)
            (declare (ignore nice-lo nice-hi))
            (values lo hi ticks (lambda (v) (format-tick v step)))))
        (ecase scale
          (:linear
           (multiple-value-bind (ticks nice-lo nice-hi step) (nice-ticks lo hi)
             (values (or amin nice-lo) (or amax nice-hi) ticks
                     (lambda (v) (format-tick v step)))))
          (:log
           (multiple-value-bind (ticks nice-lo nice-hi) (log-ticks lo hi)
             (values (or amin nice-lo) (or amax nice-hi) ticks #'format-log-tick)))
          (:time
           (multiple-value-bind (ticks nice-lo nice-hi unit)
               (time-ticks (and lo (max 0 (floor lo))) (and hi (max 0 (ceiling hi))))
             (values (or amin nice-lo) (or amax nice-hi) ticks
                     (lambda (v) (format-time-tick v unit)))))))))
