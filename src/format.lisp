(in-package #:canvas-backend-svg)

;;; Label text. Every number this backend prints goes through one of these, so
;;; output never depends on *PRINT-BASE*, *PRINT-RADIX*, *READ-DEFAULT-FLOAT-FORMAT*
;;; or the implementation's float printer. Bind the printer variables to their
;;; standard values (or use ~D with explicit arguments) inside each function.
;;;
;;; Exact arithmetic: a float argument is first converted with RATIONALIZE
;;; (0.1d0 -> 1/10); integers and ratios are used as they are. "Exponent of x"
;;; (x > 0) is the integer e with 10^e <= x < 10^(e+1), found exactly on
;;; rationals (no LOG). "Round" is half away from zero on the magnitude:
;;; (floor (+ |x| 1/2)), sign put back after; a result of zero prints without
;;; a sign ("0", never "-0").
;;;
;;; FORMAT-NUMBER value -> string. VALUE a real (CHECK-TYPE). Integer -> ~D.
;;;   Otherwise rationalize, round to 6 decimals, print as fixed decimal with
;;;   trailing zeros (and a trailing ".") removed:
;;;   3 -> "3", 1.5d0 -> "1.5", 1/3 -> "0.333333", 2/3 -> "0.666667",
;;;   -1/2 -> "-0.5", -1d-7 -> "0", 1d20 -> "100000000000000000000".
;;;   Used for explicit axis ticks, tooltips, histogram bin edges and log-scale
;;;   endpoints that are not powers of ten.
;;;
;;; FORMAT-TICK value step -> string. Tick label on an automatic linear axis.
;;;   STEP is the positive tick step from NICE-TICKS (1, 2 or 5 x 10^e); e is
;;;   the exponent of STEP. VALUE is a multiple of STEP (CHECK-TYPE real for
;;;   both; a non-positive STEP is a TYPE-ERROR too).
;;;   - Fixed when -4 <= e <= 5: exactly max(0, -e) decimals, trailing zeros
;;;     kept: (4 2) -> "4", (1/2 1/2) -> "0.5", (3/2500 1/5000) -> "0.0012",
;;;     (1/1000 1/5000) -> "0.0010", (-4 2) -> "-4", (-1/2 1/2) -> "-0.5".
;;;   - Scientific when e >= 6 or e <= -5: VALUE 0 -> "0"; else k = exponent of
;;;     |VALUE|, mantissa m = VALUE / 10^k printed with (k - e) decimals, trailing
;;;     zeros and "." removed, then "e" and k in decimal:
;;;     (2e11 2e11) -> "2e11", (1e12 2e11) -> "1e12", (15/10^9 5/10^9) -> "1.5e-8",
;;;     (2/10^9 1/10^9) -> "2e-9", (-3e6 1e6) -> "-3e6".
;;;
;;; FORMAT-LOG-TICK value -> string. VALUE a positive real. An exact power of
;;;   ten 10^k (after RATIONALIZE): 0 <= k <= 6 -> the integer ("1" "10" ...
;;;   "1000000"); -4 <= k < 0 -> fixed decimal ("0.1" ... "0.0001"); otherwise
;;;   "1e<k>" ("1e7", "1e-5"). Anything else -> FORMAT-NUMBER.
;;;
;;; FORMAT-TIME-TICK universal-time unit -> string, UTC. UNIT is one of
;;;   :second :minute :hour :day :week :month :year (from TIME-TICKS).
;;;   :year "YYYY"; :month "YYYY-MM"; :day and :week "YYYY-MM-DD";
;;;   :hour and :minute "HH:MM"; :second "HH:MM:SS" -- except that a sub-day
;;;   unit (:second :minute :hour) at exactly 00:00:00 prints the date
;;;   "YYYY-MM-DD" instead. Unknown unit -> TYPE-ERROR.
;;;
;;; FORMAT-TIME universal-time -> "YYYY-MM-DD HH:MM:SS" (UTC). Tooltips on a
;;;   :time axis.
;;;
;;; Calendar fields come from datetime-protocol, not DECODE-UNIVERSAL-TIME
;;; (which consults the local zone on some implementations for its 9th value
;;; and is easy to misuse): days = (floor ut 86400), date =
;;; (stack-datetime:date-from-rd (+ 693596 days)) -- RD 693596 is 1900-01-01,
;;; universal time 0 -- then DATE-YEAR / DATE-MONTH / DATE-DAY (or
;;; STACK-DATETIME:PRINT-ISO-DATE) and the remainder (mod ut 86400) for H:M:S.

(defconstant +rd-1900-01-01+ 693596
  "Rata Die of 1900-01-01, the epoch of CL universal time.")

;;; ---------------------------------------------------------------- numbers

(defun %rat (x)
  "Exact value of the real X. Floats are RATIONALIZEd; a float of magnitude
2^53 or more is integral, and RATIONAL gives its exact value there (1d20 ->
10^20) where RATIONALIZE may pick a different integer."
  (cond ((not (floatp x)) x)
        ((>= (abs x) (expt 2 53)) (rational x))
        (t (rationalize x))))

(defun %exponent (x)
  "X a positive rational -> the integer e with 10^e <= X < 10^(e+1)."
  (let ((e 0))
    (loop while (>= x 10) do (setf x (/ x 10)) (incf e))
    (loop while (< x 1) do (setf x (* x 10)) (decf e))
    e))

(defun %power-of-ten (r)
  "K when the rational R is exactly 10^K, else NIL."
  (and (rationalp r) (plusp r)
       (let ((k (%exponent r)))
         (and (= r (expt 10 k)) k))))

(defun %fixed (r decimals keep-zeros)
  "The rational R as a fixed decimal with DECIMALS digits, rounded half away
from zero. Without KEEP-ZEROS, trailing zeros and a trailing \".\" go. Never
\"-0\"."
  (let* ((scale (expt 10 decimals))
         (n (floor (+ (* (abs r) scale) 1/2)))
         (negative (and (minusp r) (plusp n))))
    (multiple-value-bind (int frac) (floor n scale)
      (let ((digits (if (zerop decimals) "" (format nil "~V,'0D" decimals frac))))
        (unless keep-zeros
          (setf digits (string-right-trim "0" digits)))
        (concatenate 'string
                     (if negative "-" "")
                     (format nil "~D" int)
                     (if (plusp (length digits)) "." "")
                     digits)))))

(defun format-number (value)
  (check-type value real)
  (let ((r (%rat value)))
    (if (integerp r)
        (format nil "~D" r)
        (%fixed r 6 nil))))

(defun format-tick (value step)
  (check-type value real)
  (check-type step (real (0)))
  (let ((v (%rat value))
        (e (%exponent (%rat step))))
    (cond ((<= -4 e 5) (%fixed v (max 0 (- e)) t))
          ((zerop v) "0")
          (t (let ((k (%exponent (abs v))))
               (concatenate 'string
                            (%fixed (/ v (expt 10 k)) (max 0 (- k e)) nil)
                            "e" (format nil "~D" k)))))))

(defun format-log-tick (value)
  (check-type value (real (0)))
  (let* ((r (%rat value))
         (k (%power-of-ten r)))
    (cond ((null k) (format-number r))
          ((<= 0 k 6) (format nil "~D" r))
          ((<= -4 k -1) (%fixed r (- k) t))
          (t (format nil "1e~D" k)))))

;;; ---------------------------------------------------------------- calendar

(defun %ut-date (ut)
  "The datetime-protocol DATE of the universal time UT (UTC)."
  (stack-datetime:date-from-rd (+ +rd-1900-01-01+ (floor ut 86400))))

(defun %ut-fields (ut)
  "UT -> year month day hour minute second, UTC."
  (let ((date (%ut-date ut)))
    (multiple-value-bind (h rest) (floor (mod ut 86400) 3600)
      (multiple-value-bind (mi s) (floor rest 60)
        (values (stack-datetime:date-year date) (stack-datetime:date-month date)
                (stack-datetime:date-day date) h mi s)))))

(defun %date-ut (year month &optional (day 1))
  "Universal time of 00:00 UTC on YEAR-MONTH-DAY."
  (* 86400 (- (stack-datetime:date-rd (stack-datetime:make-date year month day))
              +rd-1900-01-01+)))

(defun %ymd (year month day)
  (format nil "~4,'0D-~2,'0D-~2,'0D" year month day))

(defun format-time-tick (universal-time unit)
  (check-type universal-time (integer 0))
  (check-type unit (member :second :minute :hour :day :week :month :year))
  (multiple-value-bind (y mo d h mi s) (%ut-fields universal-time)
    (let ((midnight (zerop (mod universal-time 86400))))
      (ecase unit
        (:year (format nil "~4,'0D" y))
        (:month (format nil "~4,'0D-~2,'0D" y mo))
        ((:day :week) (%ymd y mo d))
        ((:hour :minute)
         (if midnight (%ymd y mo d) (format nil "~2,'0D:~2,'0D" h mi)))
        (:second
         (if midnight (%ymd y mo d) (format nil "~2,'0D:~2,'0D:~2,'0D" h mi s)))))))

(defun format-time (universal-time)
  (check-type universal-time (integer 0))
  (multiple-value-bind (y mo d h mi s) (%ut-fields universal-time)
    (format nil "~4,'0D-~2,'0D-~2,'0D ~2,'0D:~2,'0D:~2,'0D" y mo d h mi s)))
