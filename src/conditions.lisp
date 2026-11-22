(in-package #:canvas-backend-svg)

;;; Contract stub marker (H4h-1). Deliberately a plain ERROR, not a
;;; canvas-protocol condition, so no test can pass by catching it. Remove
;;; SVG0-PENDING and %SVG0-PENDING once nothing calls them.
;;;
;;; This backend defines no conditions of its own. It signals canvas-protocol's:
;;; - CANVAS:INVALID-CHART (from CANVAS:VALIDATE-CHART, and :FIELD :SERIES for a
;;;   bad series colour, see render.lisp);
;;; - CANVAS:CANVAS-ERROR for a bad :ID or an AXIS-FORMAT that does not return a
;;;   string;
;;; - TYPE-ERROR (CHECK-TYPE) for bad arguments to the exported tick/label
;;;   functions.

(define-condition svg0-pending (error)
  ((name :initarg :name :reader svg0-pending-name))
  (:report (lambda (c s)
             (format s "H4h-1 pending: ~A is not implemented yet" (svg0-pending-name c)))))

(defun %svg0-pending (name)
  (error 'svg0-pending :name name))
