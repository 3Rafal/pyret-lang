provide *
provide-types *

import ast as A
import string-dict as SD
import "compiler/list-aux.arr" as LA

all2-strict  = LA.all2-strict
map2-strict  = LA.map2-strict
fold2-strict = LA.fold2-strict

data Pair<L,R>:
  | pair(left :: L, right :: R)
sharing:
  on-left(self, f :: (L -> L)) -> Pair<L,R>:
    pair(f(self.left), self.right)
  end,
  on-right(self, f :: (R -> R)) -> Pair<L,R>:
    pair(self.left, f(self.right))
  end
end

data Comparison:
  | less-than
  | equal
  | greater-than
sharing:
  _comp(self, other):
    cases(Comparision) other:
      | less-than    => cases(Comparision) self:
          | less-than    => equal
          | equal        => greater-than
          | greater-than => greater-than
        end
      | equal       => self
      | greater-than => cases(Comparision) self:
          | less-than    => less-than
          | equal        => less-than
          | greater-than => equal
        end
    end
  end
end

fun <T> list-compare(a :: List<T>, b :: List<T>) -> Comparison:
  cases(List<T>) a:
    | empty => cases(List<T>) b:
        | empty   => equal
        | link(_) => less-than
      end
    | link(a-f, a-r) => cases(List<T>) b:
        | empty          => greater-than
        | link(b-f, b-r) => cases (Comparison) a-f._comp(b-f):
            | less-than    => less-than
            | greater-than => greater-than
            | equal        => list-compare(a-r, b-r)
          end
      end
  end
end

fun <T> old-list-compare(a :: List<T>, b :: List<T>) -> Comparison:
  cases(List<T>) a:
    | empty => cases(List<T>) b:
        | empty   => equal
        | link(_) => less-than
      end
    | link(a-f, a-r) => cases(List<T>) b:
        | empty => greater-than
        | link(b-f, b-r) =>
          if a-f < b-f:       less-than
          else if a-f == b-f: list-compare(a-r, b-r)
          else:               greater-than
          end
      end
  end
end

fun fold-comparisons(l :: List<Comparison>) -> Comparison:
  cases (List<Comparison>) l:
    | empty      => equal
    | link(f, r) => cases (Comparison) f:
        | equal  => fold-comparisons(r)
        | else   => f
      end
  end
end

data TypeVariable:
  | t-variable(l :: A.Loc, id :: String, upper-bound :: Type) # bound = Top is effectively unbounded
sharing:
  tostring(self) -> String:
    self.id + " <: " + self.upper-bound.tostring()
  end
end

data TypeMember:
  | t-member(field-name :: String, typ :: Type) with:
    tostring(self):
      self.field-name + " : " + self.typ.tostring()
    end
sharing:
  _comp(a, b :: TypeMember) -> Comparison:
    fold-comparisons([list:
        a.field-name._comp(b.field-name),
        a.typ._comp(b.typ)
      ])
  end
end

type TypeMembers = List<TypeMember>
empty-type-members = empty

fun type-members-lookup(type-members :: TypeMembers, field-name :: String) -> Option<TypeMember>:
  fun same-field(tm):
    tm.field-name == field-name
  end
  type-members.find(same-field)
end

data TypeVariant:
  | t-variant(l           :: A.Loc,
              name        :: String,
              fields      :: TypeMembers,
              with-fields :: TypeMembers)
  | t-singleton-variant(l           :: A.Loc,
                        name        :: String,
                        with-fields :: TypeMembers)
end

fun type-variant-fields(tv :: TypeVariant) -> TypeMembers:
  cases(TypeVariant) tv:
    | t-variant(_, _, variant-fields, with-fields) => with-fields + variant-fields
    | t-singleton-variant(_, _, with-fields)       => with-fields
  end
end

data DataType:
  | t-datatype(params   :: List<TypeVariable>,
               variants :: List<TypeVariant>,
               fields   :: TypeMembers) # common (with-)fields, shared methods, etc
end

data Type:
  | t-name(l :: A.Loc, module-name :: Option<String>, id :: String)
  | t-var(id :: String)
  | t-arrow(l :: A.Loc, forall :: List<TypeVariable>, args :: List<Type>, ret :: Type)
  | t-app(l :: A.Loc, onto :: Type % (is-t-name), args :: List<Type> % (is-link))
  | t-top
  | t-bot
  | t-record(l :: A.Loc, fields :: TypeMembers)
sharing:
  satisfies-type(self, other :: Type) -> Boolean:
    cases(Type) self:
      | t-name(_, a-mod, a-id)              => cases(Type) other:
          | t-top => true
          | t-name(_, b-mod, b-id) =>
            (a-mod == b-mod) and (a-id == b-id)
          | else => false
        end
      | t-var(a-id)                         => cases(Type) other:
          | t-top => true
          | t-var(b-id) => a-id == b-id
          | else => false
        end
      | t-arrow(_, a-forall, a-args, a-ret) => cases(Type) other:
          | t-top => true
          | t-arrow(_, b-forall, b-args, b-ret) =>
            all2-strict(_ == _, a-forall, b-forall)
                  # order is important because contravariance!
              and all2-strict(lam(x, y): x.satisfies-type(y);, b-args, a-args)
              and a-ret.satisfies-type(b-ret)
          | else => false
        end
      | t-app(_, a-onto, a-args)            => cases(Type) other:
          | t-top => true
          | t-app(_, b-onto, b-args) =>
            (a-onto == b-onto) and all2-strict(_ == _, a-args, b-args)
          | else => false
        end
      | t-top => is-t-top(other)
      | t-bot => true
      | t-record(_, fields)                 => cases(Type) other:
          | t-top => true
          | t-record(_, other-fields) =>
            fields-satisfy(fields, other-fields)
          | else => false
        end
    end
  end,
  tostring(self) -> String:
    cases(Type) self:
      | t-name(_, module-name, id) => cases(Option<String>) module-name:
          | none    => id
          | some(m) => m + "." + id
        end
      | t-var(id) => id

      | t-arrow(_, forall, args, ret) =>
        "(<" + forall.map(_.tostring()).join-str(", ") + ">"
          +      args.map(_.tostring()).join-str(", ")
          + " -> " + ret.tostring() + ")"

      | t-app(_, onto, args) =>
        onto.tostring() + "<" + args.map(_.tostring()).join-str(", ") + ">"

      | t-top => "Top"
      | t-bot => "Bot"
      | t-record(_, fields) =>
        "{"
          + for map(field from fields):
              field.tostring()
            end.join-str(", ")
          + "}"
    end
  end,
  toloc(self) -> A.Loc:
    cases(Type) self:
      | t-name(l, _, _)     => l
      | t-arrow(l, _, _, _) => l
      | t-var(_)            => A.dummy-loc
      | t-app(l, _, _)      => l
      | t-top               => A.dummy-loc
      | t-bot               => A.dummy-loc
      | t-record(l, _)      => l
    end
  end,
  substitute(self, orig-typ :: Type, new-typ :: Type) -> Type:
    if self == orig-typ:
      new-typ
    else:
      cases(Type) self:
        | t-arrow(l, forall, args, ret) => t-arrow(l, forall,
            args.map(_.substitute(orig-typ, new-typ)),
            ret.substitute(orig-typ, new-typ))

        | t-app(l, onto, args) => t-app(l,
            onto.substitute(orig-typ, new-typ),
            args.map(_.substitute(orig-typ, new-typ)))

        | else => self
      end
    end
  end,
  _lessthan     (self, other :: Type) -> Boolean: self._comp(other) == less-than    end,
  _lessequal    (self, other :: Type) -> Boolean: self._comp(other) <> greater-than end,
  _greaterthan  (self, other :: Type) -> Boolean: self._comp(other) == greater-than end,
  _greaterequal (self, other :: Type) -> Boolean: self._comp(other) <> less-than    end,
  _equal        (self, other :: Type) -> Boolean: self._comp(other) == equal        end,
  _comp(self, other :: Type) -> Comparison:
    cases(Type) self:
      | t-bot                                 => cases(Type) other:
          | t-bot => equal
          | else  => less-than
        end
      | t-name(a-l, a-module-name, a-id)      => cases(Type) other:
          | t-bot               => greater-than
          | t-name(b-l, b-module-name, b-id) => fold-comparisons([list:
                #a-l._comp(b-l),
                a-module-name._comp(b-module-name)
              ])
          | t-var(_)            => less-than
          | t-arrow(_, _, _, _) => less-than
          | t-app(_, _, _)      => less-than
          | t-record(_,_)       => less-than
          | t-top               => less-than
        end
      | t-var(a-id)                           => cases(Type) other:
          | t-bot               => greater-than
          | t-name(_, _, _)     => greater-than
          | t-var(b-id) => a-id._comp(b-id)
          | t-arrow(_, _, _, _) => less-than
          | t-app(_, _, _)      => less-than
          | t-record(_,_)       => less-than
          | t-top               => less-than
        end
      | t-arrow(a-l, a-forall, a-args, a-ret) => cases(Type) other:
          | t-bot               => greater-than
          | t-name(_, _, _)     => greater-than
          | t-var(_)            => greater-than
          | t-arrow(b-l, b-forall, b-args, b-ret) => fold-comparisons([list:
                #a-l._comp(b-l),
                old-list-compare(a-forall, b-forall),
                old-list-compare(a-args, b-args),
                a-ret._comp(b-ret)
              ])
          | t-app(_, _, _)      => less-than
          | t-record(_,_)       => less-than
          | t-top               => less-than
        end
      | t-app(a-l, a-onto, a-args)            => cases(Type) other:
          | t-bot               => greater-than
          | t-name(_, _, _)     => greater-than
          | t-var(_)            => greater-than
          | t-arrow(_, _, _, _) => greater-than
          | t-app(b-l, b-onto, b-args) => fold-comparisons([list:
                #a-l._comp(b-l),
                old-list-compare(a-args, b-args),
                a-onto._comp(b-onto)
              ])
          | t-record(_,_)       => less-than
          | t-top               => less-than
        end
      | t-record(a-l, a-fields)               => cases(Type) other:
          | t-bot               => greater-than
          | t-name(_, _, _)     => greater-than
          | t-var(_)            => greater-than
          | t-arrow(_, _, _, _) => greater-than
          | t-app(_, _, _)      => greater-than
          | t-record(b-l, b-fields) => fold-comparisons([list:
                #a-l._comp(b-l),
                list-compare(a-fields, b-fields)
              ])
          | t-top               => less-than
        end
      | t-top                                 => cases(Type) other:
          | t-top => equal
          | else  => greater-than
        end
    end
  end
end

fun fields-satisfy(a-fields :: TypeMembers, b-fields :: TypeMembers) -> Boolean:
  fun shares-name(here :: TypeMember):
    lam(there :: TypeMember):
      here.field-name == there.field-name
    end
  end
  for fold(good from true, b-field from b-fields):
    pred = shares-name(b-field)
    good and
    cases(Option<TypeMember>) a-fields.find(pred):
      | some(tm) =>
        tm.typ.satisfies-type(b-field.typ)
      | none     =>
        false
    end
  end
end

t-number  = t-name(A.dummy-loc, none, "tglobal#Number")
t-string  = t-name(A.dummy-loc, none, "tglobal#String")
t-boolean = t-name(A.dummy-loc, none, "tglobal#Boolean")
t-srcloc  = t-name(A.dummy-loc, none, "Loc")

fun meet-fields(a-fields :: TypeMembers, b-fields :: TypeMembers) -> TypeMembers:
  for fold(curr from empty, a-field from a-fields):
    field-name = a-field.field-name
    cases(Option<TypeMember>) type-members-lookup(b-fields, field-name):
      | some(b-field) =>
        link(t-member(field-name, least-upper-bound(a-field.typ, b-field.typ)), curr)
      | none =>
        curr
    end
  end
end

fun join-fields(a-fields :: TypeMembers, b-fields :: TypeMembers) -> TypeMembers:
  for fold(curr from empty, a-field from a-fields):
    field-name = a-field.field-name
    cases(Option<TypeMember>) type-members-lookup(b-fields, field-name):
      | some(b-field) =>
        link(t-member(field-name, greatest-lower-bound(a-field.typ, b-field.typ)), curr)
      | none =>
        link(a-field, curr)
        curr
    end
  end
end

fun least-upper-bound(s :: Type, t :: Type) -> Type:
  if s.satisfies-type(t):
    t
  else if t.satisfies-type(s):
    s
  else:
    cases(Type) s:
      | t-arrow(_, s-forall, s-args, s-ret) =>
        cases(Type) t:
          | t-arrow(_, t-forall, t-args, t-ret) =>
            if s-forall == t-forall:
              cases (Option<List<Type>>) map2-strict(greatest-lower-bound, s-args, t-args):
                | some(m-args) =>
                  j-typ  = least-upper-bound(s-ret, t-ret)
                  t-arrow(A.dummy-loc, s-forall, m-args, j-typ)
                | else => t-top
              end
            else:
              t-top
            end
          | else => t-top
        end
      | t-app(_, s-onto, s-args) =>
        cases(Type) t:
          | t-app(_, t-onto, t-args) =>
            if (s-onto == t-onto) and (s-args == t-args):
              t-app(A.dummy-loc, s-onto, s-args)
            else:
              t-top
            end
          | else => t-top
        end
      | t-record(_, s-fields) =>
        cases(Type) t:
          | t-record(_, t-fields) =>
            t-record(A.dummy-loc, meet-fields(s-fields, t-fields))
          | else => t-top
        end
      | else => t-top
    end
  end
end

fun greatest-lower-bound(s :: Type, t :: Type) -> Type:
  if s.satisfies-type(t):
    s
  else if t.satisfies-type(s):
    t
  else: cases(Type) s:
      | t-arrow(s-l, s-forall, s-args, s-ret) => cases(Type) t:
          | t-arrow(_, t-forall, t-args, t-ret) =>
            if s-forall == t-forall:
              cases (Option<List<Type>>) map2-strict(least-upper-bound, s-args, t-args):
                | some(m-args) =>
                  j-typ  = greatest-lower-bound(s-ret, t-ret)
                  t-arrow(A.dummy-loc, s-forall, m-args, j-typ)
                | else => t-bot
              end
            else:
              t-bot
            end
          | else => t-bot
        end
      | t-app(_, s-onto, s-args) => cases(Type) t:
          | t-app(_, t-onto, t-args) =>
            if (s-onto == t-onto) and (s-args == t-args):
              t-app(A.dummy-loc, s-onto, s-args)
            else:
              t-bot
            end
          | else => t-bot
        end
      | t-record(_, s-fields) => cases(Type) t:
          | t-record(_, t-fields) =>
            t-record(A.dummy-loc, join-fields(s-fields, t-fields))
          | else => t-bot
        end
      | else => t-bot
    end
  end
end
