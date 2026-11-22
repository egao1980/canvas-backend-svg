(defpackage #:canvas-backend-svg
  (:use #:cl)
  (:nicknames #:stack-canvas-svg)
  (:export
   ;; backend + registration
   #:svg-backend #:make-svg-backend #:*svg-backend*
   #:chart-id
   ;; ticks
   #:nice-ticks #:log-ticks #:time-ticks
   ;; labels
   #:format-number #:format-tick #:format-log-tick #:format-time-tick #:format-time
   ;; theming
   #:palette-css))

(in-package #:canvas-backend-svg)
