#lang scribble/base
@(require "../../scribble-api.rkt" "../abbrevs.rkt")

@(define (set-method name)
  (method-doc "Set" "set" name #:alt-docstrings ""))

@(define s-of-a '(a-app (a-id "Set" (xref "sets" "Set")) "a"))
@(define l-of-a '(a-app (a-id "List" (xref "lists" "List")) "a"))
@(define boolean '(a-id "Boolean" (xref "<global>" "Boolean")))

@docmodule["sets"]{

@(append-gen-docs
  `(module "sets"
    (path "src/js/base/runtime-anf.js")
    (data-spec
      (name "Set")
      (type-vars (a-id "a"))
      (variants ("set"))
      (shared
        ((method-spec
          (name "fold")
          (arity 3)
          (params [list: leaf("b")])
          (args ("self" "f" "base"))
          (return (a-id "b"))
          (contract
            (a-arrow
              ,s-of-a
              (a-arrow "b" "a" "b")
              "b"))
        )
        (method-spec
          (name "member")
          (arity 2)
          (params)
          (args ("self" "elt"))
          (return ,boolean)
          (contract
            (a-arrow
              ,s-of-a
              "a"
              ,boolean))
        )
        (method-spec
          (name "add")
          (arity 2)
          (params)
          (args ("self" "elt"))
          (return ,s-of-a)
          (contract
            (a-arrow
              ,s-of-a
              "a"
              ,s-of-a))
        )
        (method-spec
          (name "remove")
          (arity 2)
          (params)
          (args ("self" "elt"))
          (return ,s-of-a)
          (contract
            (a-arrow
              ,s-of-a
              "a"
              ,s-of-a)))
        (method-spec
          (name "to-list")
          (arity 1)
          (params)
          (args ("self"))
          (return ,l-of-a)
          (contract
            (a-arrow
              ,s-of-a
              ,l-of-a)))
        (method-spec
          (name "union")
          (arity 2)
          (params)
          (args ("self" "other"))
          (return ,s-of-a)
          (contract
            (a-arrow
              ,s-of-a
              ,s-of-a
              ,s-of-a)))
        (method-spec
          (name "intersect")
          (arity 2)
          (params)
          (args ("self" "other"))
          (return ,s-of-a)
          (contract
            (a-arrow
              ,s-of-a
              ,s-of-a
              ,s-of-a)))
        (method-spec
          (name "difference")
          (arity 2)
          (params)
          (args ("self" "other"))
          (return ,s-of-a)
          (contract
            (a-arrow
              ,s-of-a
              ,s-of-a
              ,s-of-a)))
        (method-spec
          (name "symmetric-difference")
          (arity 2)
          (params)
          (args ("self" "other"))
          (return ,s-of-a)
          (contract
            (a-arrow
              ,s-of-a
              ,s-of-a
              ,s-of-a)))
        ))
      )
  ))

The interface to sets is in flux, and its design may change significantly in
the future.

@section{The Set Type}

@type-spec["Set" (list "a")]

There are no variants for @pyret-id{Set}s, and programs should not use
@pyret{cases} statements with @pyret-id{Set}s.  Instead, they can be created
with the constructors below, and manipulated with the methods and functions
below.

There are two underlying representations that sets may have.  List-based sets
work on all values and compares them using the @pyret-id["equal-always"
"equality"] built-in function.  List-based sets have O(n) performance on
removal and membership testing.  Tree-based sets require that all elements
implement the @pyret["_lessthan"] method in order to perform comparisons.

@section{Set Constructors}

@collection-doc["list-set" (list (cons "elt" "a")) (S-of "a")]

Constructs a set out of the @pyret{elt}s backed by a list.

@examples{
check:
  [list-set: 1, 2, 3] is [list-set: 1, 2, 3]
  [list-set: 1, 2, 2] is [list-set: 1, 2]
  [list-set: [list: 1], [list: 1], [list: 2]] is
    [list-set: [list: 2], [list: 1]]
end
}

@singleton-doc["Set" "empty-list-set" (S-of "a")]

An empty set backed by a list.

@collection-doc["tree-set" (list (cons "elt" "a")) (S-of "a")]

Constructs a set out of the @pyret{elt}s backed by a tree.  Raises an exception
if the elements don't support the @pyret{<} operator via @pyret["_lessthan"].

@examples{
check:
  [tree-set: 1, 2, 3] is [tree-set: 1, 2, 3]
  [tree-set: 1, 2, 2] is [tree-set: 1, 2]
  [tree-set: [list: 1], [list: 1], [list: 2]] raises "binop-error"
end
}

@singleton-doc["Set" "empty-tree-set" (S-of "a")]

An empty set backed by a tree.

@collection-doc["set" (list (cons "elt" "a")) (S-of "a")]

Another name for @pyret-id{list-set}.

@section{Set Methods}

@set-method["add"]
@set-method["remove"]
@set-method["member"]

Checks if @pyret{elt} is contained within this set (checking membership with
@pyret-id["equal-always" "equality"]).

@set-method["union"]
@set-method["intersect"]
@set-method["difference"]
@set-method["symmetric-difference"]

@set-method["to-list"]

@set-method["fold"]

Applies @pyret{f} to each element of the set along with the accumulator
(starting with @pyret{base}) to produce a new value.  Traverses elements in an
unspecified order.

@examples{
check:
  fun one-of(ans, elts):
    lists.member(elts, ans)
  end
  t1 = [tree-set: "1", "2", "3"]
  result = t1.fold(string-append, "")

  result is%(one-of) [list: "123", "132", "213", "231", "312", "321"]
end
}

}
