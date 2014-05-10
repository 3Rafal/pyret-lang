#lang pyret

import cmdline as C
import parse-pyret as P
# import "compiler/desugar.arr" as D
import "compiler/desugar-check.arr" as DC
# import "compiler/anf.arr" as A
# import "compiler/compile.arr" as CM
import "compiler/compile-structs.arr" as CS
import "compiler/resolve-scope.arr" as R
import ast as A
import "compiler/ast-util.arr" as U
# import "compiler/anf.arr" as N
# import "compiler/ast-split.arr" as AS
# import "compiler/js-of-pyret.arr" as JS
# import "compiler/desugar-check.arr" as CH
import file as F
import string-dict as S
import pprint as PP

options = {
  width: C.next-val-default(C.Number, 80, some("w"), C.once, "Pretty-printed width"),
  dialect: C.next-val-default(C.String, "Pyret", some("d"), C.once, "Dialect to use")
}

parsed-options = C.parse-cmdline(options)

fun break-if-needed(items):
  for fold(acc from PP.mt-doc, item from items.reverse()):
    if is-comment(item): item.tosource() + acc
    else if is-at-comment(item): item.tosource() + acc
    else if PP.is-mt-doc(acc): item.tosource()
    else: item.tosource() + PP.break(1) + acc
    end
  end
end
data SExp:
  | hashlang(str :: String) with: tosource(self): PP.str("#lang " + self.str) end
  | at-app(name :: String, kids :: List<SExp>) with:
    tosource(self):
      PP.str("@") + PP.parens(break-if-needed(leaf(self.name) ^ link(self.kids)))
    end
  | leaf(val :: String) with: tosource(self): PP.str(self.val) end
  | sexp(name :: String, kids :: List<SExp>) with:
    tosource(self):
      kids = break-if-needed(leaf(self.name)^link(self.kids))
      PP.parens(PP.nest(2, kids))
    end
  | at-comment(msg :: String) with: tosource(self): PP.str("@; " + self.msg) + PP.hardline end
  | comment(msg :: String) with: tosource(self): PP.str(";; " + self.msg) + PP.hardline end
  | toplevel(kids :: List<SExp>) with:
    tosource(self): break-if-needed(self.kids) end
  | slist(kids :: List<SExp>) with:
    tosource(self):
      PP.parens(break-if-needed(self.kids))
    end
  | hash-key(name :: String, val :: SExp) with:
    tosource(self):
      PP.group(PP.str("#:" + self.name) + PP.break(1) + self.val.tosource())
    end
  | at-exp(name :: String, raw :: Option<List<SExp>>, processed :: Option<List<SExp>>) with:
    tosource(self):
      PP.str("@" + self.name) +
      cases(Option) self.raw:
        | none => PP.mt-doc
        | some(raw) => PP.brackets(PP.nest(2, PP.break(0) + break-if-needed(raw)) + PP.break(0))
      end +
      cases(Option) self.processed:
        | none => PP.mt-doc
        | some(kids) => PP.braces(PP.nest(2, PP.break(0) + break-if-needed(kids)) + PP.break(0))
      end
    end
end

fun spair(name, val):
  if SExp(val): sexp(name, [val])
  else: sexp(name, [leaf(tostring(val))])
  end
end

fun find-result(expr):
  cases(A.Expr) expr:
    | s-obj(_, _) => expr
    | s-block(_, stmts) => find-result(stmts.last())
    | s-let-expr(_, _, body) => find-result(body)
    | s-letrec(_, _, body) => find-result(body)
    | else =>
      print("Got an expression we didn't expect:")
      print(torepr(expr))
      raise("Failure?")
  end
end

fun trim-path(path):
  var ret = path
  var prefixes = S.to-dict({
      trove: "",
      js: "js/",
      base: "",
      compiler: "compiler/"
    })
  ret := string-replace(ret, "\\", "/")
  for each(prefix from prefixes.keys()):
    i = string-index-of(ret, prefix + "/")
    when i >= 0:
      ret := string-replace(string-substring(ret, i, string-length(ret)), prefix + "/", prefixes.get(prefix))
      if string-index-of(prefixes.get(prefix), "/") >= 0:
        ret := '"' + ret + '"'
      else:
        ret := string-replace(ret, ".arr", "")
      end
    end
  end
  ret
end

data CrossRef:
  | crossref(module :: String, field :: String) with:
    tosource(self): PP.str(torepr(self)) end
end

fun lookup-value(value, bindings):
  fun help(seen, item):
    to-examine =
      if A.Name(item):
        if seen.member(item): none
        else if bindings.has-key(item.key()):
          bindings.get(item.key()).expr
        else: none
        end
      else if A.Expr(item): some(item)
      else: none
      end
    cases(Option) to-examine:
      | none => value
      | some(v) =>
        cases(A.Expr) v:
          | s-id(_, id) => help(item^link(seen), id)
          | s-id-letrec(_, id) => help(item^link(seen), id)
          | s-id-var(_, id) => help(item^link(seen), id)
          | s-block(_, stmts) => help(seen, stmts.last())
          | s-user-block(_, body) => help(seen, body)
          | s-let-expr(_, _, body) => help(seen, body)
          | s-letrec(_, _, body) => help(seen, body)
          | s-let(_, _, _, body) => help(seen, body)
          | s-dot(_, obj, field) =>
            help-obj = help(seen, obj)
            cases(A.Expr) help-obj:
              | s-import(_, file, _) => crossref(file.tosource().pretty(1000).first, field)
              | s-obj(_, obj-fields) =>
                cases(Option) obj-fields.find(fun(f): A.is-s-str(f.name) and (f.name.s == field) end):
                  | none => v
                  | some(new-v) => help(seen, new-v)
                end
              | s-data-expr(_, name, _, _, variants, shared-members, _) =>
                if (name == field):
                  help-obj
                else:
                  cases(Option) variants.find(fun(f): f.name == field end):
                    | some(new-v) => new-v
                    | none =>
                      cases(Option) variants.find(fun(f): A.make-checker-name(f.name) == field end):
                        | some(new-v) =>
                          a-an =
                            if string-index-of("aeiou", string-substring(new-v.name, 0, 1)) >= 0: "an "
                            else: "a "
                            end
                          A.s-lam(new-v.l, empty,
                            [A.s-bind(new-v.l, false, A.s-name(new-v.l, "val"), A.a-any)],
                            A.a-name(new-v.l, A.s-global("Bool")),
                            "Checks whether the provided argument is in fact " + a-an + new-v.name,
                            A.s-undefined(new-v.l), none)
                        | none =>
                          cases(Option) shared-members.find(fun(f): A.is-s-str(f.name) and (f.name.s == field) end):
                            | some(new-v) => new-v
                            | none => v
                          end
                      end
                  end
                end
              | else => v
            end
          | else => v
        end
    end
  end
  help([], value)
end
fun tosource(val):
  if is-string(val): PP.str(val)
  else if S.to-dict(val).has-key("tosource"): val.tosource()
  else: PP.str(torepr(val))
  end
end
fun process-fields(module-name, fields, bindings):
  var looked-up = S.immutable-string-dict()
  for each(field from fields):
    field-name =
      if A.is-s-str(field.name): field.name.s
      else: field.name.tosource().pretty(1000).first
      end
    value = lookup-value(field.value, bindings)
    # print("Binding " + torepr(field-name) + " to " + value^tosource().pretty(80).first)
    looked-up := looked-up.set(field-name, value)
  end
  var data-vals = S.immutable-string-dict()
  var fun-vals = S.immutable-string-dict()
  var ignored-vals = S.immutable-string-dict()
  var unknown-vals = S.immutable-string-dict()
  var imports = S.immutable-string-dict()
  var cross-refs = S.immutable-string-dict()
  for each(field from looked-up.keys()):
    value = looked-up.get(field)
    cases(A.Expr) value:
      | crossref(_, _) =>
        imports := imports.set(field, value)
        cross-refs := cross-refs.set(field, value)
      | s-lam(_, _, _, _, _, _, _) =>
        if (string-index-of(field, "\"is-") == 0):
          ignored-vals := ignored-vals.set(field, value)
        else:
          fun-vals := fun-vals.set(field, value)
        end
        cross-refs := cross-refs.set(field, crossref(module-name, field))
      | s-variant(_, _, _, _, _) =>
        cross-refs := cross-refs.set(field, crossref(module-name, field))
      | s-singleton-variant(_, _, _) =>
        cross-refs := cross-refs.set(field, crossref(module-name, field))
      | s-data-expr(_, _, _, _, _, _, _) =>
        data-vals := data-vals.set(field, value)
        cross-refs := cross-refs.set(field, crossref(module-name, field))
      | else =>
        unknown-vals := unknown-vals.set(field, value)
        cross-refs := cross-refs.set(field, crossref(module-name, field))
    end
  end
  { data-vals: data-vals,
    fun-vals: fun-vals,
    ignored-vals: ignored-vals,
    unknown-vals: unknown-vals,
    imports: imports,
    cross-refs: cross-refs
  }
end

no-atoms = A.default-map-visitor.{
  s-atom(self, base, _): A.s-name(A.dummy-loc, base) end,
  s-id-letrec(self, l, name): A.s-id(l, A.s-name(l, name.toname())) end,
  s-id-var(self, l, name): A.s-id(l, A.s-name(l, name.toname())) end
}
fun de-atomize(e): e.visit(no-atoms) end

fun xref(modname, as-name):
  sexp("xref", [leaf(torepr(modname)), leaf(torepr(as-name))])
end

fun process-ann(ann, file, fields, bindings):
  cases(A.Ann) ann:
    | a-name(l, name) =>
      cases(A.Name) name:
        | s-global(_) =>
          sexp("list", [leaf(torepr(name.toname())), xref("<global>", name.toname())])
        | else =>
          if fields.cross-refs.has-key(name.toname()):
            cases(CrossRef) fields.cross-refs.get(name.toname()):
              | crossref(modname, as-name) =>
                sexp("list", [leaf(torepr(name.toname())), xref(modname, as-name)])
            end
          else if bindings.has-key(name.key()):# and (bindings.get(name.toname()) == name.toname()):
            val = lookup-value(name, bindings)
            cases(Any) val:
              | crossref(modname, as-name) =>
                sexp("list", [leaf(torepr(name.toname())), xref(modname, as-name)])
              | s-data-expr(_, data-name, _, _, _, _, _) =>
                sexp("list", [leaf(torepr(name.toname())), xref(trim-path(file), data-name)])
              | else =>
                if (val == name):
                  leaf(torepr(name.toname()))
                else:
                  print("We found " + torepr(val))
                  leaf(torepr(name.toname()))
                end
            end
          else if bindings.has-key(name.toname()):# and (bindings.get(name.toname()) == name.toname()):
            leaf(torepr(name.toname()))
          else if fields.data-vals.has-key(name.toname()):
            cases(Any) fields.data-vals.get(name.toname()):
              | crossref(modname, as-name) =>
                sexp("list", [leaf(torepr(name.toname())), xref(modname, as-name)])
              | else =>
                print("Found " + torepr(fields.data-vals.get(name.toname())))
                leaf(torepr(name.toname()))
            end
          else:
            # print("Looking for " + torepr(name) + " in " + torepr(fields.cross-refs.keys()))
            # print("Looking for " + torepr(name) + " in " + torepr(bindings.keys()))
            print("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX Got " + torepr(name) + " at " + tostring(l) + " and no crossref for it")
            leaf(torepr(ann.tosource().pretty(1000).first))
          end
      end
    | a-app(l, base, args) =>
      sexp("a-app", process-ann(base, file, fields, bindings) ^ link(args.map(process-ann(_, file, fields, bindings))))
    | a-dot(l, obj, field) =>
      bound-as-import = lookup-value(obj, bindings)
      if A.is-s-import(bound-as-import):
        sexp("list", [sexp("a-dot", [leaf(torepr(obj.toname())), leaf(torepr(field))]),
            xref(bound-as-import.file.tosource().pretty(1000).first, field)])
      else:
        sexp("a-dot", [process-ann(obj, file, fields, bindings), leaf(torepr(field))])
      end
    | a-arrow(l, args, ret, _) =>
      sexp("a-arrow", args.map(process-ann(_, file, fields, bindings)) + [process-ann(ret, file, fields, bindings)])
    | a-record(l, rec-fields) =>
      sexp("a-record", rec-fields.map(fun(f):
          sexp("a-field", [leaf(torepr(f.name)), process-ann(f.ann, file, fields, bindings)]) end))
    | else => leaf(torepr(ann.tosource().pretty(1000).first))
  end
end

fun process-member(mem, type, file, fields, bindings):
  cases(A.Member) mem:
    | s-data-field(_, name, value) =>
      at-exp("member-spec", some([leaf(torepr(name.tosource().pretty(1000).first))]), none)
    | s-mutable-field(_, name, ann, value) =>
      at-exp("member-spec",
        some([
            leaf(name.tosource().pretty(1000).first),
            hash-key("mutable", "#t"),
            hash-key("contract", process-ann(ann, file, fields, bindings))
          ]),
        none)
    | s-once-field(_, name, ann, value) =>
      at-exp("member-spec",
        some([
            leaf(name.tosource().pretty(1000).first),
            hash-key("once", "#t"),
            hash-key("contract", process-ann(ann, file, fields, bindings))
          ]),
        none)
    | s-method-field(_, name, args, ret-ann, doc, body, _check) =>
      at-exp("method-spec", some(
          [ leaf(name.tosource().pretty(1000).first),
            hash-key("contract",
              sexp("a-arrow",
                [process-ann(A.a-name(A.dummy-loc, type), file, fields, bindings)] +
                args.rest.map(fun(a): process-ann(a.ann, file, fields, bindings) end) +
                [process-ann(ret-ann, file, fields, bindings)]))
          ]),
        _check.andthen(fun(v): some(de-atomize(v).tosource().pretty(80).map(at-comment)) end))
  end
end
fun process-var-member(mem, file, fields, bindings):
  cases(A.VariantMember) mem:
    | s-variant-member(_, type, b) =>
      at-exp("member-spec",
        some(
          [ leaf(torepr(b.id.toname())), hash-key("contract", process-ann(b.ann, file, fields, bindings)) ]
            + (cases(A.VariantMemberType) type:
              | s-cyclic => [spair("cyclic", "#t")]
              | s-mutable => [spair("mutable", "#t")]
              | s-normal => []
            end)),
        none)
  end
end


fun process-module(file, fields, bindings):
  # print("Binding keys are " + torepr(bindings.keys()))
  # print("Data keys are " + torepr(fields.data-vals.keys()))
  # print("Fun keys are " + torepr(fields.fun-vals.keys()))
  fun process-item(name :: String, e):
    cases(A.Expr) e: # Not guaranteed to be an Expr!
      | crossref(modname, as-name) =>
        at-exp("re-export",
          some([leaf(torepr(name)), spair("from", xref(modname, as-name))]),
          some([
              at-comment("N.B. need para here to keep xref inline with text"),
              at-exp("para", none,
                some([leaf("See"),
                    at-exp("xref", some([leaf(torepr(modname)), leaf(torepr(as-name))]), none)]))
            ]))
      | s-lam(_, params, args, ret-ann, doc, _, _check) =>
        new-bindings = for fold(acc from bindings, param from params):
          acc.set(param, param)
        end
        at-exp("function", some(
            [ leaf(torepr(name)) ] +
            ( if is-empty(params): []
              else: [ hash-key("params", sexp("list", params.map(fun(p): leaf(torepr(p)) end))) ]
              end) +
            [ hash-key("contract",
                sexp("a-arrow", args.map(fun(a): process-ann(a.ann, file, fields, new-bindings) end) +
                  [process-ann(ret-ann, file, fields, new-bindings)]))
            ]),
          _check.andthen(fun(v): some(de-atomize(v).tosource().pretty(80).map(at-comment)) end))
      | s-id(_, id) =>
        spair("unknown-item", spair("name", name))
      | s-data-expr(_, data-name, params, _, variants, shared, _) =>
        new-bindings = for fold(acc from bindings, param from params):
          acc.set(param, param)
        end
        at-exp("data-spec",
          some([ leaf(torepr(data-name)) ] +
            ( if is-empty(params): []
              else: [ hash-key("params", sexp("list", params.map(fun(p): leaf(torepr(p)) end))) ]
              end)),
          some([
              at-exp("variants", none, some(variants.map(fun(v):
                      cases(A.Variant) v:
                        | s-variant(_, _, variant-name, members, with-members) =>
                          at-exp("constr-spec",
                            some([leaf(torepr(variant-name))]),
                            some([
                                at-exp("members", none, some(members.map(process-var-member(_, file, fields, new-bindings)))),
                                at-exp("with-members", none, some(with-members.map(process-member(_, A.s-name(A.dummy-loc, name), file, fields, new-bindings))))
                              ]))
                        | s-singleton-variant(_, variant-name, with-members) =>
                          at-exp("singleton-spec",
                            some([leaf(torepr(variant-name))]),
                            some([
                                at-exp("with-members", none, some(with-members.map(process-member(_, A.s-name(A.dummy-loc, name), file, fields, new-bindings))))
                              ]))
                      end
                    end))),
              at-exp("shared", none, some(shared.map(process-member(_, A.s-name(A.dummy-loc, name), file, fields, new-bindings))))
            ]))
      | s-variant(_, _, variant-name, members, with-members) =>
        at-comment('ERROR: Unprocessed data constructor ' + variant-name)
      | s-singleton-variant(_,  variant-name, with-members) =>
        at-comment('ERROR: Singleton data variant ' + variant-name)
      | else =>
        spair("unknown-item",
          spair("name", name) ^ link(e.tosource().pretty(70).map(at-comment)))
    end
  end
  at-exp("docmodule", some([leaf(torepr(trim-path(file)))]),
    some(
      ( if fields.ignored-vals.keys().length() > 0:
          [ at-comment("Ignored type testers"),
            at-exp("ignore", some([sexp("list", fields.ignored-vals.keys().map(leaf))]), none)]
        else: []
        end) +
      ( if fields.unknown-vals.keys().length() > 0:
          [ at-comment("Unknown: PLEASE DOCUMENT"),
            at-exp("ignore", some([sexp("list", fields.unknown-vals.keys().map(leaf))]), none)]
        else: []
        end)
        + [at-exp("section", none, some([leaf("Re-exported values")]))]
        + fields.imports.keys().map(fun(k): process-item(k, fields.imports.get(k)) end)
        + [at-exp("section", none, some([leaf("Data types")]))]
        + fields.data-vals.keys().map(fun(k): process-item(k, fields.data-vals.get(k)) end)
        + [at-exp("section", none, some([leaf("Functions")]))]
        + fields.fun-vals.keys().map(fun(k): process-item(k, fields.fun-vals.get(k)) end)))
end

cases (C.ParsedArguments) parsed-options:
  | success(opts, rest) =>
    print-width = opts.get("width")
    dialect = opts.get("dialect")
    cases (List) rest:
      | empty => print("Require a file name")
      | link(file, _) =>
        file-contents = F.file-to-string(file)
        parsed = P.parse-dialect(dialect, file-contents, file)
        scoped = R.desugar-scope(DC.desugar-no-checks(U.append-nothing-if-necessary(parsed)), CS.minimal-builtins)
        named-and-bound = R.resolve-names(scoped, CS.minimal-builtins)
        named = named-and-bound.ast
        bindings = named-and-bound.bindings
        body = named.block
        result = find-result(body)
        cases(A.Expr) result:
          | s-obj(_, res) =>
            provides = res.find(fun(f): A.is-s-data-field(f) and A.is-s-str(f.name) and (f.name.s == "provide") end)
            cases(Option) provides:
              | none => print("Got a result object with no provides fields")
              | some(p) =>
                cases(A.Expr) find-result(p.value):
                  | s-obj(_, fields) =>
                    output = toplevel([
                        hashlang("scribble/base"),
                        at-app("require", [leaf(torepr("../scribble-api.rkt"))]),
                        process-module(file, process-fields(trim-path(file), fields, bindings), bindings)
                      ])
                    nothing
                    output.tosource().pretty(80).each(print)
                  | else => nothing
                end
            end
          | else => print("Got a result we didn't expect")
            print(torepr(result))
        end
    end
  | arg-error(m, _) =>
    each(print,  ("Error: " + m) ^ link(C.usage-info(options)))
end
