#lang pyret

provide *

import ast as A
import "./ast-anf.arr" as N

names = A.global-names

fun mk-id(loc, base):
  t = names.make-atom(base)
  { id: t, id-b: bind(loc, t), id-e: N.a-id(loc, t) }
end

data ANFCont:
  | k-cont(k :: (N.ALettable -> N.AExpr)) with:
    apply(self, l :: Loc, expr :: N.ALettable): self.k(expr) end
  | k-id(name :: Name) with:
    apply(self, l :: Loc, expr :: N.ALettable):
      cases(N.ALettable) expr:
        | a-val(v) =>
          name = mk-id(l, "cont_tail_app")
          N.a-let(l, name.id-b, N.a-app(l, N.a-id(l, self.name), [v]),
            N.a-lettable(N.a-val(name.id-e)))
        | else =>
          e-name = mk-id(l, "cont_tail_arg")
          name = mk-id(l, "cont_tail_app")
          N.a-let(l, e-name.id-b, expr,
            N.a-let(l, name.id-b, N.a-app(l, N.a-id(l, self.name), [e-name.id-e]),
              N.a-lettable(N.a-val(name.id-e))))
      end
    end
end

fun anf-term(e :: A.Expr) -> N.AExpr:
  anf(e, k-cont(fun(x):
        cases(N.ALettable) x:
            # tail call
          | a-app(l, f, args) =>
            name = mk-id(l, "anf_tail_app")
            N.a-let(l, name.id-b, x, N.a-lettable(N.a-val(name.id-e)))
          | else => N.a-lettable(x)
        end
      end)
    )
end

fun bind(l, id): N.a-bind(l, id, A.a-blank);

fun anf-bind(b):
  cases(A.Bind) b:
    | s-bind(l, shadows, id, ann) => N.a-bind(l, id, ann)
  end
end

fun anf-name(expr :: A.Expr, name-hint :: String, k :: (N.AVal -> N.AExpr)) -> N.AExpr:
  anf(expr, k-cont(fun(lettable):
        cases(N.ALettable) lettable:
          | a-val(v) => k(v)
          | else =>
            t = mk-id(expr.l, name-hint)
            N.a-let(expr.l, t.id-b, lettable, k(t.id-e))
        end
      end))
end

fun anf-name-rec(
    exprs :: List<A.Expr>,
    name-hint :: String,
    k :: (List<N.AVal> -> N.AExpr)
  ) -> N.AExpr:
  cases(List) exprs:
    | empty => k([])
    | link(f, r) =>
      anf-name(f, name-hint, fun(v):
          anf-name-rec(r, name-hint, fun(vs): k([v] + vs);)
        end)
  end
end

fun anf-program(e :: A.Program):
  cases(A.Program) e:
    | s-program(l, _, imports, block) =>
      # Note: provides have been desugared away; if this changes, revise this line
      N.a-program(l, imports.map(anf-import), anf-term(block))
  end
end

fun anf-import(i :: A.Import):
  cases(A.Import) i:
    | s-import(l, f, name) =>
      cases(A.ImportType) f:
        | s-file-import(fname) => N.a-import-file(l, fname, name)
        | s-const-import(module) => N.a-import-builtin(l, module, name)
      end
  end
end

fun anf-block(es-init :: List<A.Expr>, k :: ANFCont):
  fun anf-block-help(es):
    cases (List<A.Expr>) es:
      | empty => raise("Empty block")
      | link(f, r) =>
        # Note: assuming blocks don't end in let/var here
        if r.length() == 0:
          anf(f, k)
        else:
          cases(A.Expr) f:
            | else => anf(f, k-cont(fun(lettable):
                    t = mk-id(f.l, "anf_begin_dropped")
                    N.a-let(f.l, t.id-b, lettable, anf-block-help(r))
                  end))
          end
        end
    end
  end
  anf-block-help(es-init)
end

fun anf(e :: A.Expr, k :: ANFCont) -> N.AExpr:
  cases(A.Expr) e:
    | s-num(l, n) => k.apply(l, N.a-val(N.a-num(l, n)))
    | s-frac(l, num, den) => k.apply(l, N.a-val(N.a-num(l, num / den))) # Possibly unneeded if removed by desugar?
    | s-str(l, s) => k.apply(l, N.a-val(N.a-str(l, s)))
    | s-undefined(l) => k.apply(l, N.a-val(N.a-undefined(l)))
    | s-bool(l, b) => k.apply(l, N.a-val(N.a-bool(l, b)))
    | s-id(l, id) => k.apply(l, N.a-val(N.a-id(l, id)))
    | s-id-var(l, id) => k.apply(l, N.a-val(N.a-id-var(l, id)))
    | s-id-letrec(l, id) => k.apply(l, N.a-val(N.a-id-letrec(l, id)))

    | s-let-expr(l, binds, body) =>
      cases(List) binds:
        | empty => anf(body, k)
        | link(f, r) =>
          cases(A.LetBind) f:
            | s-var-bind(l2, b, val) => anf(val, k-cont(fun(lettable):
                    N.a-var(l2, N.a-bind(l2, b.id, b.ann), lettable,
                      anf(A.s-let-expr(l, r, body), k))
                  end))
            | s-let-bind(l2, b, val) => anf(val, k-cont(fun(lettable):
                    N.a-let(l2, N.a-bind(l2, b.id, b.ann), lettable,
                      anf(A.s-let-expr(l, r, body), k))
                  end))
          end
      end

    | s-letrec(l, binds, body) =>
      let-binds = for map(b from binds):
        A.s-var-bind(b.l, b.b, A.s-undefined(l))
      end
      assigns = for map(b from binds):
        A.s-assign(b.l, b.b.id, b.value)
      end
      anf(A.s-let-expr(l, let-binds, A.s-block(l, assigns + [body])), k)

    | s-data-expr(l, data-name, params, mixins, variants, shared, _check) =>
      fun anf-member(member :: A.VariantMember):
        cases(A.VariantMember) member:
          | s-variant-member(l2, type, b) =>
            a-type = cases(A.VariantMemberType) type:
              | s-normal => N.a-normal
              | s-cyclic => N.a-cyclic
              | s-mutable => N.a-mutable
            end
            new-bind = cases(A.Bind) b:
              | s-bind(l3, shadows, name, ann) =>
                N.a-bind(l3, name, ann)
            end
            N.a-variant-member(l2, a-type, new-bind)
        end
      end
      fun anf-variant(v :: A.Variant, kv :: (N.AVariant -> N.AExpr)):
        cases(A.Variant) v:
          | s-variant(l2, vname, members, with-members) =>
            with-exprs = with-members.map(_.value)
            anf-name-rec(with-exprs, "anf_variant_member", fun(ts):
                new-fields = for map2(f from with-members, t from ts):
                    N.a-field(f.l, f.name.s, t)
                  end
                kv(N.a-variant(l, vname, members.map(anf-member), new-fields))
              end)
          | s-singleton-variant(l2, vname, with-members) =>
            with-exprs = with-members.map(_.value)
            anf-name-rec(with-exprs, "anf_singleton_variant_member", fun(ts):
                new-fields = for map2(f from with-members, t from ts):
                    N.a-field(f.l, f.name.s, t)
                  end
                kv(N.a-singleton-variant(l, vname, new-fields))
              end)
        end
      end
      fun anf-variants(vs :: List<A.Variant>, ks :: (List<N.AVariant> -> N.AExpr)):
        cases(List) vs:
          | empty => ks([])
          | link(f, r) =>
            anf-variant(f, fun(v): anf-variants(r, fun(rest-vs): ks([v] + rest-vs););)
        end
      end
      exprs = shared.map(_.value)

      anf-name-rec(exprs, "anf_shared", fun(ts):
          new-shared = for map2(f from shared, t from ts):
              N.a-field(f.l, f.name.s, t)
            end
          anf-variants(variants, fun(new-variants):
              k.apply(l, N.a-data-expr(l, data-name, new-variants, new-shared))
            end)
        end)

    | s-if-else(l, branches, _else) =>
      cases(ANFCont) k:
        | k-id(_) =>
          for fold(acc from anf(_else, k), branch from branches.reverse()):
            anf-name(branch.test, "anf_if",
              fun(test): N.a-if(l, test, anf(branch.body, k), acc) end)
          end
        | k-cont(_) =>
          helper = mk-id(l, "if_helper")
          arg = mk-id(l, "if_helper_arg")
          N.a-let(l, helper.id-b, N.a-lam(l, [arg.id-b], k.apply(l, N.a-val(arg.id-e))),
            for fold(acc from anf(_else, k-id(helper.id)), branch from branches.reverse()):
              anf-name(branch.test, "anf_if",
                fun(test): N.a-if(l, test, anf(branch.body, k-id(helper.id)), acc) end)
            end)
      end
    | s-try(l, body, id, _except) =>
      N.a-try(l, anf-term(body), id, anf-term(_except))

    | s-block(l, stmts) => anf-block(stmts, k)
    | s-user-block(l, body) => anf(body, k)

    | s-lam(l, params, args, ret, doc, body, _) =>
      k.apply(l, N.a-lam(l, args.map(fun(a): N.a-bind(a.l, a.id, a.ann);), anf-term(body)))
    | s-method(l, args, ret, doc, body, _) =>
      k.apply(l, N.a-method(l, args.map(fun(a): N.a-bind(a.l, a.id, a.ann);), anf-term(body)))

    | s-app(l, f, args) =>
      anf-name(f, "anf_fun", fun(v):
          anf-name-rec(args, "anf_arg", fun(vs):
              k.apply(l, N.a-app(l, v, vs))
            end)
        end)

    | s-prim-app(l, f, args) =>
      anf-name-rec(args, "anf_arg", fun(vs):
          k.apply(l, N.a-prim-app(l, f, vs))
        end)

    | s-dot(l, obj, field) =>
      anf-name(obj, "anf_bracket", fun(t-obj): k.apply(l, N.a-dot(l, t-obj, field)) end)

    | s-colon(l, obj, field) =>
      anf-name(obj, "anf_colon", fun(t-obj): k.apply(l, N.a-colon(l, t-obj, field)) end)

    | s-bracket(l, obj, field) =>
      fname = cases(A.Expr) field:
          | s-str(_, s) => s
          | else => raise("Non-string field: " + torepr(field))
        end
      anf-name(obj, "anf_bracket", fun(t-obj): k.apply(l, N.a-dot(l, t-obj, fname)) end)

    | s-colon-bracket(l, obj, field) =>
      fname = cases(A.Expr) field:
          | s-str(_, s) => s
          | else => raise("Non-string field: " + torepr(field))
        end
      anf-name(obj, "anf_colon", fun(t-obj): k.apply(l, N.a-colon(l, t-obj, fname)) end)

    | s-get-bang(l, obj, field) =>
      anf-name(obj, "anf_get_bang", fun(t): k.apply(l, N.a-get-bang(l, t, field)) end)

    | s-assign(l, id, value) =>
      anf-name(value, "anf_assign", fun(v): k.apply(l, N.a-assign(l, id, v)) end)

    | s-obj(l, fields) =>
      exprs = fields.map(_.value)

      anf-name-rec(exprs, "anf_obj", fun(ts):
          new-fields = for map2(f from fields, t from ts):
              N.a-field(f.l, f.name.s, t)
            end
          k.apply(l, N.a-obj(l, new-fields))
        end)

    | s-extend(l, obj, fields) =>
      exprs = fields.map(_.value)

      anf-name(obj, "anf_extend", fun(o):
          anf-name-rec(exprs, "anf_extend", fun(ts):
              new-fields = for map2(f from fields, t from ts):
                  N.a-field(f.l, f.name.s, t)
                end
              k.apply(l, N.a-extend(l, o, new-fields))
            end)
        end)

    | s-let(_, _, _) => raise("s-let should be handled by anf-block: " + torepr(e))
    | s-var(_, _, _) => raise("s-var should be handled by anf-block: " + torepr(e))
    | else => raise("Missed case in anf: " + torepr(e))
  end
end

