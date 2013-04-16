#lang racket

(provide
  repl-eval-pyret
  print-pyret
  pyret->racket
  pyret->racket/libs
  pyret-eval
  py-eval)
(require
  racket/sandbox
  racket/runtime-path
  syntax/strip-context
  "tokenizer.rkt"
  "desugar.rkt"
  "typecheck.rkt"
  "compile.rkt"
  "load.rkt"
  "runtime.rkt")

(define-runtime-path parser "parser.rkt")
(define-runtime-path ast "ast.rkt")
(define-runtime-path runtime "runtime.rkt")
(define-runtime-module-path pyret-lang "pyret-lang.rkt")
;(dynamic-require pyret-lang #f)
(define-runtime-path pyret-base-path (simplify-path (build-path "." 'up 'up)))

(define (py-eval)
  (let ([specs (sandbox-namespace-specs)])
    (parameterize [(sandbox-namespace-specs (cons make-base-namespace
                                                  (list runtime)))
                   (sandbox-path-permissions `((read ,pyret-base-path)))]
    (define module-syntax
     (with-syntax
       ([pyret-lang-stx (path->string (resolved-module-path-name pyret-lang))])
        (strip-context #'(module src (file pyret-lang-stx) (r:begin)))))
    (make-module-evaluator module-syntax))))

(define (pyret-eval stx)
  (define make-fresh-namespace (eval
                              '(lambda ()
                                 (variable-reference->empty-namespace
                                  (#%variable-reference)))
                              (make-base-namespace)))
  (define ns (make-fresh-namespace))
  (parameterize ([current-namespace ns])
    (namespace-require pyret-lang))
  (eval stx ns))

(define (stx->racket stx desugar)
  (strip-context
   (compile-pyret
    (contract-check-pyret
     (desugar
      (parse-eval stx))))))

(define (pyret->racket src in)
  (stx->racket (get-syntax src in) desugar-pyret))

(define (pyret->racket/libs src in)
  (stx->racket (get-syntax src in) desugar-pyret/libs))

(define (repl-eval-pyret src in)
  ;; the parameterize is stolen from 
  ;; http://docs.racket-lang.org/reference/eval.html?(def._((quote._~23~25kernel)._current-read-interaction))
  (parameterize ([read-accept-reader #t]
                 [read-accept-lang #f])
    (if (eof-object? (peek-char in))
        eof
        (pyret->racket src in))))

(define (simplify-pyret val)
  (match val
    [(? (λ (v) (eq? v nothing))) nothing]
    [(p:p-num _ _ _ n) n]
    [(p:p-str _ _ _ s) s]
    [(p:p-bool _ _ _ b) b]
    [(p:p-object (p:none) _ d)
     (make-hash (hash-map d (lambda (s v) (cons s (simplify-pyret v)))))]
    [(p:p-object (? set? s) _ d)
     (make-hash (set-map s (lambda (s) (cons s (simplify-pyret (hash-ref d s))))))]
    [(? p:p-base?) val]
    [_ (void)]))

(define ((print-pyret printer) val)
  (when (not (equal? val nothing))
    (match val
      [(p:p-opaque v) (printer v)]
      [_ (pretty-write (simplify-pyret val))])))

