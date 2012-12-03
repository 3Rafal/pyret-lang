#lang racket

(require "test-utils.rkt" "../lang/ast.rkt")

(define-syntax check/block
  (syntax-rules ()
    [(_ str stmt ...)
     (check-match (parse-pyret str) (s-block _ (list stmt ...)))]))

(check/block "'str'" (s-str _ "str"))
(check/block "5" (s-num _ 5))

(check/block "true" (s-bool _ #t))
(check/block "false" (s-bool _ #f))

(check/block "5 'foo'" (s-num _ 5) (s-str _ "foo"))

(check/block "{}" (s-obj _ empty))
(check/block "{x:5}" (s-obj _ (list (s-field _ "x" (s-num _ 5)))))
(check/block "{x:5,y:'foo'}" (s-obj _ (list (s-field _ "x" (s-num _ 5))
                                                            (s-field _ "y" (s-str _ "foo")))))
(check/block "{x:{}}" (s-obj _ (list (s-field _ "x" (s-obj _ empty)))))

(check/block "x" (s-id _ 'x))
(check/block "{x:x}" (s-obj _ (list (s-field _ "x" (s-id _ 'x)))))

(check/block "f()" (s-app _ (s-id _ 'f) empty))
(check/block "f(5)" (s-app _ (s-id _ 'f) (list (s-num _ 5))))

(check/block "f(5,'foo')" (s-app _ (s-id _ 'f) (list (s-num _ 5) (s-str _ "foo"))))

(check/block "fun f(): 5 end"
            (s-fun _ 'f empty (a-blank) (s-block _ (list (s-num _ 5)))))

(check/block "fun g(g): 5 end"
            (s-fun _ 'g (list (s-bind _ 'g (a-blank))) (a-blank)
                   (s-block _ (list (s-num _ 5)))))

(check/block "fun g(g,f,x): 5 end"
             (s-fun _ 'g (list (s-bind _ 'g (a-blank)) 
                               (s-bind _ 'f (a-blank)) 
                               (s-bind _ 'x (a-blank))) (a-blank)
                    (s-block _ (list (s-num _ 5)))))

(check/block "def g: 5"
             (s-def _ (s-bind _ 'g (a-blank)) (s-num _ 5)))

(check/block "[]" (s-list _ empty))
(check/block "[5]" (s-list _ (list (s-num _ 5))))

(check/block "o.x" (s-dot _ (s-id _ 'o) 'x))
(check/block "seal({x:5}, []).x"
             (s-dot _ (s-app _ (s-id _ 'seal) (list (s-obj _ (list (s-field _ "x" (s-num _ 5))))
                                                    (s-list _ empty)))
                    'x))

(check/block "o.['x']" (s-bracket _ (s-id _ 'o) (s-str _ "x")))
(check/block "x = 1" (s-assign _ 'x (s-num _ 1)))
(check/block "o.x = 1" (s-dot-assign _ (s-id _ 'o) 'x (s-num _ 1)))
(check/block "o.['x'] = 1" 
            (s-bracket-assign _ (s-id _ 'o) (s-str _ "x") (s-num _ 1)))

(check/block "brander()"
             (s-app _ (s-id _ 'brander) (list)))

(check/block "3.add" (s-dot _ (s-num _ 3) 'add))

(check/block "{extend {x:5} with y:3}"
             (s-onion _
                      (s-obj _ (list (s-field _ "x" (s-num _ 5))))
                      (list (s-field _ "y" (s-num _ 3)))))

(check/block "{extend 5 with foo: 12}"
             (s-onion _
                      (s-num _ 5)
                      (list (s-field _ "foo" (s-num _ 12)))))

(check/block "{extend List with length: 0, width: 0}"
             (s-onion _
                      (s-id _ 'List)
                      (list (s-field _ "length" (s-num _ 0))
                            (s-field _ "width" (s-num _ 0)))))

(check/block "o:f()"
             (s-dot-method _
                           (s-id _ 'o)
                           'f
                           (list)))

(check/block "{f:4}:f(2)"
             (s-dot-method _
                           (s-obj _ (list (s-field _ "f" (s-num _ 4))))
                           'f
                           (list (s-num _ 2))))

(check/block "def x :: Number: 5" (s-def _ (s-bind _ 'x (a-num _))
                                           (s-num _ 5)))
(check/block "def x :: Number: 'hello'" (s-def _ (s-bind _ 'x (a-num _))
                                         (s-str _ "hello")))

(check/block "fun foo(x) :: (Number -> Number): 'should return a function from num to num' end" 
             (s-fun _ 'foo (list (s-bind _ 'x (a-blank))) (a-arrow _ (list (a-num _)) (a-num _))
                    (s-block _ (list (s-str _ _)))))
(check/block "fun foo(x :: Bool) :: Bool: x end" 
             (s-fun _ 'foo (list (s-bind _ 'x (a-bool _))) (a-bool _)
                    (s-block _ (list (s-id _ 'x)))))

(check/block "def x :: {}: 4" (s-def _ (s-bind _ 'x (a-record _ (list))) (s-num _ 4)))
(check/block "def x :: {foo: Number}: 4" 
             (s-def _ (s-bind _ 'x (a-record _ (list (a-field _ "foo" Number)))) (s-num _ 4)))
(check/block "def x :: {foo: Number}: 4" 
             (s-def _ (s-bind _ 'x (a-record _ (list (a-field _ "foo" Number)))) (s-num _ 4)))
(check/block "def x :: {foo: Number, a: Bool}: 4" 
             (s-def _ (s-bind _ 'x (a-record _ (list (a-field _ "foo" (a-num _)) 
                                                     (a-field _ "a" (a-bool _)))))
                    (s-num _ 4)))


(check/block "cond: | true => 1 | false => 2 end" 
             (s-cond _ (list (s-cond-branch _ (s-bool _ #t) (s-block _ (list (s-num _ 1))))
                             (s-cond-branch _ (s-bool _ #f) (s-block _ (list (s-num _ 2)))))))

(check/block "  data Foo | bar end"
             (s-data _ 'Foo (list (s-variant _ 'bar (list)))))

(check/block "data NumList
  | empty
  | cons: first :: Number, rest :: NumList
end"
             (s-data _ 'NumList (list (s-variant _ 'empty (list))
                                      (s-variant _ 'cons (list (s-member _ 'first (a-num _))
                                                               (s-member _ 'rest (a-name _ 'NumList)))))))