provide *
provide-types *

import ast as A
import string-dict as SD

shadow fold2 = lam(f, base, l1, l2):
                 if l1.length() <> l2.length():
                   raise("Lists are not equal in length!")
                 else:
                   fold2(f, base, l1, l2)
                 end
               end

shadow map2 = lam(f, l1, l2):
                 if l1.length() <> l2.length():
                   raise("Lists are not equal in length!")
                 else:
                   map2(f, l1, l2)
                 end
               end

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
  | LessThan
  | Equal
  | GreaterThan
end

fun <T> list-compare(a :: List<T>, b :: List<T>) -> Comparison:
  cases(List<T>) a:
    | empty =>
      if is-link(b):
        LessThan
      else:
        Equal
      end
    | link(a-f, a-r) =>
      cases(List<T>) b:
        | empty =>
          GreaterThan
        | link(b-f, b-r) =>
          if a-f < b-f:
            LessThan
          else if a-f == b-f:
            list-compare(a-r, b-r)
          else:
            GreaterThan
          end
      end
  end
end

data TypeVariable:
  | t-variable(l :: A.Loc, id :: String, upper-bound :: Type) # bound = Top is effectively unbounded
end

data TypeMember:
  | type-member(field-name :: String, typ :: Type)
end

data TypeVariant:
  | type-variant(fields      :: List<TypeMember>,
                 with-fields :: List<TypeMember>)
end

data DataType:
  | t-datatype(params   :: List<TypeVariable>,
               variants :: SD.StringDict<TypeVariant>,
               fields   :: List<TypeMember>) # common (with-)fields, shared methods, etc
end

data Type:
  | t-name(l :: A.Loc, module-name :: Option<String>, id :: String)
  | t-var(id :: String)
  | t-arrow(l :: A.Loc, forall :: List<TypeVariable>, args :: List<Type>, ret :: Type)
  | t-top
  | t-bot
#  | t-app(onto :: Type % (is-t-name), introduced :: List<Type>)
sharing:
  satisfies-type(self, other :: Type) -> Boolean:
    cases(Type) self:
      | t-name(_, module-name, id) =>
        cases(Type) other:
          | t-top => true
          | t-name(_, other-module, other-id) =>
            (module-name == other-module) and (id == other-id)
          | else => false
        end
      | t-var(id) =>
        cases(Type) other:
          | t-top => true
          | t-var(other-id) => id == other-id
          | else => false
        end
      | t-arrow(_, forall, args, ret) =>
        cases(Type) other:
          | t-top => true
          | t-arrow(_, other-forall, other-args, other-ret) =>
            for fold2(res from true, this-arg from self.args, other-arg from other-args):
              res and other-arg.satisfies-type(this-arg)
            end and ret.satisfies-type(other-ret)
          | else => false
        end
      | t-top => is-t-top(other)
      | t-bot => true
    end
  end,
  tostring(self) -> String:
    cases(Type) self:
      | t-name(l, module-name, id) =>
        cases(Option<String>) module-name:
          | none    => id
          | some(m) => m + "." + id
        end
      | t-var(id) =>
        id
      | t-arrow(l, forall, args, ret) =>
        "(" + args.map(_.tostring()).join-str(", ") + " -> " + ret.tostring() + ")"
      | t-top =>
        "Top"
      | t-bot =>
        "Bot"
    end
  end,
  toloc(self) -> A.Loc:
    cases(Type) self:
      | t-name(l, module-name, id) => l
      | t-arrow(l, forall, args, ret) => l
      | t-var(_) => A.dummy-loc
      | t-top => A.dummy-loc
      | t-bot => A.dummy-loc
    end
  end,
  substitute(self, orig-typ :: Type, new-typ :: Type) -> Type:
    if self == orig-typ:
      new-typ
    else:
      cases(Type) self:
        | t-arrow(l, forall, args, ret) =>
          new-args = args.map(_.substitute(orig-typ, new-typ))
          new-ret  = ret.substitute(orig-typ, new-typ)
          t-arrow(l, forall, new-args, new-ret)
        | else =>
          self
      end
    end
  end,
  _lessthan(self, other :: Type) -> Boolean:
    cases(Type) self:
      | t-bot =>
        true
      | t-name(a-l, a-module-name, a-id) =>
        cases(Type) other:
          | t-bot =>
            false
          | t-name(b-l, b-module-name, b-id) =>
            (a-l < b-l) or
              ((a-l == b-l) and
                ((a-module-name < b-module-name) or
                  ((a-module-name == b-module-name) and (a-id < b-id))))
          | t-var(_) =>
            true
          | t-arrow(_, _, _, _) =>
            true
          | t-top =>
            true
        end
      | t-var(a-id) =>
        cases(Type) other:
          | t-bot =>
            false
          | t-name(_, _, _) =>
            false
          | t-var(b-id) =>
            a-id < b-id
          | t-arrow(_, _, _, _) =>
            true
          | t-top =>
            true
        end
      | t-arrow(a-l, a-forall, a-args, a-ret) =>
        cases(Type) other:
          | t-bot =>
            false
          | t-name(_, _, _) =>
            false
          | t-var(id) =>
            false
          | t-arrow(b-l, b-forall, b-args, b-ret) =>
            (a-l < b-l) or
              ((a-l == b-l) and
                cases(Comparison) list-compare(a-forall, b-forall):
                  | LessThan =>
                    true
                  | Equal =>
                    cases(Comparison) list-compare(a-args, b-args):
                      | LessThan    => true
                      | Equal       => a-ret < b-ret
                      | GreaterThan => false
                    end
                  | GreaterThan =>
                    false
                end)
          | t-top =>
            true
        end
      | t-top =>
        false
    end
  end
end

t-number  = t-name(A.dummy-loc, none, "tglobal#Number")
t-string  = t-name(A.dummy-loc, none, "tglobal#String")
t-boolean = t-name(A.dummy-loc, none, "tglobal#Boolean")
t-srcloc  = t-name(A.dummy-loc, none, "Loc")

fun least-upper-bound(s :: Type, t :: Type) -> Type:
  if s.satisfies-type(t):
    t
  else if t.satisfies-type(s):
    s
  else:
    cases(Type) s:
      | t-arrow(s-l, s-forall, s-args, s-ret) =>
        cases(Type) t:
          | t-arrow(t-l, t-forall, t-args, t-ret) =>
            if s-forall == t-forall:
              m-args = map2(greatest-lower-bound, s-args, t-args)
              j-typ  = least-upper-bound(s-ret, t-ret)
              t-arrow(A.dummy-loc, s-forall, m-args, j-typ)
            else:
              t-top
            end
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
  else:
    cases(Type) s:
      | t-arrow(s-l, s-forall, s-args, s-ret) =>
        cases(Type) t:
          | t-arrow(t-l, t-forall, t-args, t-ret) =>
            if s-forall == t-forall:
              m-args = map2(least-upper-bound, s-args, t-args)
              j-typ  = greatest-lower-bound(s-ret, t-ret)
              t-arrow(A.dummy-loc, s-forall, m-args, j-typ)
            else:
              t-bot
            end
          | else => t-bot
        end
      | else => t-bot
    end
  end
end
