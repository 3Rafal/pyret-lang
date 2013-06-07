#lang racket/base

(require
  pyret/lang/settings
  pyret/lang/pyret
  pyret/lang/eval
  ;; pyret/whalesong/lang/reader
  racket/cmdline
  racket/list
  racket/pretty
  racket/runtime-path
  racket/syntax)


(define-runtime-path pyret-lang-racket "lang/pyret-lang-racket.rkt")
(module test-shell "lang/pyret-lang-racket.rkt"
  (r:define-namespace-anchor test-shell-anchor)
  (r:provide test-shell-anchor))
(require (submod "." test-shell))

(define (make-fresh-namespace)
  (define ns (namespace-anchor->empty-namespace test-shell-anchor))
  (parameterize ([current-namespace ns])
    (namespace-require pyret-lang-racket)
    (namespace-require '(only racket/base current-read-interaction current-print void))
    (current-read-interaction repl-eval-pyret)
    (current-print print-pyret))
  ns)

(define check-mode #f)
(command-line
  #:once-each
  ("--check" "Run in check mode"
   (set! check-mode #t))
  #:args file-and-maybe-other-stuff
  (define pyret-file (first file-and-maybe-other-stuff))
  (define-values (base name dir?) (split-path (simplify-path (path->complete-path pyret-file))))
  (cond
    [check-mode
     (parameterize ([current-load-relative-directory base])
       (define pyret-code (pyret->racket pyret-file (open-input-file pyret-file) #:toplevel #t #:check #t))
       (eval pyret-code (make-fresh-namespace)))]
    [else
     (dynamic-require pyret-file #f)]))

