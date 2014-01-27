#lang pyret

provide *
import "ast-anf.arr" as N
import ast as A

data Helper:
  | helper(name :: String, args :: List<String>, body :: N.AExpr)
end

data SplitResult:
  | split-result-e(helpers :: List<Helper>, body :: N.AExpr, freevars :: Set<String>)
  | split-result-l(helpers :: List<Helper>, body :: N.ALettable, freevars :: Set<String>)
end

fun <a> unions(ss :: List<Set<a>>) -> Set<a>:
  for fold(unioned from set([]), s from ss):
    unioned.union(s)
  end
end

fun freevars-e(expr :: N.AExpr) -> Set<String>:
  cases(N.AExpr) expr:
    | a-let(_, b, e, body) =>
      freevars-e(body).remove(b.id).union(freevars-l(e))
    | a-var(_, b, e, body) =>
      freevars-e(body).remove(b.id).union(freevars-l(e))
    | a-try(_, body, b, c) =>
      freevars-e(c).remove(b.id).union(freevars-e(body))
    | a-split-app(_, _, f, args, name, helper-args) =>
      freevars-v(f).union(unions(args.map(freevars-v)).union(unions(helper-args.rest.map(freevars-v)))).remove(name)
    | a-lettable(e) => freevars-l(e)
  end
where:
  d = N.dummy-loc
  freevars-e(
      N.a-let(d, N.a-bind(d, "x", A.a_blank), N.a-val(N.a-num(d, 4)),
        N.a-lettable(N.a-val(N.a-id(d, "y"))))).to-list() is ["y"]
end

fun freevars-l(e :: N.ALettable) -> Set<String>:
  cases(N.ALettable) e:
    | a-assign(_, id, v) => freevars-v(v).union(set([id]))
    | a-app(_, f, args) => freevars-v(f).union(unions(args.map(freevars-v)))
    | a-help-app(_, _, args) => unions(args.map(freevars-v))
    | a-lam(_, args, body) => freevars-e(body).difference(set(args.map(_.id)))
    | a-method(_, args, body) => freevars-e(body).difference(set(args.map(_.id)))
    | a-obj(_, fields) => unions(fields.map(fun(f): freevars-v(f.value) end))
    | a-if(_, c, t, e) =>
      freevars-v(c).union(freevars-e(t)).union(freevars-e(e))
    | a-update(_, super, fields) => freevars-v(super).union(unions(fields.map(_.value).map(freevars-v)))
    | a-extend(_, super, fields) => freevars-v(super).union(unions(fields.map(_.value).map(freevars-v)))
    | a-dot(_, obj, _) => freevars-v(obj)
    | a-colon(_, obj, _) => freevars-v(obj)
    | a-get-bang(_, obj, _) => freevars-v(obj)
    | a-val(v) => freevars-v(v)
  end
end

fun freevars-v(v :: N.AVal) -> Set<String>:
  cases(N.AVal) v:
    | a-id(_, id) => set([id])
    | a-id-var(_, id) => set([id])
    | a-id-letrec(_, id) => set([id])
    | else => set([])
  end
end

fun ast-split(expr :: N.AExpr) -> SplitResult:
  fun handle-bind(l, is-var, b, e, body):
    cases(N.ALettable) e:
      | a-app(l2, f, args) =>
        rest-split = ast-split(body)
        fvs = rest-split.freevars.remove(b.id)
        h = helper(gensym(b.id), link(b.id, fvs.to-list()), rest-split.body)
        split-result-e(
            link(h, rest-split.helpers),
            N.a-split-app(l, is-var, f, args, h.name, h.args.map(N.a-id(l, _))),
            fvs.remove(b.id).union(unions(args.map(freevars-v))).union(freevars-v(f))
          )
      | else =>
        e-split = ast-split-lettable(e)
        rest-split = ast-split(body)
        split-result-e(
            rest-split.helpers + e-split.helpers,
            if is-var:
              N.a-var(l, b, e-split.body, rest-split.body)
            else:
              N.a-let(l, b, e-split.body, rest-split.body)
            end,
            e-split.freevars.union(rest-split.freevars.remove(b.id))
          )
    end
  end
  cases(N.AExpr) expr:
    | a-let(l, b, e, body) =>
      handle-bind(l, false, b, e, body)
    | a-var(l, b, e, body) =>
      handle-bind(l, true, b, e, body)
    | a-lettable(e) =>
      let-result = ast-split-lettable(e)
      split-result-e(let-result.helpers, N.a-lettable(let-result.body), let-result.freevars)
    | else => raise("NYI: " + torepr(expr))
  end
end

fun ast-split-lettable(e :: N.ALettable) -> is-split-result-l:
  cases(N.ALettable) e:
    | a-lam(l, args, body) =>
      body-split = ast-split(body)
      split-result-l(
          body-split.helpers,
          N.a-lam(l, args, body-split.body),
          body-split.freevars.difference(set(args.map(_.id)))
        )
    | a-method(l, args, body) =>
      body-split = ast-split(body)
      split-result-l(
          body-split.helpers,
          N.a-method(l, args, body-split.body),
          body-split.freevars.difference(set(args.map(_.id)))
        )
    | a-if(l, cond, consq, alt) =>
      consq-split = ast-split(consq)
      alt-split = ast-split(alt)
      split-result-l(
          consq-split.helpers + alt-split.helpers,
          N.a-if(l, cond, consq-split.body, alt-split.body),
          freevars-v(cond).union(consq-split.freevars).union(alt-split.freevars)
        )
    | else =>
      split-result-l([], e, freevars-l(e))
  end
end

fun param(l, name):
  N.a-bind(l, name, A.a_blank)
end

check:
  fun strip-helper(h):
    cases(Helper) h:
      | helper(name, args, body) => helper(name, args, N.strip-loc-expr(body))
    end
  end
  fun split-strip(e):
    res = ast-split(e)
    split-result-e(res.helpers.map(strip-helper), N.strip-loc-expr(res.body))
  end
  b = A.a_blank
  d = N.dummy-loc
  e1 = N.a-lettable(N.a-val(N.a-num(d, 5)))
  split-strip(e1) is split-result-e([], e1, set([]))

  e2 = N.a-let(d, N.a-bind(d, "x", A.a_blank), N.a-val(N.a-num(d, 5)), N.a-lettable(N.a-val(N.a-id(d, "x"))))
  split-strip(e2) is split-result-e([], e2, set([]))

  e3 = N.a-let(d, N.a-bind(d, "v", A.a_blank), N.a-app(d, N.a-id(d, "f"), [N.a-num(d, 5)]),
    N.a-lettable(N.a-val(N.a-id(d, "v"))))
  e3-split = split-strip(e3)
  e3-split.helpers.length() is 1
  e3-split.helpers.first.body is
    N.a-lettable(N.a-val(N.a-id(d, "v")))
  e3-split.body is
    N.a-split-app(d, false, N.a-id(d, "f"), [N.a-num(d, 5)], e3-split.helpers.first.name, [N.a-id(d, "v")])
end

