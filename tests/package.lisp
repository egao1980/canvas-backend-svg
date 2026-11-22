(defpackage #:canvas-backend-svg/tests
  (:use #:cl #:rove #:canvas-backend-svg))

(in-package #:canvas-backend-svg/tests)

;;; Helpers shared by every test file.

(defun q (string)
  "STRING with every ' replaced by a double quote (golden SVG stays readable)."
  (substitute #\" #\' string))

(defun s+ (&rest strings)
  (apply #'concatenate 'string strings))

(defun contains (needle haystack)
  (and (search needle haystack) t))

(defun occurrences (needle haystack)
  (loop with n = 0
        for start = (search needle haystack) then (search needle haystack :start2 (1+ start))
        while start do (incf n)
        finally (return n)))

(defun svg (chart &rest keys)
  "TO-HTML of the SVG backend's figure for CHART."
  (canvas:to-html (apply #'canvas:render-chart *svg-backend* chart keys)))

(defun node (chart &rest keys)
  (apply #'canvas:render-chart *svg-backend* chart keys))

(defun axis (&rest args)
  (apply #'canvas:make-axis args))

(defun series (name points &rest args)
  (apply #'canvas:make-series name points args))

(defun chart (kind &rest args)
  (apply #'canvas:make-chart kind args))

(defun ut (year month day &optional (hour 0) (minute 0) (second 0))
  (encode-universal-time second minute hour day month year 0))

(defun walk-elements (tree fn)
  (labels ((walk (n)
             (cond ((listp n) (mapc #'walk n))
                   ((stack-html:html-element-p n)
                    (funcall fn n)
                    (mapc #'walk (stack-html:html-element-children n))))))
    (walk tree)))

(defun elements-named (tree name)
  (let ((found '()))
    (walk-elements tree (lambda (e)
                          (when (string-equal name (stack-html:html-element-name e))
                            (push e found))))
    (nreverse found)))

(defun attr (element name)
  (stack-html:element-attr element name))

(defun child-elements (element)
  (remove-if-not #'stack-html:html-element-p (stack-html:html-element-children element)))

(defun text-labels (html)
  "The contents of every <text>…</text> in HTML, in order."
  (loop with out = '()
        for start = (search "<text" html) then (search "<text" html :start2 end)
        while start
        for open-end = (position #\> html :start start)
        for end = (search "</text>" html :start2 open-end)
        do (push (subseq html (1+ open-end) end) out)
        finally (return (nreverse out))))

(defun tooltips (html)
  "The contents of every <title>…</title> in HTML after the chart's own title."
  (rest (loop with out = '()
              for start = (search "<title" html) then (search "<title" html :start2 end)
              while start
              for open-end = (position #\> html :start start)
              for end = (search "</title>" html :start2 open-end)
              do (push (subseq html (1+ open-end) end) out)
              finally (return (nreverse out)))))
