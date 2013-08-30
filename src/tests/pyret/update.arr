#lang pyret

data D:
  | no-ann(mutable x)
  | with-ann(mutable y :: Number)
  | arrow-ann(mutable f :: (Number -> String))
  | multi-field(mutable a, mutable b, c)
where:
    my-d1 = no-ann(5)
    my-d1!x is 5

    my-d1!{x : 10}

    my-d1!x is 10

    my-d1!y raises "y was not found"

    Mutable(my-d1:x) is true

    with-ann("not-a-num") raises "expected Number"

    my-d2 = with-ann(5)
    my-d2!{ y : "not-a-num" } raises "expected Number"

    my-d2!{ y : 10 }
    my-d2!y is 10

    my-d3 = arrow-ann(fun(n): "some-string" end)
    my-d3!f(5) is "some-string"
    my-d3!{ f : fun(n): 42 end }
    my-d3!f(5) raises "expected String"

    my-d4 = multi-field(1, 2, 3)
    my-d4!{a : "new-a", b : "new-b" }
    my-d4!a is "new-a"
    my-d4!b is "new-b"

    my-d4!{c : 5} raises "Updating immutable field"
    my-d4!{a : 5, c : 10} raises "Updating immutable field"
    my-d4!a is "new-a" # doesn't get updated unless all updates work

    my-d4!c raises "look up immutable field"
end


check:
  o = { mutable x: 5 }
  o!{ x: 10 }
  o!x is 10
end
