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

(defun nice-ticks (lo hi &key (count 5))
  (declare (ignore lo hi count))
  (%svg0-pending 'nice-ticks))

(defun log-ticks (lo hi)
  (declare (ignore lo hi))
  (%svg0-pending 'log-ticks))

(defun time-ticks (lo hi &key (count 5))
  (declare (ignore lo hi count))
  (%svg0-pending 'time-ticks))
