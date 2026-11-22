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

;;; ---------------------------------------------------------------- ids, colours

(defun %ascii-letter-p (c) (or (char<= #\a c #\z) (char<= #\A c #\Z)))
(defun %ascii-digit-p (c) (char<= #\0 c #\9))
(defun %hex-digit-p (c) (or (%ascii-digit-p c) (char<= #\a c #\f) (char<= #\A c #\F)))

(defun %id-p (id)
  "ID matches [A-Za-z][A-Za-z0-9_-]*."
  (and (stringp id)
       (plusp (length id))
       (%ascii-letter-p (char id 0))
       (every (lambda (c) (or (%ascii-letter-p c) (%ascii-digit-p c) (find c "_-"))) id)))

(defparameter +colour-forms+
  (list (lambda (c)                     ; #rgb or #rrggbb
          (and (member (length c) '(4 7))
               (char= (char c 0) #\#)
               (every #'%hex-digit-p (subseq c 1))))
        (lambda (c)                     ; a CSS colour name
          (and (<= 1 (length c) 20)
               (every (lambda (ch) (char<= #\a ch #\z)) c))))
  "The accepted shapes of a series COLOR, one predicate each.")

(defun %colour-p (c)
  (and (stringp c) (find-if (lambda (p) (funcall p c)) +colour-forms+) t))

(defun %kind-name (kind)
  (string-downcase (symbol-name kind)))

(defun %slug (title)
  "Runs of characters other than ASCII [a-z0-9] -> one \"-\", trimmed, cut to
32 characters, trimmed again."
  (let ((s (with-output-to-string (out)
             (let ((gap nil) (any nil))
               (loop for ch across (string-downcase title)
                     do (if (or (char<= #\a ch #\z) (%ascii-digit-p ch))
                            (progn (when (and gap any) (write-char #\- out))
                                   (write-char ch out)
                                   (setf gap nil any t))
                            (setf gap t)))))))
    (string-trim "-" (subseq s 0 (min 32 (length s))))))

(defun chart-id (chart)
  (let* ((title (canvas:chart-title chart))
         (slug (if (stringp title) (%slug title) "")))
    (concatenate 'string "chart-"
                 (if (plusp (length slug)) slug (%kind-name (canvas:chart-kind chart))))))

;;; ---------------------------------------------------------------- axes

(defstruct (%ax (:constructor %make-ax (scale d0 d1 px0 px1 &optional ticks tip)))
  "One axis: SCALE (:linear :log :time, or :band for bar x), domain [D0, D1],
pixel ends PX0 (at D0) and PX1 (at D1), TICKS as (pixel . label) pairs in
ascending value order, TIP the value printer for tooltips."
  scale d0 d1 px0 px1 ticks tip)

(defun %round (r)
  (values (floor (+ r 1/2))))

(defun %lg (x)
  (or (%power-of-ten x) (/ (log (float x 1d0)) (log 10d0))))

(defun %pos (ax v)
  "The rounded pixel of the value V on AX (clamped into the domain)."
  (let* ((d0 (%ax-d0 ax))
         (d1 (%ax-d1 ax))
         (v (max d0 (min d1 (%rat v))))
         (u (if (eq (%ax-scale ax) :log)
                (/ (- (%lg v) (%lg d0)) (- (%lg d1) (%lg d0)))
                (/ (- v d0) (- d1 d0))))
         (p (+ (%ax-px0 ax) (* u (- (%ax-px1 ax) (%ax-px0 ax))))))
    (%round (rational p))))

(defun %axis-printer (axis default)
  "The printer of AXIS values: its FORMAT when given, else DEFAULT."
  (let ((f (canvas:axis-format axis)))
    (typecase f
      (null default)
      (string (lambda (v) (format nil f v)))
      (t (lambda (v)
           (let ((r (funcall f v)))
             (if (stringp r)
                 r
                 (error 'canvas:canvas-error
                        :message (format nil "axis format returned ~S, not a string" r)))))))))

(defun %make-axis (axis scale values px0 px1 &key exact)
  "Domain, ticks and printers of AXIS for VALUES, drawn from PX0 to PX1. Tick
labels are made here, so a bad axis FORMAT signals before any mark is built."
  (multiple-value-bind (d0 d1 auto labeller)
      (%axis-domain scale values (canvas:axis-min axis) (canvas:axis-max axis) :exact exact)
    (let* ((explicit (canvas:axis-ticks axis))
           (inside (lambda (v) (<= d0 v d1)))
           (ticks (remove-if-not inside
                                 (if explicit
                                     (sort (remove-duplicates (mapcar #'%rat explicit) :test #'=)
                                           #'<)
                                     auto)))
           (ticks (if (and (eq scale :log) (null explicit) (null ticks))
                      (list d0 d1)
                      ticks))
           (default-tip (if (eq scale :time) #'format-time #'format-number))
           (label (%axis-printer axis (if explicit default-tip labeller)))
           (ax (%make-ax scale d0 d1 px0 px1 nil (%axis-printer axis default-tip))))
      (setf (%ax-ticks ax)
            (mapcar (lambda (v) (cons (%pos ax v) (funcall label v))) ticks))
      ax)))

(defun %x-axis-group (ax yb label h)
  (let ((x0 (%ax-px0 ax)) (x1 (%ax-px1 ax)))
    (canvas:el :g nil
               (canvas:el :line (list :x1 x0 :y1 yb :x2 x1 :y2 yb :stroke "currentColor"))
               (loop for (p . text) in (%ax-ticks ax)
                     collect (canvas:el :line (list :x1 p :y1 yb :x2 p :y2 (+ yb 6)
                                                    :stroke "currentColor"))
                     collect (canvas:el :text (list :x p :y (+ yb 20) :text-anchor "middle") text))
               (when label
                 (canvas:el :text (list :x (%round (/ (+ x0 x1) 2)) :y (- h 12)
                                        :text-anchor "middle")
                            label)))))

(defun %y-axis-group (ax x0 label)
  (let ((yb (%ax-px0 ax)) (yt (%ax-px1 ax)))
    (canvas:el :g nil
               (canvas:el :line (list :x1 x0 :y1 yb :x2 x0 :y2 yt :stroke "currentColor"))
               (loop for (p . text) in (%ax-ticks ax)
                     collect (canvas:el :line (list :x1 (- x0 6) :y1 p :x2 x0 :y2 p
                                                    :stroke "currentColor"))
                     collect (canvas:el :text (list :x (- x0 9) :y (+ p 4) :text-anchor "end") text))
               (when label
                 (canvas:el :text (list :transform (format nil "translate(16,~D) rotate(-90)"
                                                           (%round (/ (+ yb yt) 2)))
                                        :text-anchor "middle")
                            label)))))

;;; ---------------------------------------------------------------- marks

(defun %points (series)
  (coerce (canvas:series-points series) 'list))

(defun %tip (series i default)
  "The tooltip of point I: the series' label when it has LABELS, else DEFAULT
\(a function of no arguments)."
  (let ((labels (canvas:series-labels series)))
    (if labels (elt labels i) (funcall default))))

(defun %titled (tag attrs tip)
  (canvas:el tag attrs (canvas:el :title nil tip)))

(defun %xy-tip (ax ay x y)
  (lambda ()
    (concatenate 'string (funcall (%ax-tip ax) (%rat x)) ", " (funcall (%ax-tip ay) (%rat y)))))

(defun %line-marks (series ax ay)
  (let ((points (%points series)))
    (append
     (when (cdr points)
       (list (canvas:el :polyline
                        (list :points (format nil "~{~D,~D~^ ~}"
                                              (loop for (x . y) in points
                                                    collect (%pos ax x) collect (%pos ay y)))
                              :fill "none" :stroke "currentColor" :stroke-width 2))))
     (loop for (x . y) in points
           for i from 0
           collect (%titled :circle (list :cx (%pos ax x) :cy (%pos ay y) :r 3
                                          :fill "currentColor")
                            (%tip series i (%xy-tip ax ay x y)))))))

(defun %scatter-marks (series ax ay)
  (loop for (x . y) in (%points series)
        for i from 0
        collect (%titled :circle (list :cx (%pos ax x) :cy (%pos ay y) :r 4 :fill "currentColor")
                         (%tip series i (%xy-tip ax ay x y)))))

(defun %base (ay)
  "The value bars grow from: 0 clamped into the domain (d0 for :log)."
  (if (eq (%ax-scale ay) :log)
      (%ax-d0 ay)
      (max (%ax-d0 ay) (min (%ax-d1 ay) 0))))

(defun %bar-rect (left right v ay tip)
  (let* ((base (%base ay))
         (top (%pos ay (max v base)))
         (bottom (%pos ay (min v base))))
    (%titled :rect (list :x left :y top :width (- right left) :height (- bottom top)
                         :fill "currentColor")
             tip)))

(defun %categories (all-series)
  (let ((cats '()))
    (dolist (s all-series (nreverse cats))
      (dolist (p (%points s))
        (pushnew (car p) cats :test #'string=)))))

(defun %bar-marks (series si nseries cats x0 bw ay)
  (let ((w (/ (* 8/10 bw) nseries)))
    (loop for (cat . v) in (%points series)
          for i from 0
          for c = (position cat cats :test #'string=)
          collect (let ((left (+ x0 (* c bw) (/ bw 10) (* si w))))
                    (%bar-rect (%round left) (%round (+ left w)) (%rat v) ay
                               (%tip series i
                                     (let ((cat cat) (v v))
                                       (lambda ()
                                         (concatenate 'string cat ", "
                                                      (funcall (%ax-tip ay) (%rat v)))))))))))

(defun %bin-counts (values lo hi bins)
  "A list of BINS counts of VALUES over [LO, HI]; values outside are not counted."
  (let ((counts (make-array bins :initial-element 0)))
    (dolist (v values (coerce counts 'list))
      (let ((v (%rat v)))
        (when (<= lo v hi)
          (incf (aref counts (min (1- bins) (floor (* (- v lo) bins) (- hi lo))))))))))

(defun %histogram-marks (counts si nseries bins ax ay)
  (let* ((lo (%ax-d0 ax))
         (width (/ (- (%ax-d1 ax) lo) bins))
         (share (/ width nseries)))
    (loop for count in counts
          for k from 0
          collect (let* ((a (+ lo (* k width)))
                         (b (+ a width))
                         (left (+ a (* si share))))
                    (%bar-rect (%pos ax left) (%pos ax (+ left share)) count ay
                               (concatenate 'string (funcall (%ax-tip ax) a) " to "
                                            (funcall (%ax-tip ax) b) ": "
                                            (format nil "~D" count)))))))

(defun %series-group (series index marks)
  (canvas:el :g (list :data-series (1+ (mod index (length canvas:*chart-palette*)))
                      :color (canvas:series-color series))
             marks))

(defun %legend (all-series x0)
  (let ((cx x0))
    (canvas:el :g nil
               (loop for s in all-series
                     for i from 0
                     for name = (canvas:series-name s)
                     collect (canvas:el :rect (list :data-series (1+ (mod i (length canvas:*chart-palette*)))
                                                    :color (canvas:series-color s)
                                                    :x cx :y 6 :width 10 :height 10
                                                    :fill "currentColor"))
                     collect (canvas:el :text (list :x (+ cx 14) :y 16) name)
                     do (incf cx (+ 14 (* 7 (length name)) 16))))))

;;; ---------------------------------------------------------------- tree

(defparameter +kind-texts+
  '((:line "Line chart" "point")
    (:bar "Bar chart" "bar")
    (:scatter "Scatter chart" "point")
    (:histogram "Histogram" "value"))
  "kind -> (default title, desc noun).")

(defun %description (chart label noun)
  (or (canvas:chart-description chart)
      (let ((series (canvas:chart-series chart)))
        (format nil "~A of ~D series: ~{~A~^, ~}." label (length series)
                (loop for s in series
                      for n = (length (canvas:series-points s))
                      collect (format nil "~A (~D ~A~P)" (canvas:series-name s) n noun n))))))

(defun %legend-p (chart)
  (let ((legend (canvas:chart-legend chart)))
    (or (eq legend t)
        (and (eq legend :auto) (cdr (canvas:chart-series chart)) t))))

(defun %series-values (series key)
  (loop for s in series nconc (mapcar key (%points s))))

(defun %plot (chart x0 x1 yb yt)
  "-> (values x-axis y-axis series-groups) for CHART in the plot box."
  (let* ((kind (canvas:chart-kind chart))
         (series (canvas:chart-series chart))
         (xa (canvas:chart-x-axis chart))
         (ya (canvas:chart-y-axis chart))
         (y-scale (canvas:axis-scale ya))
         (zero (if (eq y-scale :log) '() (list 0))))
    (ecase kind
      ((:line :scatter)
       (let ((ax (%make-axis xa (canvas:axis-scale xa) (%series-values series #'car) x0 x1))
             (ay (%make-axis ya y-scale (%series-values series #'cdr) yb yt)))
         (values ax ay
                 (loop for s in series for i from 0
                       collect (%series-group s i (if (eq kind :line)
                                                      (%line-marks s ax ay)
                                                      (%scatter-marks s ax ay)))))))
      (:bar
       (let* ((cats (%categories series))
              (bw (/ (- x1 x0) (max 1 (length cats))))
              (ax (%make-ax :band 0 1 x0 x1
                            (loop for cat in cats for c from 0
                                  collect (cons (%round (+ x0 (* c bw) (/ bw 2))) cat))))
              (ay (%make-axis ya y-scale (append (%series-values series #'cdr) zero) yb yt))
              (n (length series)))
         (values ax ay
                 (loop for s in series for i from 0
                       collect (%series-group s i (%bar-marks s i n cats x0 bw ay))))))
      (:histogram
       (let* ((bins (canvas:chart-bins chart))
              (ax (%make-axis xa :linear (%series-values series #'identity) x0 x1 :exact t))
              (counts (loop for s in series
                            collect (%bin-counts (%points s) (%ax-d0 ax) (%ax-d1 ax) bins)))
              (ay (%make-axis ya y-scale
                              (append (if (eq y-scale :log)
                                          (remove-if-not #'plusp (reduce #'append counts))
                                          (reduce #'append counts))
                                      zero)
                              yb yt))
              (n (length series)))
         (values ax ay
                 (loop for s in series for c in counts for i from 0
                       collect (%series-group s i (%histogram-marks c i n bins ax ay)))))))))

(defun %figure (chart id)
  (let* ((kind (canvas:chart-kind chart))
         (texts (rest (assoc kind +kind-texts+)))
         (title (or (canvas:chart-title chart) (first texts)))
         (w (canvas:chart-width chart))
         (h (canvas:chart-height chart))
         (x-label (canvas:axis-label (canvas:chart-x-axis chart)))
         (y-label (canvas:axis-label (canvas:chart-y-axis chart)))
         (legendp (%legend-p chart))
         (x0 (if y-label 72 56))
         (x1 (max (- w 16) (1+ x0)))
         (yt (if legendp 40 16))
         (yb (max (- h (if x-label 56 40)) (1+ yt))))
    (multiple-value-bind (ax ay groups) (%plot chart x0 x1 yb yt)
      (canvas:el :figure (list :data-chart (%kind-name kind))
                 (stack-html:make-html-element
                  "svg"
                  :attributes (list (cons "id" id)
                                    (cons "viewBox" (format nil "0 0 ~D ~D" w h))
                                    (cons "role" "img")
                                    (cons "aria-labelledby"
                                          (concatenate 'string id "-title " id "-desc"))
                                    (cons "fill" "currentColor")
                                    (cons "font-family" "sans-serif")
                                    (cons "font-size" "12"))
                  :children (canvas:render
                             (list (canvas:el :title (list :id (concatenate 'string id "-title"))
                                              title)
                                   (canvas:el :desc (list :id (concatenate 'string id "-desc"))
                                              (%description chart (first texts) (second texts)))
                                   (%x-axis-group ax yb x-label h)
                                   (%y-axis-group ay x0 y-label)
                                   groups
                                   (when legendp (%legend (canvas:chart-series chart) x0)))))
                 (when (canvas:chart-title chart)
                   (canvas:el :figcaption nil (canvas:chart-title chart)))))))

;;; ---------------------------------------------------------------- entry

(defmethod canvas:render-chart ((backend svg-backend) chart &key id)
  (canvas:validate-chart chart)
  (let ((id (or id (chart-id chart))))
    (unless (%id-p id)
      (error 'canvas:canvas-error :message (format nil "invalid chart id ~S" id)))
    (dolist (s (canvas:chart-series chart))
      (let ((c (canvas:series-color s)))
        (when (and c (not (%colour-p c)))
          (error 'canvas:invalid-chart
                 :field :series
                 :reason (format nil "series ~S: colour ~S is not #rgb, #rrggbb or a lowercase name"
                                 (canvas:series-name s) c)))))
    (%figure chart id)))
