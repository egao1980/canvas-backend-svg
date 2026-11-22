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

(defun format-number (value)
  (declare (ignore value))
  (%svg0-pending 'format-number))

(defun format-tick (value step)
  (declare (ignore value step))
  (%svg0-pending 'format-tick))

(defun format-log-tick (value)
  (declare (ignore value))
  (%svg0-pending 'format-log-tick))

(defun format-time-tick (universal-time unit)
  (declare (ignore universal-time unit))
  (%svg0-pending 'format-time-tick))

(defun format-time (universal-time)
  (declare (ignore universal-time))
  (%svg0-pending 'format-time))
