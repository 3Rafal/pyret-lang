#lang racket

;; This sketch comes from Matthias Felleisen:
;; http://lists.racket-lang.org/users/archive/2013-April/057407.html

(require
  profile
  "../runtime.rkt"
  "../string-map.rkt"
  "../ffi-helpers.rkt")
(provide (rename-out [export %PYRET-PROVIDE]))


(define (profile-wrapper pyret-fun)
  (define (wrapped)
    ((p:p-base-app pyret-fun)))
  (profile-thunk wrapped #:threads #t))

(define profile-pfun (p:mk-internal-fun profile-wrapper))

(define export (p:mk-object
  (string-map (list (cons "profile" profile-pfun)))))

