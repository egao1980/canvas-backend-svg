(defpackage #:canvas-backend-svg/tests
  (:use #:cl #:rove))

(in-package #:canvas-backend-svg/tests)

(deftest package-exists
  (ok (find-package :canvas-backend-svg)))
