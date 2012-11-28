#lang racket

(provide (rename-out [my-read read]
                     [my-read-syntax read-syntax]))

(require "tokenizer.rkt" "compile.rkt" "desugar.rkt" "typecheck.rkt")
(require racket/runtime-path)

(define-runtime-module-path parser "parser.rkt")
(define-runtime-module-path pyret-lang "pyret-lang.rkt")
(define-runtime-module-path full-eval "eval.rkt")

(dynamic-require parser 0)
(define ns (module->namespace (resolved-module-path-name parser)))

(dynamic-require pyret-lang 0)

(define (my-read in)
  (syntax->datum (my-read-syntax #f in)))

(define (my-read-syntax src in)
  (with-syntax
     ([pyret-lang-stx (path->string (resolved-module-path-name pyret-lang))]
      [full-eval-stx (path->string (resolved-module-path-name full-eval))]
      [stx 
       (compile-pyret 
        (typecheck-pyret 
         (desugar-pyret (eval (get-syntax src in) ns))))])
        #'(module src (file pyret-lang-stx)
            (require (file full-eval-stx))
            (current-read-interaction eval-pyret)
            (void (current-print print-pyret))
            stx)))

