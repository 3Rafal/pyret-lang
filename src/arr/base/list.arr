#lang pyret/library

provide *
import option as O
import either as E

none = O.none
is-none = O.is-none
some = O.some
is-some = O.is-some
Option = O.Option

left = E.left
right = E.right
Either = E.Either

data List:
  | empty with:

    length(self) -> Number:
      doc: "Takes no other arguments and returns the number of links in the list"
      0
    end,

    each(self, f :: (Any -> Nothing)) -> Nothing:
      doc: "Takes a function and calls that function for each element in the list. Returns nothing"
      nothing
    end,

    map(self, f :: (Any -> Any)) -> List:
      doc: "Takes a function and returns a list of the result of applying that function every element in this list"
      empty
    end,

    filter(self, f :: (Any -> Bool)) -> List:
      doc: "Takes a predicate and returns a list containing the items in this list for which the predicate returns true."
      empty
    end,

    find(self, f :: (Any -> Bool)) -> Option:
      doc: "Takes a predicate and returns on option containing either the first item in this list that passes the predicate, or none"
      none
    end,

    partition(self, f):
      doc: "Takes a predicate and returns an object with two fields: the 'is-true' field contains the list of items in this list for which the predicate holds, and the 'is-false' field contains the list of items in this list for which the predicate fails"
      { is-true: empty, is-false: empty }
    end,

    foldr(self, f, base):
      doc: "Takes a function and an initial value, and folds the function over this list from the right, starting with the base value"
      base
    end,

    foldl(self, f, base):
      doc: "Takes a function and an initial value, and folds the function over this list from the left, starting with the base value"
      base
    end,

    member(self, elt):
      doc: "Returns true when the given element is equal to a member of this list"
      false
    end,

    append(self, other):
      doc: "Takes a list and returns the result of appending the given list to this list"
      other
    end,

    last(self):
      doc: "Returns the last element of this list, or raises an error if the list is empty"
      raise('last: took last of empty list')
    end,

    reverse(self):
      doc: "Returns a new list containing the same elements as this list, in reverse order"
      self
    end,

    _equals(self, other):
      is-empty(other)
    end,

    tostring(self): "[]" end,

    _torepr(self): "[]" end,

    sort-by(self, cmp, eq):
      doc: "Takes a comparator to check for elements that are strictly greater or less than one another, and an equality procedure for elements that are equal, and sorts the list accordingly.  The sort is not guaranteed to be stable."
      self
    end,

    sort(self):
      doc: "Returns a new list whose contents are the smae as those in this list, sorted by the default ordering and equality"
      self
    end,

    join-str(self, str):
      doc: "Returns a string containing the tostring() forms of the elements of this list, joined by the provided separator string"
      ""
    end

  | link(first :: Any, rest :: List) with:

    length(self):
      doc: "Takes no other arguments and returns the number of links in the list"
      1 + self.rest.length()
    end,

    each(self, f):
      doc: "Takes a function and calls that function for each element in the list. Returns nothing"
      f(self.first)
      self.rest.each(f)
    end,

    map(self, f):
      doc: "Takes a function and returns a list of the result of applying that function every element in this list"
      f(self.first)^link(self.rest.map(f))
    end,

    filter(self, f):
      doc: "Takes a predicate and returns a list containing the items in this list for which the predicate returns true."
      if f(self.first): self.first^link(self.rest.filter(f))
      else:             self.rest.filter(f)
      end
    end,

    partition(self, f):
      doc: "Takes a predicate and returns an object with two fields: the 'is-true' field contains the list of items in this list for which the predicate holds, and the 'is-false' field contains the list of items in this list for which the predicate fails"
      partition(f, self)
    end,

    find(self, f):
      doc: "Takes a predicate and returns on option containing either the first item in this list that passes the predicate, or none"
      find(f, self)
    end,

    member(self, elt):
      doc: "Returns true when the given element is equal to a member of this list"
      (elt == self.first) or self.rest.member(elt)
    end,

    foldr(self, f, base):
      doc: "Takes a function and an initial value, and folds the function over this list from the right, starting with the initial value"
      f(self.first, self.rest.foldr(f, base))
    end,

    foldl(self, f, base):
      doc: "Takes a function and an initial value, and folds the function over this list from the left, starting with the initial value"
      self.rest.foldl(f, f(self.first, base))
    end,

    append(self, other):
      doc: "Takes a list and returns the result of appending the given list to this list"
      self.first^link(self.rest.append(other))
    end,

    last(self):
      doc: "Returns the last element of this list, or raises an error if the list is empty"
      if is-empty(self.rest): self.first
      else: self.rest.last()
      end
    end,

    reverse(self):
      doc: "Returns a new list containing the same elements as this list, in reverse order"
      reverse-help(self, empty)
    end,

    _equals(self, other):
      if is-link(other):
        others-equal = (self:first == other:first)
        others-equal and (self:rest == other:rest)
      else:
        false
      end
    end,

    tostring(self):
      "[" +
        for raw-fold(combined from tostring(self:first), elt from self:rest):
          combined + ", " + tostring(elt)
        end
      + "]"
    end,

    _torepr(self):
      "[" +
        for raw-fold(combined from torepr(self:first), elt from self:rest):
          combined + ", " + torepr(elt)
        end
      + "]"
    end,

    sort-by(self, cmp, eq):
      doc: "Takes a comparator to check for elements that are strictly greater or less than one another, and an equality procedure for elements that are equal, and sorts the list accordingly.  The sort is not guaranteed to be stable."
      pivot = self.first
      
      # builds up three lists, split according to cmp and eq
      # Note: We use each, which is tail-recursive, but which causes the three
      # list parts to grow in reverse order.  This isn't a problem, since we're
      # about to sort two of those parts anyway.
      var are-lt = empty
      var are-eq = empty
      var are-gt = empty
      self.each(fun(e):
          if cmp(e, pivot):     are-lt := e^link(are-lt)
          else if eq(e, pivot): are-eq := e^link(are-eq)
          else:                 are-gt := e^link(are-gt)
          end
        end)
      less =    are-lt.sort-by(cmp, eq)
      equal =   are-eq
      greater = are-gt.sort-by(cmp, eq)
      less.append(equal.append(greater))
    end,
    
    sort(self):
      doc: "Returns a new list whose contents are the same as those in this list, sorted by the default ordering and equality"
      self.sort-by(fun(e1,e2): e1 < e2 end, fun(e1,e2): e1 == e2 end)
    end,

    join-str(self, str):
      doc: "Returns a string containing the tostring() forms of the elements of this list, joined by the provided separator string"
      if is-link(self.rest):
         tostring(self.first) + str + self.rest.join-str(str)
      else:
         tostring(self.first)
      end
    end,


sharing:
  push(self, elt):
    doc: "Adds an element to the front of the list, returning a new list"
    link(elt, self)
  end,
  _plus(self :: List, other :: List): self.append(other) end,
  split-at(self, n):
    doc: "Splits this list into two lists, one containing the first n elements, and the other containing the rest"
    split-at(n, self)
  end,
  take(self, n):
    doc: "Returns the first n elements of this list"
    split-at(n, self).prefix
  end,
  drop(self, n):
    doc: "Returns all but the first n elements of this list"
    split-at(n, self).suffix
  end,
  
  get(self, n):
    doc: "Returns the nth element of this list, or raises an error if n is out of range"
    get-help(self, n)
  end,
  set(self, n, e):
    doc: "Returns a new list with the nth element set to the given value, or raises an error if n is out of range"
    set-help(self, n, e)
  end
end

fun get-help(lst, n :: Number):
  doc: "Returns the nth element of the given list, or raises an error if n is out of range"
  fun help(l, cur):
    if is-empty(l): raise("get: n too large " + tostring(n))
    else if cur == 0: l.first
    else: help(l.rest, cur - 1)
    end
  end
  if n < 0: raise("get: invalid argument: " + tostring(n))
  else: help(lst, n)
  end
end
fun set-help(lst, n :: Number, v):
  doc: "Returns a new list with the same values as the given list but with the nth element set to the given value, or raises an error if n is out of range"
  fun help(l, cur):
    if is-empty(l): raise("set: n too large " + tostring(n))
    else if cur == 0: v ^ link(l.rest)
    else: l.first ^ link(help(l.rest, cur - 1))
    end
  end
  if n < 0: raise("set: invalid argument: " + tostring(n))
  else: help(lst, n)
  end
end
fun reverse-help(lst, acc):
  doc: "Returns a new list containing the same elements as this list, in reverse order"
  cases(List) lst:
    | empty => acc
    | link(first, rest) => reverse-help(rest, first^link(acc))
  end
end

fun raw-fold(f, base, lst :: List):
  doc: "Helper method for folding from the left over the raw field values of the list"
  if is-empty(lst):
    base
  else:
    raw-fold(f, f(base, lst:first), lst.rest)
  end
end

fun range(start, stop):
  doc: "Creates a list of numbers, starting with start, ending with stop-1"
  if start < stop:       link(start, range(start + 1, stop))
  else if start == stop: empty
  else:  raise("range: start greater than stop: ("
                                 + tostring(start)
                                 + ", "
                                 + tostring(stop)
                                 + ")")
  end
end

fun repeat(n :: Number, e :: Any) -> List:
  doc: "Creates a list with n copies of e"
  if n > 0:       link(e, repeat(n - 1, e))
  else if n == 0: empty
  else:           raise("repeat: can't have a negative argument'")
  end
where:
  repeat(0, 10) is empty
  repeat(3, -1) is link(-1, link(-1, link(-1, empty)))
  repeat(1, "foo") is link("foo", empty)
end

fun filter(f, lst :: List):
  doc: "Returns the subset of lst for which f(elem) is true"
  if is-empty(lst):
    empty
  else:
    if f(lst.first):
      lst.first^link(filter(f, lst.rest))
    else:
      filter(f, lst.rest)
    end
  end
end

fun partition(f, lst :: List):
  doc: "Splits the list into two lists, one for which f(elem) is true, and one for which f(elem) is false"
  var is-true = empty
  var is-false = empty
  fun help(inner-lst):
    if is-empty(inner-lst): nothing
    else:
      help(inner-lst.rest)
      if f(inner-lst.first):
        is-true := inner-lst.first^link(is-true)
      else:
        is-false := inner-lst.first^link(is-false)
      end
    end
  end
  help(lst)
  { is-true: is-true, is-false: is-false }
end

fun find(f :: (Any -> Bool), lst :: List) -> Option:
  doc: "Returns some(elem) where elem is the first elem in lst for which f(elem) returns true, or none otherwise"
  if is-empty(lst):
    none
  else:
    if f(lst.first):
      some(lst.first)
    else:
      find(f, lst.rest)
    end
  end
where:
 find(fun(elt): elt > 1 end, link(1,link(2,link(3,empty)))) is some(2)
 find(fun(elt): true end, link("find-me",empty)) is some("find-me")
 find(fun(elt): elt > 4 end, link(1,link(2,link(3)))) is none
 find(fun(elt): true end, empty) is none
 find(fun(elt): false end, empty) is none
 find(fun(elt): false end, link(1,empty)) is none
end

fun split-at(n :: Number, lst :: List) -> { prefix: List, suffix: List }:
  doc: "Splits the list into two lists, one containing the first n elements, and the other containing the rest"
  when n < 0:
    raise("Invalid index")
  end
  var prefix = empty
  var suffix = empty
  fun help(ind, l):
    if ind == 0: suffix := l
    else:
      cases(List) l:
        | empty => raise("Index too large")
        | link(fst, rst) =>
          help(ind - 1, rst)
          prefix := fst^link(prefix)
      end
    end
  end
  help(n, lst)
  { prefix: prefix, suffix: suffix }
where:
  one-four = link(1, link(2, link(3, link(4, empty))))
  split-at(0, one-four) is { prefix: empty, suffix: one-four }
  split-at(4, one-four) is { prefix: one-four, suffix: empty }
  split-at(2, one-four) is { prefix: link(1, link(2, empty)), suffix: link(3, link(4, empty)) }
  split-at(-1, one-four) raises "Invalid index"
  split-at(5, one-four) raises "Index too large"
end

fun any(f :: (Any -> Bool), lst :: List) -> Bool:
  doc: "Returns true if f(elem) returns true for any elem of lst"
  is-some(find(f, lst))
where:
 any(fun(n): n > 1 end, link(1,link(2,link(3,empty)))) is true
 any(fun(n): n > 3 end, link(1,link(2,link(3,empty)))) is false
 any(fun(x): true end, empty) is false
 any(fun(x): false end, empty) is false
end

fun all(f :: (Any -> Bool), lst :: List) -> Bool:
  doc: "Returns true if f(elem) returns true for all elems of lst"
  fun help(l):
    if is-empty(l): true
    else: f(l.first) and help(l.rest)
    end
  end
  help(lst)
where:
 all(fun(n): n > 1 end, link(1,link(2,link(3,empty)))) is false
 all(fun(n): n <= 3 end, link(1,link(2,link(3,empty)))) is true
 all(fun(x): true end, empty) is true
 all(fun(x): false end, empty) is true
end

fun all2(f :: (Any, Any -> Bool), lst1 :: List, lst2 :: List) -> Bool:
  doc: "Returns true if f(elem1, elem2) returns true for all corresponding elems of lst1 and list2. Returns true when either list is empty"
  fun help(l1, l2):
    if is-empty(l1) or is-empty(l2): true
    else: f(l1.first, l2.first) and help(l2.rest, l2.rest)
    end
  end
  help(lst1, lst2)
where:
 all2(fun(n, m): n > m end, link(1,link(2,link(3,empty))), link(0,link(1,link(2,empty)))) is true
 all2(fun(n, m): (n + m) == 3 end, link(1,link(2,link(3,empty))), link(2,link(1,link(0,empty)))) is true
 all2(fun(n, m): n < m end, link(1,link(2,link(3,empty))), link(0,link(1,link(2,empty)))) is false
 all2(fun(_, _): true end, empty, empty) is true
 all2(fun(_, _): false end, empty, empty) is true
end


fun map(f, lst :: List):
  doc: "Returns a list made up of f(elem) for each elem in lst"
  if is-empty(lst):
    empty
  else:
    f(lst.first)^link(map(f, lst.rest))
  end
end

fun map2(f, l1 :: List, l2 :: List):
  doc: "Returns a list made up of f(elem1, elem2) for each elem1 in l1, elem2 in l2"
  if is-empty(l1) or is-empty(l2):
    empty
  else:
    f(l1.first, l2.first)^link(map2(f, l1.rest, l2.rest))
  end
end

fun map3(f, l1 :: List, l2 :: List, l3 :: List):
  doc: "Returns a list made up of f(e1, e2, e3) for each e1 in l1, e2 in l2, e3 in l3"
  if is-empty(l1) or is-empty(l2) or is-empty(l3):
    empty
  else:
    f(l1.first, l2.first, l3.first)^link(map3(f, l1.rest, l2.rest, l3.rest))
  end
end

fun map4(f, l1 :: List, l2 :: List, l3 :: List, l4 :: List):
  doc: "Returns a list made up of f(e1, e2, e3, e4) for each e1 in l1, e2 in l2, e3 in l3, e4 in l4"
  if is-empty(l1) or is-empty(l2) or is-empty(l3) or is-empty(l4):
    empty
  else:
    f(l1.first, l2.first, l3.first, l4.first)^link(map4(f, l1.rest, l2.rest, l3.rest, l4.rest))
  end
end

fun map_n(f, n :: Number, lst :: List):
  doc: "Returns a list made up of f(n, e1), f(n+1, e2) .. for e1, e2 ... in lst"
  if is-empty(lst):
    empty
  else:
    f(n, lst.first)^link(map_n(f, n + 1, lst.rest))
  end
end

fun map2_n(f, n :: Number, l1 :: List, l2 :: List):
  doc: "Returns a list made up of f(i, e1, e2) for each e1 in l1, e2 in l2, and i counting up from n"
  if is-empty(l1) or is-empty(l2):
    empty
  else:
    f(n, l1.first, l2.first)^link(map2_n(f, n + 1, l1.rest, l2.rest))
  end
end

fun map3_n(f, n :: Number, l1 :: List, l2 :: List, l3 :: List):
  doc: "Returns a list made up of f(i, e1, e2, e3) for each e1 in l1, e2 in l2, e3 in l3, and i counting up from n"
  if is-empty(l1) or is-empty(l2) or is-empty(l3):
    empty
  else:
    f(n, l1.first, l2.first, l3.first)^link(map3_n(f, n + 1, l1.rest, l2.rest, l3.rest))
  end
end

fun map4_n(f, n :: Number, l1 :: List, l2 :: List, l3 :: List, l4 :: List):
  doc: "Returns a list made up of f(i, e1, e2, e3, e4) for each e1 in l1, e2 in l2, e3 in l3, e4 in l4, and i counting up from n"
  if is-empty(l1) or is-empty(l2) or is-empty(l3) or is-empty(l4):
    empty
  else:
    f(n, l1.first, l2.first, l3.first, l4.first)^link(map4(f, n + 1, l1.rest, l2.rest, l3.rest, l4.rest))
  end
end

fun each(f, lst :: List):
  doc: "Calls f for each elem in lst, and returns nothing"
  fun help(l):
    if is-empty(l):
      nothing
    else:
      f(l.first)
      help(l.rest)
    end
  end
  help(lst)
end

fun each2(f, lst1 :: List, lst2 :: List):
  doc: "Calls f on each pair of corresponding elements in l1 and l2, and returns nothing.  Stops after the shortest list"
  fun help(l1, l2):
    if is-empty(l1) or is-empty(l2):
      nothing
    else:
      f(l1.first, l2.first)
      help(l1.rest, l2.rest)
    end
  end
  help(lst1, lst2)
end

fun each3(f, lst1 :: List, lst2 :: List, lst3 :: List):
  doc: "Calls f on each triple of corresponding elements in l1, l2 and l3, and returns nothing.  Stops after the shortest list"
  fun help(l1, l2, l3):
    if is-empty(l1) or is-empty(l2) or is-empty(l3):
      nothing
    else:
      f(l1.first, l2.first, l3.first)
      help(l1.rest, l2.rest, l3.rest)
    end
  end
  help(lst1, lst2, lst3)
end

fun each4(f, lst1 :: List, lst2 :: List, lst3 :: List, lst4 :: List):
  doc: "Calls f on each tuple of corresponding elements in l1, l2, l3 and l4, and returns nothing.  Stops after the shortest list"
  fun help(l1, l2, l3, l4):
    if is-empty(l1) or is-empty(l2) or is-empty(l3) or is-empty(l4):
      nothing
    else:
      f(l1.first, l2.first, l3.first, l4.first)
      help(l1.rest, l2.rest, l3.rest, l4.rest)
    end
  end
  help(lst1, lst2, lst3, lst4)
end

fun each_n(f, num :: Number, lst:: List):
  doc: "Calls f(i, e) for each e in lst and with i counting up from num, and returns nothing"
  fun help(n, l):
    if is-empty(l):
      nothing
    else:
      f(n, l.first)
      help(n + 1, l.rest)
    end
  end
  help(num, lst)
end

fun each2_n(f, num :: Number, lst1 :: List, lst2 :: List):
  doc: "Calls f(i, e1, e2) for each e1 in lst1, e2 in lst2 and with i counting up from num, and returns nothing"
  fun help(n, l1, l2):
    if is-empty(l1) or is-empty(l2):
      nothing
    else:
      f(n, l1.first, l2.first)
      help(n + 1, l1.rest, l2.rest)
    end
  end
  help(num, lst1, lst2)
end

fun each3_n(f, num :: Number, lst1 :: List, lst2 :: List, lst3 :: List):
  doc: "Calls f(i, e1, e2, e3) for each e1 in lst1, e2 in lst2, e3 in lst3 and with i counting up from num, and returns nothing"
  fun help(n, l1, l2, l3):
    if is-empty(l1) or is-empty(l2) or is-empty(l3):
      nothing
    else:
      f(n, l1.first, l2.first, l3.first)
      help(n + 1, l1.rest, l2.rest, l3.rest)
    end
  end
  help(num, lst1, lst2, lst3)
end

fun each4_n(f, num :: Number, lst1 :: List, lst2 :: List, lst3 :: List, lst4 :: List):
  doc: "Calls f(i, e1, e2, e3, e4) for each e1 in lst1, e2 in lst2, e3 in lst3, e4 in lst4 and with i counting up from num, and returns nothing"
  fun help(n, l1, l2, l3, l4):
    if is-empty(l1) or is-empty(l2) or is-empty(l3) or is-empty(l4):
      nothing
    else:
      f(n, l1.first, l2.first, l3.first, l4.first)
      help(n + 1, l1.rest, l2.rest, l3.rest, l4.rest)
    end
  end
  help(num, lst1, lst2, lst3, lst4)
end

fun fold-while(f, base, lst):
  doc: "Takes a function that takes two arguments and returns an Either, and also a base value, and folds over the given list from the left as long as the function returns a left() value, and returns either the final value or the right() value"
  cases(List) lst:
    | empty => base
    | link(elt, r) =>
      cases(Either) f(base, elt):
        | left(v) => fold-while(f, v, r)
        | right(v) => v
      end
  end
end

fun fold(f, base, lst :: List):
  doc: "Takes a function, an initial value and a list, and folds the function over the list from the left, starting with the initial value"
  if is-empty(lst):
    base
  else:
    fold(f, f(base, lst.first), lst.rest)
  end
end

fun fold2(f, base, l1 :: List, l2 :: List):
  doc: "Takes a function, an initial value and two lists, and folds the function over the lists in parallel from the left, starting with the initial value and ending when either list is empty"
  if is-empty(l1) or is-empty(l2):
    base
  else:
    fold2(f, f(base, l1.first, l2.first), l1.rest, l2.rest)
  end
end

fun fold3(f, base, l1 :: List, l2 :: List, l3 :: List):
  doc: "Takes a function, an initial value and three lists, and folds the function over the lists in parallel from the left, starting with the initial value and ending when any list is empty"
  if is-empty(l1) or is-empty(l2) or is-empty(l3):
    base
  else:
    fold3(f, f(base, l1.first, l2.first, l3.first), l1.rest, l2.rest, l3.rest)
  end
end

fun fold4(f, base, l1 :: List, l2 :: List, l3 :: List, l4 :: List):
  doc: "Takes a function, an initial value and four lists, and folds the function over the lists in parallel from the left, starting with the initial value and ending when any list is empty"
  if is-empty(l1) or is-empty(l2) or is-empty(l3) or is-empty(l4):
    base
  else:
    fold4(f, f(base, l1.first, l2.first, l3.first, l4.first), l1.rest, l2.rest, l3.rest, l4.rest)
  end
end

fun fold_n(f, num :: Number, base, lst :: List):
  doc: "Takes a function, an initial value and a list, and folds the function over the list from the left, starting with the initial value and passing along the index (starting with the given num)"
  fun help(n, acc, partial-list):
    if is-empty(partial-list):
      acc
    else:
      help(n + 1, f(n, acc, partial-list.first), partial-list.rest)
    end
  end
  help(num, base, lst)
end

index = get-help
