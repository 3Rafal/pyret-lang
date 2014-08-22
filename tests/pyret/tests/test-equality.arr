#lang pyret

import equality as E

check "numbers":
  identical(1, 1) is true
  identical(1, 2) is false
  equal-always(1, 1) is true
  equal-always(1, 2) is false
  equal-now(1, 1) is true
  equal-now(1, 2) is false
end

data Nat:
  | Z
  | S(n)
end

check "datatypes (no ref)":
  identical(Z, Z) is true
  identical(Z, S(Z)) is false
  identical(S(Z), S(Z)) is false
  equal-always(Z, Z) is true
  equal-always(Z, S(Z)) is false
  equal-always(S(Z), S(Z)) is true
  equal-now(Z, Z) is true
  equal-now(Z, S(Z)) is false
  equal-now(S(Z), S(Z)) is true
end

data Box:
  | box(ref v)
end

check "datatypes (with ref)":
  x = box(5)
  y = box(5)
  identical(x, x) is true
  identical(x, y) is false
  equal-always(x, x) is true
  equal-always(x, y) is false
  equal-now(x, x) is true
  equal-now(x, y) is true
end

data NLink:
  | nlink(n, ref l)
  | nempty
end

graph:
  ones = nlink(1, ones)
  other-ones = nlink(1, other-ones)
  third-ones = nlink(1, ones)
end

check "immutable cyclic lists":
  identical(ones, ones) is true
  identical(ones, other-ones) is false
  identical(ones, third-ones) is false
  equal-always(ones, ones) is true
  equal-always(ones, other-ones) is true
  equal-always(ones, third-ones) is true
  equal-now(ones, ones) is true
  equal-now(ones, other-ones) is true
  equal-now(ones, third-ones) is true
end

data MLink:
  | mlink(ref n, ref l)
  | mempty
end

block:
  graph:
    mt1 = mempty
    BOS = mlink(PRO, rest1)
    rest1 = mlink(WOR, mt1)
    PRO = mlink(BOS, mt1)
    WOR = mlink(BOS, mt1)
  end

  graph:
    mt2 = mempty
    CHI = mlink(CLE, mt2)
    DEN = mlink(CLE, mt2)
    CLE = mlink(CHI, rest2)
    rest2 = mlink(DEN, mt2)
  end

  check "general immutable graphs":
    identical(BOS, CLE) is false
    identical(PRO, CHI) is false
    identical(WOR, DEN) is false
    equal-always(BOS, CLE) is true
    equal-always(PRO, CHI) is true
    equal-always(WOR, DEN) is true
    equal-now(BOS, CLE) is true
    equal-now(PRO, CHI) is true
    equal-now(WOR, DEN) is true
  end
end

block:
  m-graph:
    mt1 = mempty
    BOS = mlink(PRO, rest1)
    rest1 = mlink(WOR, mt1)
    PRO = mlink(BOS, mt1)
    WOR = mlink(BOS, mt1)
  end

  m-graph:
    mt2 = mempty
    CHI = mlink(CLE, mt2)
    DEN = mlink(CLE, mt2)
    CLE = mlink(CHI, rest2)
    rest2 = mlink(DEN, mempty)
  end

  check "general mutable graphs":
    identical(BOS, CLE) is false
    identical(PRO, CHI) is false
    identical(WOR, DEN) is false

    equal-always(ref-get(PRO), ref-get(WOR)) is true
    equal-always(ref-get(DEN), ref-get(CHI)) is true

    equal-always(BOS, CLE) is false
    equal-always(PRO, CHI) is false
    equal-always(WOR, DEN) is false
    equal-now(BOS, CLE) is true
    equal-now(PRO, CHI) is true
    equal-now(WOR, DEN) is true
  end
end

# Sets
# Lists
# Trees

check "sets":
  s1 = [tree-set: 1, 2, 3]
  s2 = [tree-set: 2, 1, 3]
  s3 = [tree-set: 1, 2, 5]

  identical(s1, s2) is false
  identical(s1, s3) is false
  equal-always(s1, s2) is true
  equal-always(s1, s3) is false
  equal-now(s1, s2) is true
  equal-now(s1, s3) is false
end

check "lists":
  l1 = [list: 1, 2, 3]
  l2 = [list: 1, 2, 3]
  l3 = [list: 3, 1, 2]

  identical(l1, l2) is false
  identical(l1, l3) is false
  equal-always(l1, l2) is true
  equal-always(l1, l3) is false
  equal-now(l1, l2) is true
  equal-now(l1, l3) is false
end

eq-all = { _equals(_, _, _): E.Equal end }
eq-none = { _equals(_, _, _): E.NotEqual("just because") end }

check "identical pre-check overrides method in true case, but not in false case":
  identical(eq-none, eq-none) is true
  equal-always(eq-none, eq-none) is true
  equal-now(eq-none, eq-none) is true
  
  identical(eq-all, eq-none) is false
  eq-all is-not<=> eq-none
  identical(eq-none, eq-all) is false
  eq-all is-not<=> eq-none
  
  equal-always(eq-all, eq-none) is true
  eq-all is== eq-none
  equal-always(eq-none, eq-all) is false
  eq-none is-not== eq-all
  equal-now(eq-all, eq-none) is true
  eq-all is=~ eq-none
  equal-now(eq-none, eq-all) is false
  eq-none is-not=~ eq-all
end                                                                                                                    

f-err = "compare functions or methods"
f = lam(): "no-op" end
m = method(self): "no-op" end

check "eq-all is equal to everything always":
  eq-all is== f
  eq-all is== m
  eq-all is== 0
  eq-all is== "a"
  eq-all is== nothing
  eq-all is== true
  eq-all is== [list: 1, 2, 3]
  eq-all is== eq-none
end

check "eq-none is equal nothing never always":
  eq-none is-not== f
  eq-none is-not== m
  eq-none is-not== 0
  eq-none is-not== "a"
  eq-none is-not== nothing
  eq-none is-not== true
  eq-none is-not== [list: 1, 2, 3]
  eq-none is-not== eq-all
end

check "error on bare fun and meth":
  identical(f, f) raises f-err
  equal-always(f, f) raises f-err
  equal-now(f, f) raises f-err


  identical(m, m) raises f-err
  equal-always(f, f) raises f-err
  equal-now(f, f) raises f-err
end

check "error (and non-error) on nested fun and meth":
  o1 = {f: f, x: 5}
  o2 = {f: f, x: 5}
  o3 = {f: f, x: 6}
  
  equal-always(o1, o2) raises f-err
  equal-always(o2, o1) raises f-err

  equal-now(o1, o2) raises f-err
  equal-now(o2, o1) raises f-err
  
  equal-always(o1, o3) is false
  o1 is-not== o3
  equal-always(o3, o1) is false
  o3 is-not== o1
  
  equal-now(o1, o3) is false
  o1 is-not=~ o3
  equal-now(o3, o1) is false
  o3 is-not=~ o1
  
  o4 = { subobj: eq-none, f: f }
  o5 = { subobj: eq-all, f: f }
  
  equal-always(o4, o5) is false
  o4 is-not== o5
  equal-always(o5, o4) raises f-err
  
  equal-now(o4, o5) is false
  o4 is-not=~ o5
  equal-now(o5, o4) raises f-err
end

block:
  m-graph:
    mt1 = mempty
    BOS = mlink(PRO, rest1)
    rest1 = mlink(WOR, mt1)
    PRO = mlink(BOS, mt1)
    WOR = mlink(BOS, mt1)
  end

  m-graph:
    mt2 = mempty
    CHI = mlink(CLE, mt2)
    DEN = mlink(CLE, mt2)
    CLE = mlink(CHI, rest2)
    rest2 = mlink(DEN, mt2)
  end

  check "nesting cyclic within user-defined":
    [list-set: PRO, WOR] is=~ [list-set: PRO, WOR]
    [list-set: PRO, DEN] is=~ [list-set: CHI, WOR]
    [list-set: CHI, DEN] is=~ [list-set: PRO, WOR]
    [list-set: CHI, DEN] is=~ [list-set: PRO, WOR]

    [list-set: PRO, WOR] is== [list-set: PRO, WOR]
    [list-set: PRO, DEN] is-not== [list-set: CHI, WOR]
    [list-set: CHI, DEN] is-not== [list-set: PRO, WOR]
    [list-set: CHI, DEN] is-not== [list-set: PRO, WOR]

    for each(r from [list: mt1, BOS, rest1, PRO, WOR, mt2, CHI, DEN, CLE, rest2]):
      ref-freeze(r)
    end

    [list-set: PRO, WOR] is== [list-set: PRO, WOR]
    [list-set: PRO, DEN] is== [list-set: CHI, WOR]
    [list-set: CHI, DEN] is== [list-set: PRO, WOR]
    [list-set: CHI, DEN] is== [list-set: PRO, WOR]
  end
end
