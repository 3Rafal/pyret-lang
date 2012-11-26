#lang typed/racket

(provide
 (struct-out none)
 (struct-out p-object)
 (struct-out p-list)
 (struct-out p-num)
 (struct-out p-bool)
 (struct-out p-str)
 (struct-out p-fun)
 get-dict
 get-seal
 get-field
 has-field?
 reseal
 (rename-out [seal-pfun seal])
 (rename-out [brander-pfun brander]))


(define-type Value (U p-object p-list p-num p-bool p-str p-fun))

(define-type Dict (HashTable String Value))
(define-type Seal (U (Setof String) none))

(struct: none () #:transparent)
;; Everything has a seal, a set of brands, and a dict
(struct: p-object ((seal : Seal) 
                   (brands : (Setof Symbol))
                   (dict : Dict)) #:transparent)
(struct: p-list ((l : (Listof Value))
                 (seal : Seal) 
                 (brands : (Setof Symbol)) 
                 (dict : Dict)) #:transparent)
(struct: p-num ((n : Number) 
                (seal : Seal) 
                (brands : (Setof Symbol)) 
                (dict : Dict)) #:transparent)
(struct: p-bool ((b : Boolean) 
                 (seal : Seal) 
                 (brands : (Setof Symbol)) 
                 (dict : Dict)) #:transparent)                
(struct: p-str ((s : String) 
                (seal : Seal) 
                (brands : (Setof Symbol)) 
                (dict : Dict)) #:transparent)
(struct: p-fun ((f : Procedure) 
                (seal : Seal) 
                (brands : (Setof Symbol)) 
                (dict : Dict)) #:transparent)

(define: (mk-object (dict : Dict)) : Value
  (p-object (none) (set) dict))

(define: (mk-list (l : (Listof Value))) : Value
  (p-list l (none) (set) (make-hash)))

(define: (mk-num (n : Number)) : Value
  (p-num n (none) (set) (make-hash)))

(define: (mk-bool (b : Boolean)) : Value
  (p-bool b (none) (set) (make-hash)))

(define: (mk-str (s : String)) : Value
  (p-str s (none) (set) (make-hash)))

(define: (mk-fun (f : Procedure)) : Value
  (p-fun f (none) (set) (make-hash)))

(define: (get-dict (v : Value)) : Dict
  (match v
    [(p-object _ _ h) h]
    [(p-list _ _ _ h) h]
    [(p-num _ _ _ h) h]
    [(p-bool _ _ _ h) h]
    [(p-str _ _ _ h) h]
    [(p-fun _ _ _ h) h]))

(define: (get-seal (v : Value)) : Seal
  (match v
    [(p-object s _ _) s]
    [(p-list _ s _ _) s]
    [(p-num _ s _ _) s]
    [(p-bool _ s _ _) s]
    [(p-str _ s _ _) s]
    [(p-fun _ s _ _) s]))

(define: (get-brands (v : Value)) : (Setof Symbol)
  (match v
    [(p-object _ b _) b]
    [(p-list _ _ b _) b]
    [(p-num _ _ b _) b]
    [(p-bool _ _ b _) b]
    [(p-str _ _ b _) b]
    [(p-fun _ _ b _) b]))

(define: (get-field (v : Value) (f : String)) : Value
  (if (has-field? v f)
      (hash-ref (get-dict v) f)
      (error (string-append "get-field: field not found: " f))))

(define: (reseal (v : Value) (new-seal : Seal)) : Value
  (match v
    [(p-object _ b h) (p-object new-seal b h)]
    [(p-list l _ b h) (p-list l new-seal b h)]
    [(p-num n _ b h) (p-num n new-seal b h)]
    [(p-bool t _ b h) (p-bool t new-seal b h)]
    [(p-str s _ b h) (p-str s new-seal b h)]
    [(p-fun f _ b h) (p-fun f new-seal b h)]))

(define: (add-brand (v : Value) (new-brand : Symbol)) : Value
  (define: bs : (Setof Symbol) (set-union (get-brands v) (set new-brand)))
  (match v
    [(p-object s _ h) (p-object s bs h)]
    [(p-list l s _ h) (p-list l s bs h)]
    [(p-num n s _ h) (p-num n s bs h)]
    [(p-bool t s _ h) (p-bool t s bs h)]
    [(p-str s sl _ h) (p-str s sl bs h)]
    [(p-fun f s _ h) (p-fun f s bs h)]))

(define: (has-brand? (v : Value) (brand : Symbol)) : Boolean
  (set-member? (get-brands v) brand))

(define: (has-field? (v : Value) (f : String)) : Boolean
  (define d (get-dict v))
  (define s (get-seal v))
  (and (or (none? s)
           (set-member? s f))
       (hash-has-key? d f)))

(define: (seal (object : Value) (fields : Value)) : Value
  (define: (get-strings (strs : (Listof Value))) : (Setof String)
    (foldr (lambda: ((v : Value) (s : (Setof String)))
             (if (p-str? v)
                 (set-add s (p-str-s v))
                 (error "seal: found non-string in constraint list")))
           ((inst set String))
           strs))
  (if (not (p-list? fields))
      (error "seal: found non-list as constraint")
      (local [(define current-seal (get-seal object))
              (define effective-seal (if (none? current-seal)
                                         (apply set (hash-keys (get-dict object)))
                                         current-seal))
              (define fields-seal (get-strings (p-list-l fields)))]
        (begin 
          (when (not (subset? fields-seal effective-seal))
            (error "seal: cannot seal unmentionable fields"))
          (reseal object (set-intersect fields-seal effective-seal))))))

(define seal-pfun (mk-fun seal))


(define: (brander) : Value
  (define: sym : Symbol (gensym))
  (mk-object 
   (make-hash 
    `(("brand" .
       ,(mk-fun (lambda: ((v : Value))
                 (add-brand v sym))))
      ("check" .
       ,(mk-fun (lambda: ((v : Value))
                 (mk-bool (has-brand? v sym)))))))))

(define brander-pfun (mk-fun brander))

