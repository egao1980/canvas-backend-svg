(in-package #:canvas-backend-svg)

;;; The SVG chart backend (H4h-1). Locked design: cl-stack/docs/capabilities/canvas.md
;;; § H4h-1. Rules below are the contract; the golden strings in
;;; tests/golden-test.lisp are worked examples of every rule.
;;;
;;; ---------------------------------------------------------------- building
;;; Output is html-protocol nodes (stack-html), never strings: html-protocol
;;; 0.1.1 escapes every text node (& < >) and attribute value (& " <) when it
;;; serializes, so escaping happens by construction and nothing here escapes by
;;; hand. Elements are made with CANVAS:EL (keyword tag, attribute plist: the
;;; CSP refusals of canvas-protocol apply) -- except the <svg> root, made with
;;; STACK-HTML:MAKE-HTML-ELEMENT and an attribute alist, because EL lowercases
;;; attribute names and "viewBox" must keep its case. xml-protocol is not used:
;;; canvas trees, CSP-VIOLATIONS and FREEZE all work on html-protocol nodes, and
;;; inline SVG in HTML is parsed by the HTML parser.
;;; Attribute values: integers as integers (EL prints ~D), strings as strings.
;;; Output order = the order written below. No generated ids, no hash tables,
;;; no timestamps: same chart + same :id -> byte-identical TO-HTML.
;;;
;;; ---------------------------------------------------------------- entry
;;; RENDER-CHART (backend svg-backend) chart &key id -> <figure> node.
;;;   1. CANVAS:VALIDATE-CHART (INVALID-CHART propagates).
;;;   2. ID: a string [A-Za-z][A-Za-z0-9_-]*, else CANVAS-ERROR; default
;;;      (CHART-ID chart).
;;;   3. Every series COLOR (when non-NIL) must be "#" + 3 or 6 hex digits, or
;;;      1-20 lowercase ASCII letters (a CSS colour name); else
;;;      CANVAS:INVALID-CHART :field :series.
;;;
;;; CHART-ID chart -> "chart-" + slug of the title; slug: the title
;;;   downcased, each run of characters other than ASCII [a-z0-9] replaced by
;;;   one "-", "-" trimmed from both ends, cut to 32 characters, "-" trimmed
;;;   again. No title or an empty slug -> the kind's name ("line" "bar"
;;;   "scatter" "histogram"). Title "Sales" -> "chart-sales";
;;;   "<script>alert(1)</script>" -> "chart-script-alert-1-script".
;;;
;;; ---------------------------------------------------------------- tree
;;; <figure data-chart="KIND">                       KIND = kind name, lowercase
;;;   <svg id="ID" viewBox="0 0 W H" role="img" aria-labelledby="ID-title ID-desc"
;;;        fill="currentColor" font-family="sans-serif" font-size="12">
;;;     <title id="ID-title">TITLE</title>
;;;     <desc id="ID-desc">DESC</desc>
;;;     X-AXIS group, Y-AXIS group, one SERIES group per series (chart order),
;;;     LEGEND group when shown
;;;   </svg>
;;;   <figcaption>TITLE</figcaption>                 only when the chart has a title
;;; </figure>
;;; No width/height attributes: the viewBox makes the SVG scale to its
;;; container (the themes' "figure[data-chart] svg { max-width: 100%; height:
;;; auto }"). W, H = CHART-WIDTH / CHART-HEIGHT.
;;; TITLE = the chart title, else the kind's label: "Line chart" "Bar chart"
;;;   "Scatter chart" "Histogram".
;;; DESC = the chart description, else
;;;   (format nil "~A of ~D series: ~{~A~^, ~}." label n items), item =
;;;   (format nil "~A (~D ~A~:P)" name count noun count) -- noun "point" for
;;;   line/scatter, "bar" for bar, "value" for histogram; count = the number of
;;;   points of that series: "Line chart of 1 series: a (3 points)."
;;;
;;; ---------------------------------------------------------------- layout
;;; Margins: left 56 (72 with a y-axis label), right 16, top 16 (40 with a
;;; legend), bottom 40 (56 with an x-axis label). Plot box: X0 = left,
;;; X1 = W - right, YB (bottom) = H - bottom, YT (top) = top; when X1 <= X0,
;;; X1 = X0 + 1; when YB <= YT, YB = YT + 1.
;;; Position of a value: clamp it into the domain [d0, d1], then
;;;   linear/time: t = (v - d0) / (d1 - d0) exactly;
;;;   log: t = (lg v - lg d0) / (lg d1 - lg d0), lg x = the exact integer k when
;;;        x is exactly 10^k, else (/ (log (float x 1d0)) (log 10d0));
;;;   x = X0 + t (X1 - X0), y = YB - t (YB - YT); printed coordinates are
;;;   ROUNDED: (floor (+ p 1/2)). Integers only -- no float ever reaches the
;;;   output.
;;; Domains and ticks: ticks.lisp ("How the renderer builds an axis domain").
;;;   Values per kind -- line/scatter: x = the cars, y = the cdrs; bar: y = the
;;;   cdrs plus 0 (x is categorical); histogram: x = all values of all series
;;;   (exact domain, see below), y = the bin counts plus 0. For :log, 0 is not
;;;   added; bars and histogram bars then start at d0.
;;; Labels: an axis FORMAT (function of one value -> string, or a FORMAT
;;;   control string applied to the value; a function result that is not a
;;;   string -> CANVAS-ERROR) wins everywhere a value of that axis is printed
;;;   (tick labels and tooltips). Otherwise tick labels: automatic linear ticks
;;;   FORMAT-TICK value step; explicit TICKS FORMAT-NUMBER; :log FORMAT-LOG-TICK;
;;;   :time FORMAT-TIME-TICK value unit (explicit ticks on a :time axis:
;;;   FORMAT-TIME). Tooltip values: FORMAT-NUMBER, :time FORMAT-TIME.
;;;
;;; X-AXIS <g> (no attributes):
;;;   <line x1=X0 y1=YB x2=X1 y2=YB stroke="currentColor"></line>
;;;   per tick at x = P: <line x1=P y1=YB x2=P y2=YB+6 stroke="currentColor"></line>
;;;                      <text x=P y=YB+20 text-anchor="middle">LABEL</text>
;;;   label (when the axis has one): <text x=round((X0+X1)/2) y=H-12 text-anchor="middle">…</text>
;;; Y-AXIS <g>:
;;;   <line x1=X0 y1=YB x2=X0 y2=YT stroke="currentColor"></line>
;;;   per tick at y = P: <line x1=X0-6 y1=P x2=X0 y2=P stroke="currentColor"></line>
;;;                      <text x=X0-9 y=P+4 text-anchor="end">LABEL</text>
;;;   label: <text transform="translate(16,CY) rotate(-90)" text-anchor="middle">…</text>,
;;;          CY = round((YB+YT)/2)
;;; Ticks are emitted in ascending value order.
;;;
;;; SERIES <g data-series="N"> (N per palette.lisp), then color="C" when the
;;; series has a COLOR. Marks inside, in point order; each mark has exactly one
;;; child, <title>TIP</title>. TIP = the series' label for that point when the
;;; series has LABELS, else the default below.
;;;   line:    <polyline points="x,y x,y …" fill="none" stroke="currentColor"
;;;            stroke-width="2"></polyline> (only with 2 or more points; no
;;;            title), then per point <circle cx cy r="3" fill="currentColor">.
;;;            Default TIP "X, Y".
;;;   scatter: per point <circle cx cy r="4" fill="currentColor">. TIP "X, Y".
;;;   bar:     categories = the distinct point strings (STRING=) in first-seen
;;;            order over all series. Band c: width BW = (X1 - X0) / ncat,
;;;            start X0 + c BW; the group of bars is inset BW/10 on each side,
;;;            each series s (chart order) gets an equal share
;;;            w = (8 BW / 10) / nseries: left = X0 + c BW + BW/10 + s w,
;;;            right = left + w (both rounded separately; width = right - left).
;;;            Value y: top = round(pos(max(v, base))), bottom =
;;;            round(pos(min(v, base))), base = 0 clamped into the domain (d0
;;;            for :log); height = bottom - top.
;;;            <rect x y width height fill="currentColor">. A series without
;;;            a category draws nothing there; a repeated category draws each.
;;;            TIP "CATEGORY, Y". The x axis is categorical: one tick per band
;;;            at round(X0 + c BW + BW/2), label = the category string as is
;;;            (the x-axis FORMAT and TICKS are ignored).
;;;   histogram: domain [lo, hi] = the axis MIN / MAX, else the min / max of
;;;            all values (exact, not niced); lo = hi -> [lo - 1/2, lo + 1/2];
;;;            no values -> [0, 1]. B = CHART-BINS equal-width bins, edge
;;;            k = lo + k (hi - lo) / B (exact). A value v in [lo, hi] goes to
;;;            bin min(B - 1, floor((v - lo) B / (hi - lo))); values outside
;;;            are not counted. Counts per series. Bin k, series s of n: from
;;;            edge k + s (width / n) to edge k + (s + 1)(width / n), through
;;;            the x scale, rounded; every bin is drawn, also with count 0.
;;;            <rect x y width height fill="currentColor">.
;;;            TIP "A to B: COUNT" (A, B the bin's edges). Series LABELS are
;;;            ignored for histograms. X ticks: as for a linear axis, from
;;;            NICE-TICKS on [lo, hi], those within [lo, hi]; explicit TICKS win.
;;;
;;; LEGEND, shown when CHART-LEGEND is T, or :AUTO with more than one series:
;;;   <g> with, per series, starting at cx = X0:
;;;     <rect data-series="N" [color="C"] x=cx y="6" width="10" height="10" fill="currentColor"></rect>
;;;     <text x=cx+14 y="16">NAME</text>
;;;   next cx = cx + 14 + 7 (length NAME) + 16.
;;;
;;; ---------------------------------------------------------------- safety
;;; Never emitted: <script>, <style>, <foreignObject>, <a>, <image>, <use>,
;;; any href / xlink:href, any style attribute, on* / hx-* attributes, any URL
;;; (no xmlns either: inline SVG in HTML needs none). CANVAS:CSP-VIOLATIONS of
;;; every output is NIL, and CANVAS:FREEZE keeps the chart (FREEZE lowercases
;;; attribute names, which the HTML parser undoes for inline SVG;
;;; egao1980/canvas-protocol#3).
;;;
;;; ---------------------------------------------------------------- registration
;;; Loading this system makes *SVG-BACKEND* CANVAS:*CHART-BACKEND* unless
;;; another backend is already there, so (canvas:render chart) and
;;; CANVAS:CHART-NODE draw SVG with no further setup.

(defclass svg-backend (canvas:chart-backend) ()
  (:documentation "Pure-Lisp inline SVG chart backend."))

(defun make-svg-backend ()
  (make-instance 'svg-backend))

(defvar *svg-backend* (make-svg-backend)
  "The shared SVG backend instance (stateless).")

(unless canvas:*chart-backend*
  (setf canvas:*chart-backend* *svg-backend*))

(defun chart-id (chart)
  (declare (ignore chart))
  (%svg0-pending 'chart-id))

(defmethod canvas:render-chart ((backend svg-backend) chart &key id)
  (declare (ignore id))
  (canvas:validate-chart chart)
  (%svg0-pending 'render-chart))
