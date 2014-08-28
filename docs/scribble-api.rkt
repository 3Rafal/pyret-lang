#lang at-exp racket/base

;; TODO
; - get path for loading module docs
; - pull in everything under generated for all-docs
; - turn set-documentation! errors into warnings that report at end of module
; - relax xrefs to support items beyond strings (such as method names)
;   idea here is xref["list" '("get" "to" "method")], with anchor formed
;   by string-join if itemspec is a list.

;; Scribble extensions for creating pyret.code.org documentation

(require scribble/base
         scribble/core
         scribble/decode
         scribble/basic
         scribble/html-properties
         (for-syntax racket/base racket/syntax)
         racket/list
         racket/bool
         racket/dict
         racket/path
         racket/runtime-path
         "scribble-helpers.rkt"
         )

(provide docmodule
         function
         re-export from
         pyret pyret-block
         tag-name
         data-spec
         method-spec
         variants
         constr-spec
         singleton-spec
         with-members
         shared
         a-compound
         a-id
         a-arrow
         a-named-arrow
         a-record
         a-field
         a-app
         a-pred
         a-dot
         members
         member-spec
         lod
         ignore
         ignoremodule
         xref
         init-doc-checker
         append-gen-docs
         curr-module-name
         )

;;;;;;;;; Parameters and Constants ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; tracks the module currently being processed
(define curr-module-name (make-parameter #f))
(define curr-data-spec (make-parameter #f))
(define curr-var-spec (make-parameter #f))
(define curr-method-location (make-parameter #f))
(define EMPTY-XREF-TABLE (make-hash))



;;;;;;;;;; API for generated module information ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Each module specification has the form
;   (module name path (spec-type (field val) ...) ...)
; where
;  - spec-type is one of path, fun-spec, unknown-item, data-spec, constr-spec
;  - each spec-type has a field called name

(define mod-name second)
(define mod-path third)
(define mod-specs cdddr)
(define spec-type first)
(define (spec-fields l) (if (cons? l) (rest l) #f))
(define field-name first)
(define field-val second)



;;;;;;;;;; Functions to sanity check generated documentation ;;;;;;;;;;;;;;;;;;

;; Maybe something like this could be put in the Racket standard library?
(define-runtime-path HERE ".")

(define GEN-BASE (build-path (path-only HERE) "generated" "trove"))
(define curr-doc-checks #f)

;; print a warning message, optionally with name of issuing function
(define (warning funname msg)
  (if funname
      (eprintf "WARNING in ~a: ~s~n" funname msg)
      (eprintf "WARNING: ~s~n" msg)))

(define (read-mod mod)
  (list (mod-name mod)
        (make-hash
         (map (lambda (spec)
                (cons (get-defn-field 'name spec) #f))
              (drop mod 3)))))
(define (init-doc-checker read-docs)
  (map read-mod read-docs))

(define (set-documented! modname name)
  (let ([mod (assoc modname curr-doc-checks)])
    (if mod
        (if (dict-has-key? (second mod) name)
            (if (dict-ref (second mod) name)
                (warning 'set-documented! (format "~s is already documented in module ~s" name modname))
                (dict-set! (second mod) name #t))
            (warning 'set-documented! (format "Unknown identifier ~s in module ~s" name modname)))
        (warning 'set-documented! (format "Unknown module ~s" modname)))))

(define (report-undocumented modname)
  (let ([mod (assoc modname curr-doc-checks)])
    (if mod
        (dict-for-each
         (second mod)
         (lambda (key val)
           (unless val (warning 'report-undocumented
                                (format "Undocumented export ~s from module ~s~n"
                                        key modname)))))
        (warning 'report-undocumented (format "Unknown module ~s" modname)))))

(define (load-gen-docs)
  (let ([all-docs (filter (lambda(f)
                            (let ([str (path->string f)])
                              (and
                                (not (string=? (substring str (- (string-length str) 4)) ".bak"))
                                (not (string=? (substring str (- (string-length str) 1)) "~"))
                                (not (string=? (substring str 0 1) "."))
                                ))
                            ) (directory-list GEN-BASE))])
    (let ([read-docs
           (map (lambda (f) (with-input-from-file (build-path GEN-BASE f) read)) all-docs)])
      (set! curr-doc-checks (init-doc-checker read-docs))
      ;(printf "Modules are ~s~n" (map first curr-doc-checks))
      read-docs)))

;;;;;;;;;;; Functions to extract information from generated documentation ;;;;;;;;;;;;;;

;; finds module with given name within all files in docs/generated/arr/*
;; mname is string naming the module
(define (find-module mname)
  (let ([m (findf (lambda (mspec)
    (equal? (mod-name mspec) mname)) ALL-GEN-DOCS)])
    (unless m
      (error 'find-module (format "Module not found ~a~n" mname)))
    m))

;; finds definition in defn spec list that has given value for designated field
;; by-field is symbol, indefns is list<specs>
(define (find-defn by-field for-val indefns)
  (if (or (empty? indefns) (not indefns))
      #f
      (let ([d (findf (lambda (d)
        (equal? for-val (field-val (assoc by-field (spec-fields d))))) indefns)])
        (unless d
          (warning 'find-defn (format "No definition for field ~a = ~a in module ~s ~n" by-field for-val indefns)))
        d)))

;; defn-spec is '(fun-spec <assoc>)
(define (get-defn-field field defn-spec)
  (if (or (empty? defn-spec) (not defn-spec)) #f
      (let ([f (assoc field (spec-fields defn-spec))])
        (if f (field-val f) #f))))

;; extracts the definition spec for the given function name
;; - will look in all modules to find the name
(define (find-doc mname fname)
  (let ([mdoc (find-module mname)])
    (find-defn 'name fname (drop mdoc 3))))

;;;;;;;;;; Styles ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define css-js-additions (list "style.css"))

(define (div-style name)
  (make-style name (cons (make-alt-tag "div") css-js-additions)))

(define (pre-style name)
  (make-style name (cons (make-alt-tag "pre") css-js-additions)))

(define code-style (make-style "pyret-code" (cons (make-alt-tag "span") css-js-additions)))

(define (span-style name)
  (make-style name (cons (make-alt-tag "span") css-js-additions)))

; style that drops html anchor -- use only with elems
(define (anchored-elem-style anchor)
  (make-style "anchor" (list (make-alt-tag "span") (url-anchor anchor))))

(define (dl-style name) (make-style name (list (make-alt-tag "dl"))))
(define (dt-style name) (make-style name (list (make-alt-tag "dt"))))
(define (dd-style name) (make-style name (list (make-alt-tag "dd"))))

(define (pyret-block . body) (nested #:style (pre-style "pyret-highlight") (nested #:style 'smaller  body)))
(define pyret tt)

;;;;;;;;;; Cross-Reference Infrastructure ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Uses the xref table for error checking that
;   we aren't generating links to unknown targets
; TODO: fix path to html file in "file" definition
(define (xref modname itemname . subitems)
  (apply tag-name (cons modname (cons itemname subitems))))
;  (let [(cur-mod (curr-module-name))]
;    (traverse-element
;     (lambda (get set!)
;       (traverse-element
;        (lambda (get set!)
;          (let* ([xref-table (get 'doc-xrefs '())]
;                 [entry (assoc itemname xref-table)])
;            (when (string=? modname cur-mod)
;                (unless (and entry (string=? (second entry) modname))
;                  (error 'xref "No xref info for ~a in ~a~nxref-table = ~s~n" itemname modname xref-table)))
;            (let* ([file (path->string
;                          (build-path (current-directory)
;                                      (string-append modname ".html#" itemname)))]) ; fix here if change anchor format
;              (hyperlink file itemname)))))))))

; drops an "a name" anchor for cross-referencing
(define (drop-anchor name)
  (elem #:style (anchored-elem-style name) ""))

;;;;;;;;;; Scribble functions used in writing documentation ;;;;;;;;;;;;;;;;;;;

(define (ignoremodule name) "")

(define (ignore specnames)
  (for-each (lambda (n) (set-documented! (curr-module-name) n))
            specnames))

; generates dt for use in dl-style itemizations
(define (dt . args)
  (elem #:style (dt-style "") args))
; generates dt for use in dl-style itemizations
(define (dt-indent . args)
  (elem #:style (dt-style "indent-arg") args))

; generates dd for use in dl-style itemizations
(define (dd . args)
  (elem #:style (dd-style "") args))

;; docmodule is a macro so that we can parameterize the
;; module name before processing functions defined within
;; the module.  Need this since module contents are nested
;; within the module specification in the scribble sources
@(define-syntax (docmodule stx)
   (syntax-case stx ()
     [(_ name args ...)
      (syntax/loc stx
        (parameterize ([curr-module-name name])
          (let ([contents (docmodule-internal name args ...)])
            (report-undocumented name)
            contents)))]))

;; render documentation for all definitions in a module
;; this function does the actual work after syntax expansion
@(define (docmodule-internal name
                             #:friendly-title (friendly-title #f)
                             #:noimport (noimport #f)
                             . defs)
   (interleave-parbreaks/all
    (list (title #:tag (tag-name name) (or friendly-title name))
          (if noimport ""
                       (list (para "Usage:")
                             (nested #:style (pre-style "code") "import " name " as ...")))
          (interleave-parbreaks/all defs))))

@(define (lod . assocLst)
   (let ([render-for "bs"])
     (second (assoc render-for assocLst))))

;; render re-exports
@(define (re-export name from . contents)
   (set-documented! (curr-module-name) name)
   (list "For " (elem #:style (span-style "code") name) ", see " from))

@(define (from where)
   (secref where))

@(define (tag-name . args)
   (apply string-append (add-between args "_")))


@(define-syntax (data-spec stx)
   (syntax-case stx ()
     [(_ name args ...)
      (syntax/loc stx
        (parameterize ([curr-data-spec (find-doc (curr-module-name) name)])
         (let ([contents (data-spec-internal name args ...)])
           contents)))]))
@(define (data-spec-internal name #:params (params #f) . members)
   (set-documented! (curr-module-name) name)
   (let ([processing-module (curr-module-name)])
     (interleave-parbreaks/all
      (list (drop-anchor name)
            (subsubsub*section #:tag (tag-name (curr-module-name) name))
            (traverse-block ; use this to build xrefs on an early pass through docs
             (lambda (get set!)
               (set! 'doc-xrefs (cons (list name processing-module)
                                      (get 'doc-xrefs '())))
               @para{}))
            (interleave-parbreaks/all members)))))
@(define (method-spec name
                      #:params (params #f)
                      #:contract (contract #f)
                      #:return (return #f)
                      #:args (args #f)
                      #:alt-docstrings (alt-docstrings #f)
                      #:examples (examples '())
                      . body)
   (let* ([methods (get-defn-field (curr-method-location) (curr-var-spec))]
          [var-name (get-defn-field 'name (curr-var-spec))]
          [spec (find-defn 'name name methods)])
     (render-fun-helper
      spec name
      (list 'part (tag-name (curr-module-name) var-name name))
      contract return args alt-docstrings examples body)))
@(define (member-spec name #:contract (contract-in #f) . body)
   (let* ([members (get-defn-field 'members (curr-var-spec))]
          [member (if (list? members) (assoc name members) #f)]
          [contract (or contract-in (interp (get-defn-field 'contract member)))])
     (list (dt (if contract (tt name " :: " contract) (tt name)))
           (dd body))))

@(define-syntax (singleton-spec stx)
   (syntax-case stx ()
     [(_ name args ...)
      (syntax/loc stx
        (parameterize ([curr-var-spec (find-doc (curr-module-name) name)]
                       [curr-method-location 'with-members])
          (let ([contents (singleton-spec-internal name args ...)])
            contents)))]))
@(define (singleton-spec-internal name #:private (private #f) . body)
   (if private
       (list (subsubsub*section name) body)
       (begin
         (when (not private) (set-documented! (curr-module-name) name))
         (list (subsubsub*section #:tag (list (tag-name (curr-module-name) name) (tag-name (curr-module-name) (string-append "is-" name))) name) body))))

@(define-syntax (constr-spec stx)
   (syntax-case stx ()
     [(_ name args ...)
      (syntax/loc stx
        (parameterize ([curr-var-spec (find-doc (curr-module-name) name)]
                       [curr-method-location 'with-members])
          (let ([contents (constr-spec-internal name args ...)])
            contents)))]))
@(define (constr-spec-internal name #:params (params #f) #:private (private #f) . body)
   (if private
       (list (subsubsub*section name) body)
       (begin
         (when (not private) (set-documented! (curr-module-name) name))
         (list (subsubsub*section #:tag (list (tag-name (curr-module-name) name) (tag-name (curr-module-name) (string-append "is-" name))) name) body))))

@(define (with-members . members)
   (if (empty? members) 
       empty
       (list "Methods" members)))
@(define (members . mems)
   (if (empty? mems)
       empty
       (list "Fields" (para #:style (dl-style "fields") mems))))
@(define (a-id name . args)
   (if (cons? args) (seclink (first args) name) name))
@(define (a-compound typ . args)
   (if (cons? args) (seclink (first args) typ) typ))
@(define (a-app base . typs)
   (append (list base "<") (add-between typs ", ") (list ">")))
@(define (a-pred base refinement)
   (list base "%(" refinement ")"))
@(define (a-dot base field)
   (list base "." field))
@(define (a-arrow . typs)
   (append (list "(") (add-between typs ", " #:before-last " -> ") (list ")")))
@(define (every-other lst)
  (cond
    [(empty? lst) empty]
    [(cons? lst)
      (define r (rest lst))
      (cond
        [(empty? r) lst]
        [(cons? r) (cons (first lst) (every-other (rest (rest lst))))])]))
@(define (a-named-arrow . names-and-typs)
   (define all-but-last (take names-and-typs (- (length names-and-typs) 1)))
   (define last (first (drop names-and-typs (- (length names-and-typs) 1))))
   (define names (every-other all-but-last))
   (define typs (every-other (rest all-but-last)))
   (define pairs (map (λ (n t) (list n " :: " t)) names typs))
   (append (list "(") (add-between (append pairs (list last)) ", " #:before-last " -> ") (list ")")))
@(define (a-record . fields)
   (append (list "{") (add-between fields ", ") (list "}")))
@(define (a-field name type . desc)
   (append (list name ":") (list type)))
@(define (variants . vars)
   vars)
@(define-syntax (shared stx)
   (syntax-case stx ()
     [(_ args ...)
      (syntax/loc stx
        (parameterize ([curr-var-spec (curr-data-spec)]
                       [curr-method-location 'shared])
          (let ([contents (shared-internal args ...)])
            contents)))]))
@(define (shared-internal . shares)
   (if (empty? shares)
       empty
       (list "Shared Methods" shares)))

@(define (interp an-exp)
   (cond
     [(list? an-exp)
      (let* ([f (first an-exp)]
             [args (map interp (rest an-exp))])
        (cond
          [(symbol=? f 'a-record) (apply a-record args)]
          [(symbol=? f 'a-id) (apply a-id args)]
          [(symbol=? f 'a-compound) (apply a-compound args)]
          [(symbol=? f 'a-arrow) (apply a-arrow args)]
          [(symbol=? f 'a-field) (apply a-field args)]
          [(symbol=? f 'a-app) (apply a-app args)]
          [(symbol=? f 'a-pred) (apply a-pred args)]
          [(symbol=? f 'a-dot) (apply a-dot args)]
          [(symbol=? f 'xref) (apply xref args)]
          [#t an-exp]))]
     [#t an-exp]))


@(define (render-multiline-args names types descrs)
   (map (lambda (name type descr)
          (cond [(and name type descr)
                 (list (dt-indent (tt name " :: " type))
                       (dd descr))]
                [(and name type)
                 (list (dt-indent (tt name " :: " type))
                       (dd ""))]
                [(and name descr)
                 (list (dt-indent (tt name)) (dd descr))]
                [else (list (dt-indent (tt name)) (dd ""))]))
        names types descrs))

@(define (render-singleline-args names types)
  (define args
   (map (lambda (name type)
          (cond [(and name type)
                 (list (tt name " :: " type))]
                [else (list (tt name))]))
        names types))
  (add-between args ", "))

;; render documentation for a function
@(define (render-fun-helper spec name part-tag contract-in return-in args alt-docstrings examples contents)
   (let* ([contract (or contract-in (interp (get-defn-field 'contract spec)))] 
          [return (or return-in (interp (get-defn-field 'return spec)))] 
          [argnames (if (list? args) (map first args) (get-defn-field 'args spec))]
          [input-types (map (lambda(i) (first (drop contract (+ 1 (* 2 i))))) (range 0 (length argnames)))]
          [input-descr (if (list? args) (map second args) (map (lambda(i) #f) argnames))]
          [doc (or alt-docstrings (get-defn-field 'doc spec))]
          [arity (get-defn-field 'arity spec)]
          )
     ;; checklist
     ; - TODO: make sure found funspec or unknown-item
     ; confirm argnames provided
     (unless argnames
       (error 'function (format "Argument names not provided for name ~s" name)))
     ; if contract, check arity against generated
     (unless (or (not arity) (eq? arity (length argnames)))
       (error 'function (format "Provided argument names do not match expected arity ~a ~a" arity name)))
     ;; render the scribble
     ; defining processing-module because raw ref to curr-module-name in traverse-block
     ;  wasn't getting bound properly -- don't know why
     (define is-method (symbol=? (first spec) 'method-spec))
     (let ([processing-module (curr-module-name)])
       (interleave-parbreaks/all
        (list ;;(drop-anchor name)
          (traverse-block ; use this to build xrefs on an early pass through docs
           (lambda (get set!)
             (set! 'doc-xrefs (cons (list name processing-module)
                                    (get 'doc-xrefs '())))
             (define name-tt (if is-method (tt "." name) (seclink (xref processing-module name) (tt name))))
             (printf "Processing: ~a\n" (xref processing-module name))
             (define name-elt (toc-target-element code-style (list name-tt) part-tag))
;             (define name-elt (seclink (xref processing-module name) name-target))
             (define header-part
               (cond
                [(and (< (length argnames) 3) (ormap (lambda (v) (false? v)) input-descr))
                 (apply para #:style (div-style "boxed")
                   (append
                    (list (tt name-elt " :: " "("))
                    (render-singleline-args argnames input-types)
                    (if return
                      (list (tt ")" " -> " return))
                      (list (tt ")")))))] 
                [else 
                 (nested #:style (div-style "boxed")
                 (apply para #:style (dl-style "multiline-args")
                   (append
                    (list (dt name-elt " :: " "("))
                    (render-multiline-args argnames input-types input-descr)
                    (if return
                      (list (dt (tt ")")) (dt (tt "-> " return)))
                      (list (dt (tt ")")))))))]))
             (nested #:style (div-style "function")
                     (cons
                       header-part
                       (interleave-parbreaks/all
                        (append
                          (if doc (list doc) (list))
                          (list (nested #:style (div-style "description") contents))
                          (list (if (andmap whitespace? examples)
                            (nested #:style (div-style "examples") "")
                            (nested #:style (div-style "examples")
                                    (para (bold "Examples:"))
                                    (pyret-block examples)))))))))))))))

@(define (function name
                   #:contract (contract #f)
                   #:return (return #f)
                   #:args (args #f)
                   #:alt-docstrings (alt-docstrings #f)
                   #:examples (examples '())
                   . contents
                   )
   (let ([ans
          (render-fun-helper
           (find-doc (curr-module-name) name) name
           (list 'part (tag-name (curr-module-name) name))
           contract return args alt-docstrings examples contents)])
          ; error checking complete, record name as documented
     (set-documented! (curr-module-name) name)
     ans))

(define ALL-GEN-DOCS (load-gen-docs))

(define (append-gen-docs s-exp)
  (define mod (read-mod s-exp))
  (set! ALL-GEN-DOCS (cons s-exp ALL-GEN-DOCS)))

