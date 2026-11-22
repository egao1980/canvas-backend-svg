(in-package #:canvas-backend-svg)

;;; This backend defines no conditions of its own. It signals canvas-protocol's:
;;; - CANVAS:INVALID-CHART (from CANVAS:VALIDATE-CHART, and :FIELD :SERIES for a
;;;   bad series colour, see render.lisp);
;;; - CANVAS:CANVAS-ERROR for a bad :ID or an AXIS-FORMAT that does not return a
;;;   string;
;;; - TYPE-ERROR (CHECK-TYPE) for bad arguments to the exported tick/label
;;;   functions.
