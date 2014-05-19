#lang pyret

provide *
import pprint as PP
import format as F

format = F.format

INDENT = 2
break-one = PP.sbreak(1)
blank-one = PP.blank(1)

fun string-printer():
  var str = ""
  {
    append: lam(s): str := str + s end,
    get: lam(): str end
  }
end


data JBlock:
  | j-block(stmts :: List<JStmt>) with:
    print-ugly-source(self, printer):
      when is-link(self.stmts):
        self.stmts.first.print-ugly-source(printer)
        for each(s from self.stmts.rest):
          printer("\n")
          s.print-ugly-source(printer)
        end
      end
    end,
    tosource(self):
      cases(List) self.stmts:
        | empty => PP.mt-doc
        | else => PP.flow-map(PP.hardline, _.tosource(), self.stmts)
      end
    end
sharing:
  to-ugly-source(self):
    strprint = string-printer()
    self.print-ugly-source(strprint.append)
    strprint.get()
  end
end

data JStmt:
  | j-var(name :: String, rhs :: JExpr) with:
    print-ugly-source(self, printer):
      printer("var " + self.name + " = ")
      self.rhs.print-ugly-source(printer)
      printer(";")
    end,
    tosource(self):
      PP.group(
        PP.str("var ") + PP.group(PP.nest(INDENT, PP.str(self.name) +
            PP.str(" =") + PP.sbreak(1) + self.rhs.tosource())) + PP.str(";"))
    end
  | j-if1(cond :: JExpr, consq :: JBlock) with:
    print-ugly-source(self, printer):
      printer("if(")
      self.cond.print-ugly-source(printer)
      printer(") {\n")
      self.consq.print-ugly-source(printer)
      printer("\n}")
    end,
    tosource(self):
      PP.group(PP.str("if") + PP.parens(self.cond.tosource())) + PP.str(" ")
        + PP.surround(INDENT, 1, PP.lbrace, self.consq.tosource(), PP.rbrace)
    end
  | j-if(cond :: JExpr, consq :: JBlock, alt :: JBlock) with:
    print-ugly-source(self, printer):
      printer("if(")
      self.cond.print-ugly-source(printer)
      printer(") {\n")
      self.consq.print-ugly-source(printer)
      printer("\n} else {\n")
      self.alt.print-ugly-source(printer)
      printer("\n}")
    end,
    tosource(self):
      alt-doc = self.alt.tosource()
      else-doc =
        if alt-doc == PP.mt-doc: PP.mt-doc
        else: PP.str(" else ") + PP.surround(INDENT, 1, PP.lbrace, alt-doc, PP.rbrace)
        end
      PP.group(PP.str("if") + PP.parens(self.cond.tosource())) + PP.str(" ")
        + PP.surround(INDENT, 1, PP.lbrace, self.consq.tosource(), PP.rbrace)
        + else-doc
    end
  | j-return(expr :: JExpr) with:
    print-ugly-source(self, printer):
      printer("return ")
      self.expr.print-ugly-source(printer)
      printer(";")
    end,
    tosource(self):
      PP.str("return ") + self.expr.tosource() + PP.str(";")
    end
  | j-try-catch(body :: JStmt, exn :: String, catch :: JBlock) with:
    print-ugly-source(self, printer):
      printer("try {\n")
      self.body.print-ugly-source(printer)
      printer("\n} catch(" + self.exn + ") {\n")
      self.catch.print-ugly-source(printer)
      printer("\n}")
    end,
    tosource(self):
      PP.surround(INDENT, 1, PP.str("try {"), self.body.tosource(), PP.rbrace)
        + PP.surround(INDENT, 1, PP.str(" catch(" + self.exn + ") {"), self.catch.tosource(), PP.rbrace)
    end
  | j-throw(exp :: JExpr) with:
    print-ugly-source(self, printer):
      printer("throw ")
      self.exp.print-ugly-source(printer)
      printer(";")
    end,
    tosource(self):
      PP.group(PP.nest(INDENT, PP.str("throw ") + self.exp.tosource())) + PP.str(";")
    end
  | j-expr(expr :: JExpr) with:
    print-ugly-source(self, printer):
      self.expr.print-ugly-source(printer)
      printer(";")
    end,
    tosource(self):
      self.expr.tosource() + PP.str(";")
    end
  | j-break with:
    print-ugly-source(self, printer): printer("break;\n") end,
    tosource(self): PP.str("break;") end
  | j-continue with:
    print-ugly-source(self, printer): printer("continue;\n") end,
    tosource(self): PP.str("continue;") end
  | j-switch(exp :: JExpr, branches :: List<JCase>) with:
    print-ugly-source(self, printer):
      printer("switch(")
      self.exp.print-ugly-source(printer)
      printer(") {\n")
      self.branches.each(_.print-ugly-source(printer))
      printer("}\n")
    end,
    tosource(self):
      PP.surround(0, 1, PP.group(PP.str("switch") + PP.parens(self.exp.tosource()) + PP.sbreak(1) + PP.lbrace),
        PP.flow-map(PP.hardline, _.tosource(), self.branches), PP.rbrace)
    end
  | j-while(cond :: JExpr, body :: JStmt) with:
    print-ugly-source(self, printer):
      printer("while(")
      self.cond.print-ugly-source(printer)
      printer(") {\n")
      self.body.print-ugly-source(printer)
      printer("}\n")
    end,
    tosource(self):
      PP.surround(INDENT, 1, PP.group(PP.str("while") + PP.parens(self.cond.tosource()) + PP.sbreak(1) + PP.lbrace),
        self.body.tosource(), PP.rbrace)
    end
sharing:
  to-ugly-source(self):
    strprint = string-printer()
    self.print-ugly-source(strprint.append)
    strprint.get()
  end
end

data JCase:
  | j-case(exp :: JExpr, body :: JStmt) with:
    print-ugly-source(self, printer):
      printer("case ")
      self.exp.print-ugly-source(printer)
      printer(": ")
      self.body.print-ugly-source(printer)
    end,
    tosource(self):
      PP.group(PP.nest(INDENT,
          PP.group(PP.nest(INDENT, PP.str("case ") + self.exp.tosource() + PP.str(":"))) + PP.sbreak(1)
            + self.body.tosource()))
    end
  | j-default(body :: JStmt) with:
    print-ugly-source(self, printer):
      printer("default: ")
      self.body.print-ugly-source(printer)
    end,
    tosource(self):
      PP.group(PP.nest(INDENT, PP.str("default:"), self.body.tosource()))
    end
sharing:
  to-ugly-source(self):
    strprint = string-printer()
    self.print-ugly-source(strprint.append)
    strprint.get()
  end
end

data JBinop:
  | j-plus with: to-ugly-source(self): "+" end
  | j-minus with: to-ugly-source(self): "-" end
  | j-times with: to-ugly-source(self): "*" end
  | j-divide with: to-ugly-source(self): "/" end
  | j-and with: to-ugly-source(self): "&&" end
  | j-or with: to-ugly-source(self): "||" end
  | j-lt with: to-ugly-source(self): "<" end
  | j-leq with: to-ugly-source(self): "<=" end
  | j-gt with: to-ugly-source(self): ">" end
  | j-geq with: to-ugly-source(self): ">=" end
  | j-eq with: to-ugly-source(self): "===" end
  | j-equals with: to-ugly-source(self): "==" end
  | j-neq with: to-ugly-source(self): "!==" end
  | j-nequals with: to-ugly-source(self): "!=" end
sharing:
  print-ugly-source(self, printer):
    printer(self.to-ugly-source())
  end,
  tosource(self):
    PP.str(self.to-ugly-source())
  end
end

data JUnop:
  | j-incr with: to-ugly-source(self): "++" end
  | j-decr with: to-ugly-source(self): "--" end
  | j-postincr with: to-ugly-source(self): "++" end
  | j-postdecr with: to-ugly-source(self): "--" end
sharing:
  print-ugly-source(self, printer):
    printer(self.to-ugly-source())
  end,
  tosource(self):
    PP.str(self.to-ugly-source())
  end
end

data JExpr:
  | j-parens(exp :: JExpr) with:
    print-ugly-source(self, printer): 
      printer("(")
      self.exp.print-ugly-source(printer)
      printer(")")
    end,
    tosource(self):
      PP.surround(INDENT, 1, PP.str("("), self.exp.tosource(), PP.str(")"))
    end
  | j-unop(exp :: JExpr, op :: JUnop) with:
    print-ugly-source(self, printer):
      cases(JUnop) self.op:
        | j-postincr =>
          self.exp.print-ugly-source(printer)
          self.op.print-ugly-source(printer)
        | j-postdeccr =>
          self.exp.print-ugly-source(printer)
          self.op.print-ugly-source(printer)
        | else =>
          self.op.print-ugly-source(printer)
          self.exp.print-ugly-source(printer)
      end
    end,
    tosource(self):
      cases(JUnop) self.op:
        | j-postincr => self.exp.tosource() + self.op.tosource()
        | j-postdeccr => self.exp.tosource() + self.op.tosource()
        | else => self.op.tosource() + self.exp.tosource()
      end
    end
  | j-binop(left :: JExpr, op :: JBinop, right :: JExpr) with:
    print-ugly-source(self, printer):
      self.left.print-ugly-source(printer)
      printer(" ")
      self.op.print-ugly-source(printer)
      printer(" ")
      self.right.print-ugly-source(printer)
    end,
    tosource(self): PP.flow([list: self.left.tosource(), self.op.tosource(), self.right.tosource()]) end
  | j-fun(args :: List<String>, body :: JBlock) with:
    print-ugly-source(self, printer):
      printer("function(")
      printer(self.args.join-str(","))
      printer(") {\n")
      self.body.print-ugly-source(printer)
      printer("\n}")
    end,
    tosource(self):
      arglist = PP.nest(INDENT, PP.surround-separate(INDENT, 0, PP.lparen + PP.rparen, PP.lparen, PP.commabreak, PP.rparen, self.args.map(PP.str)))
      header = PP.group(PP.str("function") + arglist)
      PP.surround(INDENT, 1, header + PP.str(" {"), self.body.tosource(), PP.str("}"))
    end
  | j-app(func :: JExpr, args :: List<JExpr>) with:
    print-ugly-source(self, printer):
      self.func.print-ugly-source(printer)
      printer("(")
      when is-link(self.args):
        self.args.first.print-ugly-source(printer)
        for each(a from self.args.rest):
          printer(",")
          a.print-ugly-source(printer)
        end
      end
      printer(")")
    end,
    tosource(self):
      PP.group(self.func.tosource()
          + PP.parens(PP.nest(INDENT,
            PP.separate(PP.commabreak, self.args.map(_.tosource())))))
    end
  | j-method(obj :: JExpr, meth :: String, args :: List<JExpr>) with:
    print-ugly-source(self, printer):
      self.obj.print-ugly-source(printer)
      printer(".")
      printer(self.meth)
      printer("(")
      when is-link(self.args):
        self.args.first.print-ugly-source(printer)
        for each(a from self.args.rest):
          printer(",")
          a.print-ugly-source(printer)
        end
      end
      printer(")")
    end,
    tosource(self):
      PP.group(PP.infix(INDENT, 0, PP.str("."), self.obj.tosource(), PP.str(self.meth))
          + PP.parens(PP.nest(INDENT,
            PP.separate(PP.commabreak, self.args.map(_.tosource())))))
    end
  | j-ternary(test :: JExpr, consq :: JExpr, altern :: JExpr) with:
    print-ugly-source(self, printer):
      self.test.print-ugly-source(printer)
      printer("?")
      self.consq.print-ugly-source(printer)
      printer(":")
      self.altern.print-ugly-source(printer)
    end,
    tosource(self):
      PP.parens(
        self.test.tosource()
          + PP.nest(INDENT, break-one + PP.str("?") + blank-one + PP.group(PP.nest(INDENT, self.consq.tosource())))
          + PP.nest(INDENT, break-one + PP.str(":") + blank-one + PP.group(PP.nest(INDENT, self.altern.tosource()))))
    end
  | j-assign(name :: String, rhs :: JExpr) with:
    print-ugly-source(self, printer):
      printer(self.name)
      printer(" = ")
      self.rhs.print-ugly-source(printer)
    end,
    tosource(self):
      PP.group(PP.nest(INDENT, PP.str(self.name) + PP.str(" =") + break-one + self.rhs.tosource()))
    end
  | j-bracket-assign(obj :: JExpr, field :: JExpr, rhs :: JExpr) with:
    print-ugly-source(self, printer):
      self.obj.print-ugly-source(printer)
      printer("[")
      self.field.print-ugly-source(printer)
      printer("]")
      printer(" = ")
      self.rhs.print-ugly-source(printer)
    end,
    tosource(self):
      PP.group(PP.nest(INDENT, self.obj.tosource() + PP.lbrack + self.field.tosource() + PP.rbrack + PP.str(" =")
            + break-one + self.rhs.tosource()))
    end
  | j-dot-assign(obj :: JExpr, name :: String, rhs :: JExpr) with:
    print-ugly-source(self, printer):
      self.obj.print-ugly-source(printer)
      printer(".")
      printer(self.name)
      printer(" = ")
      self.rhs.print-ugly-source(printer)
    end,
    tosource(self):
      PP.group(PP.nest(INDENT, PP.infix(INDENT, 0, PP.str("."), self.obj.tosource(), PP.str(self.name)) + PP.str(" =") + break-one + self.rhs.tosource()))
    end
  | j-dot(obj :: JExpr, field :: String) with:
    print-ugly-source(self, printer):
      self.obj.print-ugly-source(printer)
      printer(".")
      printer(self.field)
    end,
    tosource(self): PP.infix(INDENT, 0, PP.str("."), self.obj.tosource(), PP.str(self.field)) end
  | j-bracket(obj :: JExpr, field :: JExpr) with:
    print-ugly-source(self, printer):
      self.obj.print-ugly-source(printer)
      printer("[")
      self.field.print-ugly-source(printer)
      printer("]")
    end,
    tosource(self): PP.group(self.obj.tosource() +
      PP.surround(INDENT, 0, PP.lbrack, self.field.tosource(), PP.rbrack))
    end
  | j-list(multi-line :: Boolean, elts :: List<JExpr>) with:
    print-ugly-source(self, printer):
      printer("[")
      when is-link(self.elts):
        self.elts.first.print-ugly-source(printer)
        for each(f from self.elts.rest):
          printer(",")
          when self.multi-line: printer("\n");
          f.print-ugly-source(printer)
        end
      end
      printer("]")
    end,
    tosource(self):
      PP.surround-separate(INDENT, 1, PP.lbrack + PP.rbrack,
        PP.lbrack, PP.commabreak, PP.rbrack, self.elts.map(_.tosource()))
    end
  | j-obj(fields :: List<JField>) with:
    print-ugly-source(self, printer):
      printer("{")
      when is-link(self.fields):
        self.fields.first.print-ugly-source(printer)
        for each(f from self.fields.rest):
          printer(",\n")
          f.print-ugly-source(printer)
        end
      end
      printer("}")
    end,
    tosource(self):
      PP.surround-separate(INDENT, 1, PP.lbrace + PP.rbrace,
        PP.lbrace, PP.commabreak, PP.rbrace, self.fields.map(_.tosource()))
    end
  | j-id(id :: String) with:
    print-ugly-source(self, printer):
      printer(self.id)
    end,
    tosource(self): PP.str(self.id) end
  | j-str(s :: String) with:
    print-ugly-source(self, printer):
      printer(torepr(self.s))
    end,
    tosource(self): PP.str(torepr(self.s)) end
  | j-num(n :: Number) with:
    print-ugly-source(self, printer):
      printer(tostring(self.n))
    end,
    tosource(self): PP.number(self.n) end
  | j-true with:
    print-ugly-source(self, printer):
      printer("true")
    end,
    tosource(self): PP.str("true") end
  | j-false with:
    print-ugly-source(self, printer):
      printer("false")
    end,
    tosource(self): PP.str("false") end
  | j-null with:
    print-ugly-source(self, printer):
      printer("null")
    end,
    tosource(self): PP.str("null") end
  | j-undefined with:
    print-ugly-source(self, printer):
      printer("undefined")
    end,
    tosource(self): PP.str("undefined") end
  | j-raw(raw-js :: String) with:
    print-ugly-source(self, printer):
      printer(self.raw-js)
    end,
    tosource(self): PP.str(self.raw-js) end
  | j-raw-holes(raw-js :: String, fills :: List<JExpr>, width-tolerance) with:
    print-ugly-source(self, printer):
      raise("Cannot print with raw holes, not fancy enough")
    end,
    tosource(self):
      filldocs = self.fills.map(_.tosource())
      fillstrs = filldocs.map(_.pretty(self.width-tolerance)).map(_.join-str(" "))
      PP.str(format(self.raw-js, fillstrs))
    end
  | j-label(label :: JLabel) with:
    print-ugly-source(self, printer): printer(tostring(self.label.get())) end,
    tosource(self): PP.number(self.label.get()) end
sharing:
  to-ugly-source(self):
    strprint = string-printer()
    self.print-ugly-source(strprint.append)
    strprint.get()
  end

where:
  j-fun([list: "a","b"], j-block([list: j-app(j-id("a"), [list: j-id("b")])])).tosource().pretty(80) is
    [list: "function(a, b) { a(b) }"]

  j-fun([list: "RUNTIME", "NAMESPACE"], j-block([list: 
      j-var("print", j-method(j-id("NAMESPACE"), "get", [list: j-str("print")])),
      j-var("brand", j-method(j-id("NAMESPACE"), "get", [list: j-str("brand")]))
    ])).tosource().pretty(80)
    is
    [list: 
      "function(RUNTIME, NAMESPACE) {",
      "  var print = NAMESPACE.get(\"print\");",
      "  var brand = NAMESPACE.get(\"brand\");",
      "}"
    ]

  j-null.tosource().pretty(5) is [list: "null"]

  # temporary, until we implement (or replace) raises
  # j-null.tosource().pretty(3) raises "String doesn't fit"

  j-raw-holes("try { ~a } catch(e) { ~a }",
    [list: j-raw("x + y"), j-id("z")], 100000).tosource().pretty(80) is
    [list: "try { x + y } catch(e) { z }"]

  j-if(j-true, j-block([list: j-return(j-false)]), j-block([list: j-return(j-num(5))]))
    .tosource().pretty(80) is
    [list: "if(true) { return false; } else { return 5; }"]

  j-bracket(j-true, j-false).tosource().pretty(20) is [list: "true[false]"]

end

fun make-label-sequence(init):
  var next = init
  lam():
    var value = nothing
    j-label({
        get: lam():
            if value == nothing:
              value := next
              next := next + 1
              value
            else:
              value
            end
        end})
  end
end

data JField:
  | j-field(name :: String, value :: JExpr) with:
    print-ugly-source(self, printer):
      printer("\"")
      printer(self.name)
      printer("\":")
      self.value.print-ugly-source(printer)
    end,
    tosource(self):
      PP.nest(INDENT, PP.dquote(PP.str(self.name)) + PP.str(": ") + self.value.tosource())
    end
sharing:
  to-ugly-source(self):
    strprint = string-printer()
    self.print-ugly-source(strprint.append)
    strprint.get()
  end
end
