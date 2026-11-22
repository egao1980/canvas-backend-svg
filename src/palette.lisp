(in-package #:canvas-backend-svg)

;;; Colour without fixed inline colours (H4h-1, locked).
;;;
;;; The SVG never contains a colour literal of its own. Every mark is painted
;;; with currentColor, and each series' group carries data-series="<n>", n =
;;; 1 + (series index mod (length canvas:*chart-palette*)), 1-based, so a
;;; stylesheet (engels, H4h-0b, or canvas-protocol's placeholder theme) maps
;;; n to a colour. Axes and text use currentColor too, so light/dark themes
;;; work without JS and the output survives FREEZE (no <style>, no style=).
;;; A series' own COLOR is the one exception: it is the caller's choice, set
;;; as the SVG presentation attribute color="<value>" (render.lisp).
;;;
;;; PALETTE-CSS &optional (palette canvas:*chart-palette*) -> string: the rules
;;; a theme includes to colour series, one line per palette entry, each ending
;;; in a newline, in palette order:
;;;   figure[data-chart] [data-series="1"]:not([color]) { color: var(--chart-1, #E69F00); }
;;; i.e. (format nil "figure[data-chart] [data-series=\"~D\"]:not([color]) { color: var(--chart-~D, ~A); }~%" n n colour).
;;; The custom property lets a theme re-point --chart-<n> (e.g. per
;;; prefers-color-scheme) without restating the selectors; the :not([color])
;;; keeps a caller's series COLOR (an author rule would otherwise beat the
;;; presentation attribute). PALETTE must be a non-empty list of strings
;;; (CHECK-TYPE list, every element a string, else TYPE-ERROR).
;;;
;;; canvas-protocol 0.1.0's placeholder canvas.css has no such rules yet, so
;;; under it series are drawn in the text colour (still distinguishable by
;;; legend order and tooltips). Adding data-series to the canvas data-*
;;; vocabulary and these rules to the themes is a canvas-protocol minor
;;; (egao1980/canvas-protocol#2); nothing in this backend changes when it lands.

(defun palette-css (&optional (palette canvas:*chart-palette*))
  (check-type palette (and list (not null)))
  (dolist (colour palette)
    (unless (stringp colour)
      (error 'type-error :datum colour :expected-type 'string)))
  (with-output-to-string (s)
    (loop for colour in palette
          for n from 1
          do (format s "figure[data-chart] [data-series=\"~D\"]:not([color]) { color: var(--chart-~D, " n n)
             (write-string colour s)
             (write-string "); }" s)
             (terpri s))))
