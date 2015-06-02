#lang pyret

provide *
provide-types *
import ast as A
import sets as S
import "compiler/ast-anf.arr" as N
import "compiler/js-ast.arr" as J
import "compiler/gensym.arr" as G
import "compiler/compile-structs.arr" as CS
import "compiler/concat-lists.arr" as CL
import string-dict as D
import srcloc as SL

type ConcatList = CL.ConcatList
type NameSet = D.StringDict<A.Name>

cl-sing = CL.concat-singleton
cl-empty = CL.concat-empty
ns-empty = D.make-string-dict()

fun difference(s1 :: NameSet, s2 :: NameSet):
  for fold(acc from s1, k2 from s2.keys-list()):
    acc.remove(k2)
  end
end

data GraphNode:
  | node(_from :: J.Label, _to :: ConcatList<J.Label>, case-body :: J.JCase,
      ref free-vars :: NameSet,
      ref used-vars :: NameSet,
      ref decl-vars :: NameSet,
      ref live-vars :: Option<NameSet>,
      ref live-after-vars :: Option<NameSet>,
      ref dead-vars :: Option<NameSet>,
      ref dead-after-vars :: Option<NameSet>)
    # note: _to is a set, determined by identical
end

data CaseResults:
  | c-exp(exp :: J.JExpr, other-stmts :: List<J.JStmt>)
  | c-field(field :: J.JField, other-stmts :: List<J.JStmt>)
  | c-block(block :: J.JBlock, new-cases :: ConcatList<J.JCase>)
end

data RegisterAllocation:
  | results(body :: ConcatList<J.JCase>, discardable-vars :: NameSet)
end

fun used-vars-jblock(b :: J.JBlock) -> NameSet:
  for fold(acc from ns-empty, s from b.stmts):
    acc.merge(used-vars-jstmt(s))
  end
end
fun declared-vars-jblock(b :: J.JBlock) -> NameSet:
  for fold(acc from ns-empty, s from b.stmts):
    acc.merge(declared-vars-jstmt(s))
  end
end
fun declared-vars-jstmt(s :: J.JStmt) -> NameSet:
  cases(J.JStmt) s:
    | j-var(name, rhs) => ns-empty.set(name.key(), name)
    | j-if1(cond, consq) => declared-vars-jblock(consq)
    | j-if(cond, consq, alt) => declared-vars-jblock(consq).merge(declared-vars-jblock(alt))
    | j-return(expr) => ns-empty
    | j-try-catch(body, exn, catch) => declared-vars-jblock(body).merge(declared-vars-jblock(catch))
    | j-throw(exp) => ns-empty
    | j-expr(expr) => ns-empty
    | j-break => ns-empty
    | j-continue => ns-empty
    | j-switch(exp, branches) =>
      for fold(acc from ns-empty, b from branches):
        acc.merge(declared-vars-jcase(b))
      end
    | j-while(cond, body) => declared-vars-jblock(body)
    | j-for(create-var, init, cont, update, body) =>
      ans = declared-vars-jblock(body)
      if create-var and J.is-j-assign(init): ans.set(init.name.key(), init.name)
      else: ans
      end
  end
end
fun used-vars-jstmt(s :: J.JStmt) -> NameSet:
  cases(J.JStmt) s:
    | j-var(name, rhs) => used-vars-jexpr(rhs).remove(name.key())
    | j-if1(cond, consq) => used-vars-jexpr(cond).merge(used-vars-jblock(consq))
    | j-if(cond, consq, alt) =>
      used-vars-jexpr(cond).merge(used-vars-jblock(consq)).merge(used-vars-jblock(alt))
    | j-return(expr) => used-vars-jexpr(expr)
    | j-try-catch(body, exn, catch) => used-vars-jblock(body).merge(used-vars-jblock(catch).remove(exn.key()))
    | j-throw(exp) => used-vars-jexpr(exp)
    | j-expr(expr) => used-vars-jexpr(expr)
    | j-break => ns-empty
    | j-continue => ns-empty
    | j-switch(exp, branches) =>
      for fold(acc from used-vars-jexpr(exp), b from branches):
        acc.merge(used-vars-jcase(b))
      end
    | j-while(cond, body) => used-vars-jexpr(cond).merge(used-vars-jblock(body))
    | j-for(create-var, init, cont, update, body) =>
      ans = used-vars-jexpr(init)
        .merge(used-vars-jexpr(cont))
        .merge(used-vars-jexpr(update))
        .merge(used-vars-jblock(body))
      if create-var and J.is-j-assign(init): ans.remove(init.name.key())
      else: ans
      end
  end
end
fun used-vars-jexpr(e :: J.JExpr) -> NameSet:
  cases(J.JExpr) e:
    | j-parens(exp) => used-vars-jexpr(exp)
    | j-unop(exp, op) => used-vars-jexpr(exp)
    | j-binop(left, op, right) => used-vars-jexpr(left).merge(used-vars-jexpr(right))
    | j-fun(args, body) =>
      used = difference(used-vars-jblock(body), declared-vars-jblock(body))
      for fold(acc from used, a from args):
        acc.remove(a.key())
      end
    | j-new(func, args) =>
      for fold(acc from used-vars-jexpr(func), a from args):
        acc.merge(used-vars-jexpr(a))
      end
    | j-app(func, args) =>
      for fold(acc from used-vars-jexpr(func), a from args):
        acc.merge(used-vars-jexpr(a))
      end
    | j-method(obj, meth, args) =>
      for fold(acc from used-vars-jexpr(obj), a from args):
        acc.merge(used-vars-jexpr(a))
      end
    | j-ternary(test, consq, altern) =>
      used-vars-jexpr(test).merge(used-vars-jexpr(consq)).merge(used-vars-jexpr(altern))
    | j-assign(name, rhs) => used-vars-jexpr(rhs).set(name.key(), name)
    | j-bracket-assign(obj, field, rhs) =>
      used-vars-jexpr(obj).merge(used-vars-jexpr(field)).merge(used-vars-jexpr(rhs))
    | j-dot-assign(obj, name, rhs) => used-vars-jexpr(obj).merge(used-vars-jexpr(rhs))
    | j-dot(obj, field) => used-vars-jexpr(obj)
    | j-bracket(obj, field) => used-vars-jexpr(obj).merge(used-vars-jexpr(obj))
    | j-list(_, elts) =>
      for fold(acc from ns-empty, elt from elts):
        acc.merge(used-vars-jexpr(elt))
      end
    | j-obj(fields) =>
      for fold(acc from ns-empty, f from fields):
        acc.merge(used-vars-jfield(f))
      end
    | j-id(id) => ns-empty.set(id.key(), id)
    | j-str(_) => ns-empty
    | j-num(_) => ns-empty
    | j-true => ns-empty
    | j-false => ns-empty
    | j-null => ns-empty
    | j-undefined => ns-empty
    | j-label(_) => ns-empty
  end
end
fun declared-vars-jcase(c :: J.JCase) -> NameSet:
  cases(J.JCase) c:
    | j-case(exp, body) => declared-vars-jblock(body)
    | j-default(body) => declared-vars-jblock(body)
  end
end
fun used-vars-jcase(c :: J.JCase) -> NameSet:
  cases(J.JCase) c:
    | j-case(exp, body) => used-vars-jexpr(exp).merge(used-vars-jblock(body))
    | j-default(body) => used-vars-jblock(body)
  end
end
fun used-vars-jfield(f :: J.JField) -> NameSet:
  used-vars-jexpr(f.value)
end

fun compute-live-vars(n :: GraphNode, dag :: D.StringDict<GraphNode>):
  cases(Option) n!live-vars:
    | some(live) => live
    | none =>
      live-after = for CL.foldl(acc from n!free-vars, follow from n._to):
        cases(Option) dag.get(tostring(follow.get())):
          | none => acc
          | some(next) => acc.merge(compute-live-vars(next, dag))
        end
      end
      decls = n!decl-vars
      live = difference(live-after, decls)
      dead-after = difference(decls, live-after)
      dead = difference(dead-after, n!used-vars)
      n!{live-after-vars: some(live-after), live-vars: some(live),
        dead-after-vars: some(dead-after), dead-vars: some(dead)}
      live
  end
end

fun find-steps-to(rev-stmts :: List<J.JStmt>, step :: A.Name):
  cases(List) rev-stmts:
    | empty => cl-empty
    | link(stmt, rest) =>
      cases(J.JStmt) stmt:
        | j-var(name, rhs) => find-steps-to(rest, step)
        | j-if1(cond, consq) => find-steps-to(consq.stmts.reverse(), step) + find-steps-to(rest, step)
        | j-if(cond, consq, alt) =>
          find-steps-to(consq.stmts.reverse(), step)
            + find-steps-to(alt.stmts.reverse(), step)
            + find-steps-to(rest, step)
        | j-return(expr) => find-steps-to(rest, step)
        | j-try-catch(body, exn, catch) => find-steps-to(rest, step)
        | j-throw(exp) => find-steps-to(rest, step)
        | j-expr(expr) =>
          if J.is-j-assign(expr) and (expr.name == step):
            if J.is-j-label(expr.rhs):
              # simple assignment statement to $step
              cl-sing(expr.rhs.label) + find-steps-to(rest, step)
            else if J.is-j-binop(expr.rhs) and (expr.rhs.op == J.j-or):
              # $step gets a cases dispatch
              # ASSUMES that the dispatch table is assigned two statements before this one
              dispatch-table = rev-stmts.rest.rest.first.rhs
              for fold(acc from cl-sing(expr.rhs.right.label), field from dispatch-table.fields):
                acc + cl-sing(field.value.label)
              end
                + find-steps-to(rest, step)
            else:
              raise("Should not happen")
            end
          else:
            find-steps-to(rest, step)
          end
        | j-break => find-steps-to(rest, step)
        | j-continue => find-steps-to(rest, step)
        | j-switch(exp, branches) => find-steps-to(rest, step)
        | j-while(cond, body) => find-steps-to(rest, step)
        | j-for(create-var, init, cont, update, body) => find-steps-to(rest, step)
      end
  end
end

fun ignorable(rhs):
  if J.is-j-app(rhs):
    (J.is-j-id(rhs.func) and (rhs.func.id.toname() == "G"))
  else if J.is-j-method(rhs):
    (J.is-j-id(rhs.obj) and (rhs.obj.id.toname() == "R") and ((rhs.meth == "getFieldRef") or (rhs.meth == "getDotAnn")))
  else:
    false
  end
end


fun elim-dead-vars-jblock(block :: J.JBlock, dead-vars :: NameSet):
  J.j-block(elim-dead-vars-jstmts(block.stmts, dead-vars))
end
fun elim-dead-vars-jstmts(stmts :: List<J.JStmt>, dead-vars :: NameSet):
  cases(List) stmts:
    | empty => empty
    | link(s, rest) =>
      cases(J.JStmt) s:
        | j-var(name, rhs) =>
          if dead-vars.has-key(name.key()):
            if ignorable(rhs): elim-dead-vars-jstmts(rest, dead-vars)
            else: link(J.j-expr(rhs), elim-dead-vars-jstmts(rest, dead-vars))
            end
          else:
            link(s, elim-dead-vars-jstmts(rest, dead-vars))
          end
        | j-if1(cond, consq) =>
          J.j-if1(cond, elim-dead-vars-jblock(consq, dead-vars))
            ^ link(_, elim-dead-vars-jstmts(rest, dead-vars))
        | j-if(cond, consq, alt) =>
          J.j-if(cond, elim-dead-vars-jblock(consq, dead-vars), elim-dead-vars-jblock(alt, dead-vars))
            ^ link(_, elim-dead-vars-jstmts(rest, dead-vars))
        | j-return(expr) => link(s, elim-dead-vars-jstmts(rest, dead-vars))
        | j-try-catch(body, exn, catch) =>
          J.j-try-catch(elim-dead-vars-jblock(body, dead-vars), exn, elim-dead-vars-jblock(catch, dead-vars))
            ^ link(_, elim-dead-vars-jstmts(rest, dead-vars))
        | j-throw(exp) => link(s, elim-dead-vars-jstmts(rest, dead-vars))
        | j-expr(expr) => link(s, elim-dead-vars-jstmts(rest, dead-vars))
        | j-break => link(s, elim-dead-vars-jstmts(rest, dead-vars))
        | j-continue => link(s, elim-dead-vars-jstmts(rest, dead-vars))
        | j-switch(exp, branches) =>
          new-switch-branches = for map(b from branches):
            elim-dead-vars-jcase(b, dead-vars)
          end
          J.j-switch(exp, new-switch-branches)
            ^ link(_, elim-dead-vars-jstmts(rest, dead-vars))
        | j-while(cond, body) =>
          J.j-while(cond, elim-dead-vars-jblock(body, dead-vars))
            ^ link(_, elim-dead-vars-jstmts(rest, dead-vars))
        | j-for(create-var, init, cont, update, body) =>
          J.j-for(create-var, init, cont, update, elim-dead-vars-jblock(body, dead-vars))
            ^ link(_, elim-dead-vars-jstmts(rest, dead-vars))
      end
  end
end
fun elim-dead-vars-jcase(c :: J.JCase, dead-vars :: NameSet):
  cases(J.JCase) c:
    | j-default(body) => J.j-default(elim-dead-vars-jblock(body, dead-vars))
    | j-case(exp, body) => J.j-case(exp, elim-dead-vars-jblock(body, dead-vars))
  end
end

fun simplify(body-cases :: ConcatList<J.JCase>, step :: A.Name) -> RegisterAllocation:
  # print("Step 1: " + step + " num cases: " + tostring(body-cases.length()))
  dag = (for CL.foldl(acc from D.make-mutable-string-dict(), body-case from body-cases):
      if J.is-j-case(body-case):
        acc.set-now(tostring(body-case.exp.label.get()),
          node(body-case.exp.label, find-steps-to(body-case.body.stmts.reverse(), step), body-case,
            ns-empty, ns-empty, ns-empty, none, none, none, none))
        acc
      else:
        acc
      end
    end).freeze()
  # print("Step 2")
  labels = dag.keys-list()
  # for each(lbl from labels):
  #   n = dag.get-value(lbl)
  #   print(tostring(n._from.get()) + " ==> " + tostring(n._to.to-list().map(_.get())))
  #   print("\n" + n.case-body.to-ugly-source())
  # end
  # print("Step 3")
  for each(lbl from labels):
    n = dag.get-value(lbl)
    n!{decl-vars: declared-vars-jcase(n.case-body)}
    n!{used-vars: used-vars-jcase(n.case-body)}
    n!{free-vars: difference(n!used-vars, n!decl-vars)}
  end
  for each(lbl from labels):
    n = dag.get-value(lbl)
    compute-live-vars(n, dag)
  end
  # for each(lbl from labels):
  #   n = dag.get-value(lbl)
  #   print("Used vars for " + lbl + ": " + torepr(n!used-vars))
  #   print("Decl vars for " + lbl + ": " + torepr(n!decl-vars.to-list()))
  #   print("Free vars for " + lbl + ": " + torepr(n!free-vars))
  #   print("Live-after vars for " + lbl + ": " + torepr(n!live-after-vars.value.to-list()))
  #   print("Live vars for " + lbl + ": " + torepr(n!live-vars.value.to-list()))
  #   print("Dead vars for " + lbl + ": " + torepr(n!dead-vars.value.to-list()))
  #   print("Dead-after vars for " + lbl + ": " + torepr(n!dead-after-vars.value.to-list()))
  #   print("\n")
  # end
  # print("Step 4")
  # live-ranges = D.make-mutable-string-dict()
  # for each(lbl from labels):
  #   n = dag.get-value(lbl)
  #   for each(v from n!live-vars.value.to-list()):
  #     cur = if live-ranges.has-key-now(v.tosourcestring()): live-ranges.get-value-now(v) else: ns-empty end
  #     live-ranges.set-now(v.tosourcestring(), cur.add(lbl))
  #   end
  # end

  discardable-vars = for fold(acc from ns-empty, lbl from labels):
    n = dag.get-value(lbl)
    cases(Option) n!dead-after-vars:
      | none => acc
      | some(dead) => acc.merge(dead)
    end
  end

  dead-assignment-eliminated = for CL.map(body-case from body-cases):
    n = dag.get-value(tostring(body-case.exp.label.get()))
    cases(Option) n!dead-vars:
      | none => body-case
      | some(dead-vars) => elim-dead-vars-jcase(body-case, dead-vars)
    end
  end
  
  # print("Done")
  results(dead-assignment-eliminated, discardable-vars)
end
