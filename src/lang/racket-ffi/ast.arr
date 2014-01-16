#lang pyret

provide *
import pprint as PP

Loc = error.Location
loc = error.location

dummy-loc = loc("dummy location", -1, -1)

INDENT = 2

break-one = PP.break(1)
str-any = PP.str("Any")
str-arrow = PP.str("->")
str-arrowspace = PP.str("-> ")
str-as = PP.str("as")
str-blank = PP.str("")
str-let = PP.str("let")
str-letrec = PP.str("letrec")
str-block = PP.str("block:")
str-brackets = PP.str("[]")
str-cases = PP.str("cases")
str-check = PP.str("check:")
str-colon = PP.str(":")
str-coloncolon = PP.str("::")
str-colonspace = PP.str(": ")
str-comment = PP.str("# ")
str-constructor = PP.str("with constructor")
str-data = PP.str("data ")
str-datatype = PP.str("datatype ")
str-deriving = PP.str("deriving ")
str-doc = PP.str("doc: ")
str-elsebranch = PP.str("| else =>")
str-elsecolon = PP.str("else:")
str-elsespace = PP.str("else ")
str-end = PP.str("end")
str-except = PP.str("except")
str-for = PP.str("for ")
str-from = PP.str("from")
str-fun = PP.str("fun")
str-if = PP.str("if ")
str-import = PP.str("import")
str-method = PP.str("method")
str-mutable = PP.str("mutable")
str-not = PP.str("not")
str-period = PP.str(".")
str-bang = PP.str("!")
str-pipespace = PP.str("| ")
str-provide = PP.str("provide")
str-provide-star = PP.str("provide *")
str-sharing = PP.str("sharing:")
str-space = PP.str(" ")
str-spacecolonequal = PP.str(" :=")
str-spaceequal = PP.str(" =")
str-thickarrow = PP.str("=>")
str-try = PP.str("try:")
str-use-loc = PP.str("UseLoc")
str-var = PP.str("var ")
str-when = PP.str("when")
str-where = PP.str("where:")
str-with = PP.str("with:")


fun funlam_tosource(funtype, name, params, args :: List<is-s_bind>,
    ann :: Ann, doc :: String, body :: Expr, _check :: Expr) -> PP.PPrintDoc:
  typarams =
    if is-nothing(params): PP.mt-doc
    else: PP.surround-separate(INDENT, 0, PP.mt-doc, PP.langle, PP.commabreak, PP.rangle,
        params.map(PP.str))
    end
  arg-list = PP.nest(INDENT,
    PP.surround-separate(INDENT, 0, PP.lparen + PP.rparen, PP.lparen, PP.commabreak, PP.rparen,
      args.map(fun(a): a.tosource() end)))
  ftype = funtype + typarams
  fname =
    if is-nothing(name): ftype
    else if PP.is-mt-doc(ftype): PP.str(name)
    else: ftype + PP.str(" " + name)
    end
  fann =
    if is-a_blank(ann) or is-nothing(ann): PP.mt-doc
    else: break-one + str-arrowspace + ann.tosource()
    end
  header = PP.group(fname + arg-list + fann + str-colon)
  checker = _check.tosource()
  footer =
    if PP.is-mt-doc(checker): str-end
    else: PP.surround(INDENT, 1, str-where, _check.tosource(), str-end)
    end
  docstr =
    if is-nothing(doc) or (doc == ""): PP.mt-doc
    else: str-doc + PP.dquote(PP.str(doc)) + PP.hardline
    end
  PP.surround(INDENT, 1, header, docstr + body.tosource(), footer)
end

data Program:
  | s_program(l :: Loc, imports :: List<Header>, block :: Expr) with:
    label(self): "s_program" end,
    tosource(self):
      PP.group(
        PP.flow_map(PP.hardline, fun(i): i.tosource() end, self.imports)
          + PP.hardline
          + self.block.tosource()
        )
    end
end

data Header:
  | s_import(l :: Loc, file :: ImportType, name :: String) with:
    label(self): "s_import" end,
    tosource(self):
      PP.flow([str-import, self.file.tosource(), str-as, PP.str(self.name)])
    end
  | s_provide(l :: Loc, block :: Expr) with:
    label(self): "s_provide" end,
    tosource(self):
      PP.soft-surround(INDENT, 1, str-provide,
        self.block.tosource(), str-end)
    end
  | s_provide_all(l :: Loc) with:
    label(self): "s_provide_all" end,
    tosource(self): str-provide-star end
end

data ImportType:
  | s_file_import(file :: String) with:
    label(self): "s_file_import" end,
    tosource(self): PP.dquote(PP.str(self.file)) end
  | s_const_import(module :: String) with:
    label(self): "s_const_import" end,
    tosource(self): PP.str(self.module) end
end

data Hint:
  | h_use_loc(l :: Loc) with:
    tosource(self): str-use-loc + PP.parens(PP.str(self.l.tostring())) end
end

data LetBind:
  | s_let_bind(l :: Loc, b :: Bind, value :: Expr) with:
    tosource(self):
      PP.group(PP.nest(INDENT, self.b.tosource() + str-spaceequal + break-one + self.value.tosource()))
    end
  | s_var_bind(l :: Loc, b :: Bind, value :: Expr) with:
    tosource(self):
      PP.group(PP.nest(INDENT, PP.str("var ") + self.b.tosource() + str-spaceequal + break-one + self.value.tosource()))
    end
end

data LetrecBind:
  | s_letrec_bind(l :: Loc, b :: Bind, value :: Expr) with:
    tosource(self):
      PP.group(PP.nest(INDENT, self.b.tosource() + str-spaceequal + break-one + self.value.tosource()))
    end
end

data Expr:
  | s_let_expr(l :: Loc, binds :: List<LetBind>, body :: Expr) with:
    label(self): "s_let" end,
    tosource(self):
      PP.soft-surround(INDENT, 1,
        str-let + break-one + PP.flow_map(PP.comma + PP.hardline, _.tosource(), self.binds) + str-colon,
        self.body.tosource(),
        str-end)
    end
  | s_letrec(l :: Loc, binds :: List<LetrecBind>, body :: Expr) with:
    label(self): "s_letrec" end,
    tosource(self):
      PP.soft-surround(INDENT, 1,
        str-letrec + break-one + PP.flow_map(PP.comma + PP.hardline, _.tosource(), self.binds) + str-colon,
        self.body.tosource(),
        str-end)
    end
  | s_hint_exp(l :: Loc, hints :: List<Hint>, exp :: Expr) with:
    label(self): "s_hint_exp" end,
    tosource(self):
      PP.flow_map(PP.hardline, fun(h): str-comment + h.tosource() end, self.hints) + PP.hardline
        + self.e.tosource()
    end
  | s_instantiate(l :: Loc, expr :: Expr, params :: List<Ann>) with:
    label(self): "s_instantiate" end,
    tosource(self):
      PP.group(self.expr.tosource() +
        PP.surround-separate(INDENT, 0, PP.mt-doc, PP.langle, PP.commabreak, PP.rangle,
            self.params.map(_.tosource)))
    end
  | s_block(l :: Loc, stmts :: List<Expr>) with:
    label(self): "s_block" end,
    tosource(self):
      PP.flow_map(PP.hardline, _.tosource(), self.stmts) end
  | s_user_block(l :: Loc, body :: Expr) with:
    label(self): "s_user_block" end,
    tosource(self):
      PP.surround(INDENT, 1, str-block, self.body.tosource(), str-end)
    end
  | s_fun(
      l :: Loc,
      name :: String,
      params :: List<String>, # Type parameters
      args :: List<Bind>, # Value parameters
      ann :: Ann, # return type
      doc :: String,
      body :: Expr,
      check :: Expr
    ) with:
      label(self): "s_fun" end,
    tosource(self):
      funlam_tosource(str-fun,
        self.name, self.params, self.args, self.ann, self.doc, self.body, self.check)
    end
  | s_var(l :: Loc, name :: Bind, value :: Expr) with:
    label(self): "s_var" end,
    tosource(self):
      str-var
        + PP.group(PP.nest(INDENT, self.name.tosource()
            + str-spaceequal + break-one + self.value.tosource()))
    end
  | s_let(l :: Loc, name :: Bind, value :: Expr) with:
    label(self): "s_let" end,
    tosource(self):
      PP.group(PP.nest(INDENT, self.name.tosource() + str-spaceequal + break-one + self.value.tosource()))
    end
  | s_graph(l :: Loc, bindings :: List<is-s_let>) with:
    label(self): "s_graph" end,
  | s_when(l :: Loc, test :: Expr, block :: Expr) with:
    label(self): "s_when" end,
    tosource(self):
      PP.soft-surround(INDENT, 1,
        str-when + PP.parens(self.test.tosource()) + str-colon,
        self.block.tosource(),
        str-end)
    end
  | s_assign(l :: Loc, id :: String, value :: Expr) with:
    label(self): "s_assign" end,
    tosource(self):
      PP.group(PP.nest(INDENT, PP.str(self.id) + str-spacecolonequal + break-one + self.value.tosource()))
    end
  | s_if(l :: Loc, branches :: List<IfBranch>) with:
    label(self): "s_if" end,
    tosource(self):
      branches = PP.separate(break-one + str-elsespace,
        self.branches.map(fun(b): b.tosource() end))
      PP.group(branches + break-one + str-end)
    end
  | s_if_else(l :: Loc, branches :: List<IfBranch>, _else :: Expr) with:
    label(self): "s_if_else" end,
    tosource(self):
      branches = PP.separate(break-one + str-elsespace,
        self.branches.map(fun(b): b.tosource() end))
      _else = str-elsecolon + PP.nest(INDENT, break-one + self._else.tosource())
      PP.group(branches + break-one + _else + break-one + str-end)
    end
  | s_cases(l :: Loc, type :: Ann, val :: Expr, branches :: List<CasesBranch>) with:
    label(self): "s_cases" end,
    tosource(self):
      header = str-cases + PP.parens(self.type.tosource()) + break-one
        + self.val.tosource() + str-colon
      PP.surround-separate(INDENT, 1, header + str-space + str-end,
        PP.group(header), break-one, str-end,
        self.branches.map(fun(b): PP.group(b.tosource()) end))
    end
  | s_cases_else(l :: Loc, type :: Ann, val :: Expr, branches :: List<CasesBranch>, _else :: Expr) with:
    label(self): "s_cases_else" end,
    tosource(self):
      header = str-cases + PP.parens(self.type.tosource()) + break-one
        + self.val.tosource() + str-colon
      body = PP.separate(break-one, self.branches.map(fun(b): PP.group(b.tosource()) end))
        + break-one + PP.group(str-elsebranch + break-one + self._else.tosource())
      PP.surround(INDENT, 1, PP.group(header), body, str-end)
    end
  | s_try(l :: Loc, body :: Expr, id :: Bind, _except :: Expr) with:
    label(self): "s_try" end,
    tosource(self):
      _try = str-try + break-one
        + PP.nest(INDENT, self.body.tosource()) + break-one
      _except = str-except + PP.parens(self.id.tosource()) + str-colon + break-one
        + PP.nest(INDENT, self._except.tosource()) + break-one
      PP.group(_try + _except + str-end)
    end
  | s_op(l :: Loc, op :: String, left :: Expr, right :: Expr) with:
    label(self): "s_op" end,
    tosource(self): PP.infix(INDENT, 1, PP.str(self.op.substring(2, self.op.length())), self.left.tosource(), self.right.tosource()) end
  | s_check_test(l :: Loc, op :: String, left :: Expr, right :: Expr) with:
    tosource(self): PP.infix(INDENT, 1, PP.str(self.op.substring(2, self.op.length())), self.left.tosource(), self.right.tosource()) end
  | s_not(l :: Loc, expr :: Expr) with:
    label(self): "s_not" end,
    tosource(self): PP.nest(INDENT, PP.flow([str-not, self.expr.tosource()])) end
  | s_paren(l :: Loc, expr :: Expr) with:
    label(self): "s_paren" end,
    tosource(self): PP.parens(self.expr.tosource()) end
  | s_lam(
      l :: Loc,
      params :: List<String>, # Type parameters
      args :: List<Bind>, # Value parameters
      ann :: Ann, # return type
      doc :: String,
      body :: Expr,
      check :: Expr
    ) with:
    label(self): "s_lam" end,
    tosource(self):
      funlam_tosource(str-fun,
        nothing, self.params, self.args, self.ann, self.doc, self.body, self.check)
    end
  | s_method(
      l :: Loc,
      args :: List<Bind>, # Value parameters
      ann :: Ann, # return type
      doc :: String,
      body :: Expr,
      check :: Expr
    ) with:
    label(self): "s_method" end,
    tosource(self):
      funlam_tosource(str-method,
        nothing, nothing, self.args, self.ann, self.doc, self.body, self.check)
    end
  | s_extend(l :: Loc, super :: Expr, fields :: List<Member>) with:
    label(self): "s_extend" end,
    tosource(self):
      PP.group(self.super.tosource() + str-period
          + PP.surround-separate(INDENT, 1, PP.lbrace + PP.rbrace,
          PP.lbrace, PP.commabreak, PP.rbrace, self.fields.map(_.tosource())))
    end
  | s_update(l :: Loc, super :: Expr, fields :: List<Member>) with:
    label(self): "s_update" end,
  | s_obj(l :: Loc, fields :: List<Member>) with:
    label(self): "s_obj" end,
    tosource(self):
      PP.surround-separate(INDENT, 1, PP.lbrace + PP.rbrace,
        PP.lbrace, PP.commabreak, PP.rbrace, self.fields.map(_.tosource()))
    end
  | s_list(l :: Loc, values :: List<Expr>) with:
    label(self): "s_list" end,
    tosource(self):
      PP.surround-separate(INDENT, 0, str-brackets, PP.lbrack, PP.commabreak, PP.rbrack,
        self.values.map(fun(v): v.tosource() end))
    end
  | s_app(l :: Loc, _fun :: Expr, args :: List<Expr>) with:
    label(self): "s_app" end,
    tosource(self):
      PP.group(self._fun.tosource()
          + PP.parens(PP.nest(INDENT,
            PP.separate(PP.commabreak, self.args.map(_.tosource())))))
    end
  | s_left_app(l :: Loc, obj :: Expr, _fun :: Expr, args :: List<Expr>) with:
    label(self): "s_left_app" end,
    tosource(self):
      PP.group(self.obj.tosource() + PP.nest(INDENT, PP.break(0) + str-period + self._fun.tosource())
          + PP.parens(PP.separate(PP.commabreak, self.args.map(_.tosource()))))
    end
  | s_id(l :: Loc, id :: String) with:
    label(self): "s_id" end,
    tosource(self): PP.str(self.id) end
  | s_id_var(l :: Loc, id :: String) with:
    label(self): "s_id_var" end,
    tosource(self): PP.str("!" + self.id) end
  | s_id_letrec(l :: Loc, id :: String) with:
    label(self): "s_id_letrec" end,
    tosource(self): PP.str("~" + self.id) end
  | s_undefined(l :: Loc) with:
    label(self): "s_undefined" end,
    tosource(self): PP.str("undefined") end
  | s_num(l :: Loc, n :: Number) with:
    label(self): "s_num" end,
    tosource(self): PP.number(self.n) end
  | s_bool(l :: Loc, b :: Bool) with:
    label(self): "s_bool" end,
    tosource(self): PP.str(self.b.tostring()) end
  | s_str(l :: Loc, s :: String) with:
    label(self): "s_str" end,
    tosource(self): PP.squote(PP.str(self.s)) end
  | s_dot(l :: Loc, obj :: Expr, field :: String) with:
    label(self): "s_dot" end,
    tosource(self): PP.infix(INDENT, 0, str-period, self.obj.tosource(), PP.str(self.field)) end
  | s_get_bang(l :: Loc, obj :: Expr, field :: String) with:
    label(self): "s_get_bang" end,
    tosource(self): PP.infix(INDENT, 0, str-bang, self.obj.tosource(), PP.str(self.field)) end
  | s_bracket(l :: Loc, obj :: Expr, field :: Expr) with:
    label(self): "s_bracket" end,
    tosource(self): PP.infix(INDENT, 0, str-period, self.obj.tosource(),
        PP.surround(INDENT, 0, PP.lbrack, self.field.tosource(), PP.rbrack))
    end
  | s_colon(l :: Loc, obj :: Expr, field :: String) with:
    label(self): "s_colon" end,
    tosource(self): PP.infix(INDENT, 0, str-colon, self.obj.tosource(), PP.str(self.field)) end
  | s_colon_bracket(l :: Loc, obj :: Expr, field :: Expr) with:
    label(self): "s_colon_bracket" end,
    tosource(self): PP.infix(INDENT, 0, str-colon, self.obj.tosource(),
        PP.surround(INDENT, 0, PP.lbrack, self.field.tosource(), PP.rbrack))
    end
  | s_data(
      l :: Loc,
      name :: String,
      params :: List<String>, # type params
      mixins :: List<Expr>,
      variants :: List<Variant>,
      shared_members :: List<Member>,
      check :: Expr
    ) with:
      label(self): "s_data" end,
    tosource(self):
      fun optional_section(lbl, section):
        if PP.is-mt-doc(section): PP.mt-doc
        else: break-one + PP.group(PP.nest(INDENT, lbl + break-one + section))
        end
      end
      tys = PP.surround-separate(2 * INDENT, 0, PP.mt-doc, PP.langle, PP.commabreak, PP.rangle,
        self.params.map(_.tosource()))
      header = str-data + PP.str(self.name) + tys + str-colon
      _deriving =
        PP.surround-separate(INDENT, 0, PP.mt-doc, break-one + str-deriving, PP.commabreak, PP.mt-doc, self.mixins.map(fun(m): m.tosource() end))
      variants = PP.separate(break-one + str-pipespace,
        str-blank^list.link(self.variants.map(fun(v): PP.nest(INDENT, v.tosource()) end)))
      shared = optional_section(str-sharing,
        PP.separate(PP.commabreak, self.shared_members.map(fun(s): s.tosource() end)))
      _check = optional_section(str-where, self.check.tosource())
      footer = break-one + str-end
      header + _deriving + PP.group(PP.nest(INDENT, variants) + shared + _check + footer)
    end
  | s_datatype(
      l :: Loc,
      name :: String,
      params :: List<String>, # type params
      variants :: List<Variant>,
      check :: Expr
    ) with:
      label(self): "s_datatype" end,
    tosource(self):
      fun optional_section(lbl, section):
        if PP.is-empty(section): PP.empty
        else: break-one + PP.group(PP.nest(INDENT, lbl + break-one + section))
        end
      end
      tys = PP.surround-separate(2 * INDENT, 0, PP.empty, PP.langle, PP.commabreak, PP.rangle,
        self.params.map(_.tosource()))
      header = str-data + PP.str(self.name) + tys + str-colon
      variants = PP.separate(break-one + str-pipespace,
        str-blank^list.link(self.variants.map(fun(v): PP.nest(INDENT, v.tosource()) end)))
      _check = optional_section(str-where, self.check.tosource())
      footer = break-one + str-end
      header + PP.group(PP.nest(INDENT, variants) + _check + footer)
    end
  | s_for(
      l :: Loc,
      iterator :: Expr,
      bindings :: List<ForBind>,
      ann :: Ann,
      body :: Expr
    ) with:
      label(self): "s_for" end,
    tosource(self):
      header = PP.group(str-for
          + self.iterator.tosource()
          + PP.surround-separate(2 * INDENT, 0, PP.lparen + PP.rparen, PP.lparen, PP.commabreak, PP.rparen,
          self.bindings.map(fun(b): b.tosource() end))
          + PP.group(PP.nest(2 * INDENT,
            break-one + str-arrow + break-one + self.ann.tosource() + str-colon)))
      PP.surround(INDENT, 1, header, self.body.tosource(), str-end)
    end
  | s_check(
      l :: Loc,
      body :: Expr
    ) with:
      label(self): "s_check" end,
    tosource(self):
      PP.surround(INDENT, 1, str-check, self.body.tosource(), str-end)
    end
  | s_update_k(l :: Loc, conts :: Expr, super :: Expr, fields :: List<Member>) with: #Special ast for cpsing, allows you to get the continuations to pass to set
    label(self): "s_update" end,

  | s_app_k(l :: Loc, conts :: Expr, _fun :: Expr, args :: List<Expr>) with:
    label(self): "s_app" end,
    tosource(self):
      PP.group(self._fun.tosource()
          + PP.parens(PP.nest(INDENT,
            PP.separate(PP.commabreak, self.args.map(_.tosource())))))
    end

  | s_bracket_k(l :: Loc, conts :: Expr, obj :: Expr, field :: Expr) with:
    label(self): "s_bracket" end,
    tosource(self): PP.infix(INDENT, 0, str-period, self.obj.tosource(),
        PP.surround(INDENT, 0, PP.lbrack, self.field.tosource(), PP.rbrack))
    end

  | s_colon_bracket_k(l :: Loc, conts :: Expr, obj :: Expr, field :: Expr) with:
    label(self): "s_colon_bracket" end,
    tosource(self): PP.infix(INDENT, 0, str-colon, self.obj.tosource(),
        PP.surround(PP.lbrack, self.field.tosource(), PP.rbrack))
    end
  | s_block_k(l :: Loc, conts :: Expr, stmts :: List<Expr>, bindings :: List<Expr>) with:
    label(self): "s_block" end,
    tosource(self):
      PP.flow_map(PP.hardline, _.tosource(), self.stmts) end
end

data Bind:
  | s_bind(l :: Loc, shadows :: Bool, id :: String, ann :: Ann) with:
    tosource(self):
      if is-a_blank(self.ann):
        if self.shadows: PP.str("shadow " + self.id)
        else: PP.str(self.id)
        end
      else:
        if self.shadows: PP.infix(INDENT, 1, str-coloncolon, PP.str("shadow " + self.id), self.ann.tosource())
        else: PP.infix(INDENT, 1, str-coloncolon, PP.str(self.id), self.ann.tosource())
        end
      end
    end
end

data Member:
  | s_data_field(l :: Loc, name :: Expr, value :: Expr) with:
    label(self): "s_data_field" end,
    tosource(self): PP.nest(INDENT, self.name.tosource() + str-colonspace + self.value.tosource()) end,
  | s_mutable_field(l :: Loc, name :: Expr, ann :: Ann, value :: Expr) with:
    label(self): "s_mutable_field" end,
    tosource(self): PP.nest(INDENT, str-mutable + self.name.tosource() + str-coloncolon + self.ann.tosource() + str-colonspace + self.value.tosource()) end,
  | s_once_field(l :: Loc, name :: Expr, ann :: Ann, value :: Expr) with:
    label(self): "s_once_field" end
  | s_method_field(
      l :: Loc,
      name :: Expr,
      args :: List<Bind>, # Value parameters
      ann :: Ann, # return type
      doc :: String,
      body :: Expr,
      check :: Expr
    ) with:
      label(self): "s_method_field" end,
    tosource(self):
      name-part = cases(Expr) self.name:
        | s_str(l, s) => PP.str(s)
        | else => self.name.tosource()
      end
      funlam_tosource(name-part,
        nothing, nothing, self.args, self.ann, self.doc, self.body, self.check)
    end
end

data ForBind:
  | s_for_bind(l :: Loc, bind :: Bind, value :: Expr) with:
    label(self): "s_for_bind" end,
    tosource(self):
      PP.group(self.bind.tosource() + break-one + str-from + break-one + self.value.tosource())
    end
end

data VariantMember:
  | s_variant_member(l :: Loc, member_type :: String, bind :: Bind) with:
    label(self): "s_variant_member" end,
    tosource(self):
      if self.member_type <> "normal":
        PP.str(self.member_type) + str-space + self.bind.tosource()
      else:
        self.bind.tosource()
      end
    end
end

data Variant:
  | s_variant(
      l :: Loc,
      name :: String,
      members :: List<VariantMember>,
      with_members :: List<Member>
    ) with:
    label(self): "s_variant" end,
    tosource(self):
      header-nowith =
        PP.str(self.name)
        + PP.surround-separate(INDENT, 0, PP.mt-doc, PP.lparen, PP.commabreak, PP.rparen,
        self.members.map(fun(b): b.tosource() end))
      header = PP.group(header-nowith + break-one + str-with)
      withs = self.with_members.map(fun(m): m.tosource() end)
      if list.is-empty(withs): header-nowith
      else: header + PP.group(PP.nest(INDENT, break-one + PP.separate(PP.commabreak, withs)))
      end
    end
  | s_singleton_variant(
      l :: Loc,
      name :: String,
      with_members :: List<Member>
    ) with:
    label(self): "s_singleton_variant" end,
    tosource(self):
      header-nowith = PP.str(self.name)
      header = PP.group(header-nowith + break-one + str-with)
      withs = self.with_members.map(fun(m): m.tosource() end)
      if list.is-empty(withs): header-nowith
      else: header + PP.group(PP.nest(INDENT, break-one + PP.separate(PP.commabreak, withs)))
      end
    end
end

data DatatypeVariant:
  | s_datatype_variant(
      l :: Loc,
      name :: String,
      members :: List<VariantMember>,
      constructor :: Constructor
    ) with:
    label(self): "s_datatype_variant" end,
    tosource(self):
      PP.str("FIXME 10/24/2013: dbp doesn't understand this pp stuff")
    end
  | s_datatype_singleton_variant(
      l :: Loc,
      name :: String,
      constructor :: Constructor
    ) with:
    label(self): "s_datatype_singleton_variant" end,
    tosource(self):
      PP.str("FIXME 10/24/2013: dbp doesn't understand this pp stuff")
    end
end

data Constructor:
  | s_datatype_constructor(
      l :: Loc,
      self :: String,
      body :: Expr
      ) with:
    label(self): "s_datatype_constructor" end,
    tosource(self):
      PP.str("FIXME 10/24/2013: dbp doesn't understand this pp stuff")
    end
end

data IfBranch:
  | s_if_branch(l :: Loc, test :: Expr, body :: Expr) with:
    label(self): "s_if_branch" end,
    tosource(self):
      str-if
        + PP.nest(2 * INDENT, self.test.tosource() + str-colon)
        + PP.nest(INDENT, break-one + self.body.tosource())
    end
end

data CasesBranch:
  | s_cases_branch(l :: Loc, name :: String, args :: List<Bind>, body :: Expr) with:
    label(self): "s_cases_branch" end,
    tosource(self):
      PP.nest(INDENT,
        PP.group(PP.str("| " + self.name)
            + PP.surround-separate(INDENT, 0, PP.mt-doc, PP.lparen, PP.commabreak, PP.rparen,
            self.args.map(fun(a): a.tosource() end)) + break-one + str-thickarrow) + break-one +
        self.body.tosource())
    end
end

data Ann:
  | a_blank with:
    label(self): "a_blank" end,
    tosource(self): str-any end
  | a_any with:
    label(self): "a_any" end,
    tosource(self): str-any end
  | a_name(l :: Loc, id :: String) with:
    label(self): "a_name" end,
    tosource(self): PP.str(self.id) end
  | a_arrow(l :: Loc, args :: List<Ann>, ret :: Ann) with:
    label(self): "a_arrow" end,
    tosource(self):
      PP.surround(INDENT, 1, PP.lparen,
        PP.separate(str-space,
          [PP.separate(PP.commabreak,
            self.args.map(_.tosource()))] + [str-arrow, self.ret.tosource()]), PP.rparen)
    end
  | a_method(l :: Loc, args :: List<Ann>, ret :: Ann) with:
    label(self): "a_method" end,
    tosource(self): PP.str("NYI: A_method") end
  | a_record(l :: Loc, fields :: List<AField>) with:
    label(self): "a_record" end,
    tosource(self):
      PP.surround-separate(INDENT, 1, PP.lbrace + PP.rbrace, PP.lbrace, PP.commabreak, PP.rbrace,
        self.fields.map(_.tosource()))
    end
  | a_app(l :: Loc, ann :: Ann, args :: List<Ann>) with:
    label(self): "a_app" end,
    tosource(self):
      PP.group(self.ann.tosource()
          + PP.group(PP.langle + PP.nest(INDENT,
            PP.separate(PP.commabreak, self.args.map(_.tosource()))) + PP.rangle))
    end
  | a_pred(l :: Loc, ann :: Ann, exp :: Expr) with:
    label(self): "a_pred" end,
    tosource(self): self.ann.tosource() + PP.parens(self.exp.tosource()) end
  | a_dot(l :: Loc, obj :: String, field :: String) with:
    label(self): "a_dot" end,
    tosource(self): PP.str(self.obj + "." + self.field) end
end

data AField:
  | a_field(l :: Loc, name :: String, ann :: Ann) with:
    label(self): "a_field" end,
    tosource(self):
      if is-a_blank(self.ann): PP.str(self.name)
      else: PP.infix(INDENT, 1, str-coloncolon, PP.str(self.name), self.ann.tosource())
      end
    end
end

fun make-checker-name(name): "is-" + name;

fun flatten(list-of-lists :: List):
  for fold(biglist from [], piece from list-of-lists):
    biglist + piece
  end
end

fun binding-ids(stmt):
  fun variant-ids(variant):
    cases(Variant) variant:
      | s_variant(_, name, _, _) => [name, make-checker-name(name)]
      | s_singleton-variant(_, name, _, _) => [name, make-checker-name(name)]
    end
  end
  cases(Expr) stmt:
    | s_let(_, b, _) => [b.id]
    | s_var(_, b, _) => [b.id]
    | s_graph(_, bindings) => flatten(bindings.map(binding-ids))
    | s_data(_, name, _, _, variants, _, _) =>
      name ^ link(flatten(variants.map(variant-ids)))
    | else => []
  end
end

fun block-ids(b :: is-s_block):
  cases(Expr) b:
    | s_block(_, stmts) => flatten(stmts.map(binding-ids))
    | else => raise("Non-block given to block-ids")
  end
end

fun toplevel-ids(program :: Program):
  cases(Program) program:
    | s_program(_, _, b) => block-ids(b)
    | else => raise("Non-program given to toplevel-ids")
  end
end

data Pair:
  | pair(l, r)
end

fun length-andmap(pred, l1, l2):
  (l1.length() == l2.length()) and
    for list.all(p from map2(pair, l1, l2)): pred(p.l, p.r);
end

# Equivalence modulo srclocs
fun equiv-ast-prog(ast1 :: Program, ast2 :: Program):
  cases(Program) ast1:
    | s_program(_, imports1, body1) =>
      cases(Program) ast2:
        | s_program(_, imports2, body2) =>
          length-andmap(equiv-ast-header, imports1, imports2) and
            equiv-ast(body1, body2)
        | else => false
      end
  end
end

fun equiv-ast-member(m1 :: Member, m2 :: Member):
  cases(Member) m1:
    | s_data_field(_, n1, v1) =>
      cases(Member) m2:
        | s_data_field(_, n2, v2) => equiv-ast(n1, n2) and equiv-ast(v1, v2)
        | else => false
      end
    | s_method_field(_, n1, args1, ann1, doc1, body1, check1) =>
      cases(Member) m2:
        | s_method_field(_, n2, args2, ann2, doc2, body2, check2) =>
          (n1 == n2) and
            length-andmap(equiv-ast-bind, args1, args2) and
            equiv-ast-ann(ann1, ann2) and
            (doc1 == doc2) and
            equiv-ast(body1, body2) and
            equiv-ast(check1, check2)
        | else => false
      end
    | else => false
  end
end

fun equiv-ast-bind(b1 :: Bind, b2 :: Bind):
  cases(Bind) b1:
    | s_bind(_, shadow1, id1, ann1) =>
      cases(Bind) b2:
        | s_bind(_, shadow2, id2, ann2) =>
          (shadow1 == shadow2) and
            (id1 == id2) and
            equiv-ast-ann(ann1, ann2)
      end
  end
end

fun equiv-ast-for-binding(b1 :: ForBind, b2 :: ForBind):
  cases(ForBind) b1:
    | s_for_bind(_, bind1, value1) =>
      cases(ForBind) b2:
        | s_for_bind(_, bind2, value2) =>
            equiv-ast-bind(bind1, bind2) and equiv-ast(value1, value2)      
        | else => false
      end
  end
end

fun equiv-ast-if-branch(b1 :: IfBranch, b2 :: IfBranch):
  cases(IfBranch) b1:
    | s_if_branch(_, expr1, body1) =>
      cases(IfBranch) b2:
        | s_if_branch(_, expr2, body2) =>
          equiv-ast(expr1, expr2) and equiv-ast(body1, body2)
        | else => false
      end
  end
end

fun equiv-ast-cases-branch(cb1 :: CasesBranch, cb2 :: CasesBranch):
  cases(CasesBranch) cb1:
    | s_cases_branch(_, n1, ar1, body1) =>
      cases(CasesBranch) cb2:
        | s_cases_branch(_, n2, ar2, body2) =>
          (n1 == n2) and
            equiv-ast(ar1, ar2) and
            equiv-ast(body1, body2)
        | else => false
      end
  end
end

fun equiv-ast-variant-member(m1 :: VariantMember, m2 :: VariantMember):
  cases(VariantMember) m1:
    | s_variant_member(_, t1, b1) =>
      cases(VariantMember) m2:
        | s_variant_member(_, t2, b2) =>
          equiv-ast-ann(t1, t2) and equiv-ast(b1, b2)
        | else => false
      end
  end
end

fun equiv-ast-variant(v1 :: Variant, v2 :: Variant):
  cases(Variant) v1:
    | s_variant(_, n1, b1, wm1) =>
      cases(Variant) v2:
        | s_variant(_, n2, b2, wm2) =>
          (n1 == n2) and
            length-andmap(equiv-ast-bind, b1, b2) and
            length-andmap(equiv-ast-member, wm1, wm2)
        | else => false
      end
    | else => raise("nyi variant")
  end
  #(match (cons v1 v2)
  #  [(cons
  #    (s-singleton-variant _ name1 with-members1)
  #    (s-singleton-variant _ name2 with-members2))
  #   (and
  #    (symbol=? name1 name2)
  #    (length-andmap equiv-ast-member with-members1 with-members2))]
end

fun equiv-ast-datatype-variant(v1 :: DatatypeVariant, v2 :: DatatypeVariant):
  raise("nyi datatype-variant")
  #  [(cons
  #    (s-datatype-variant _ name1 binds1 constructor1)
  #    (s-datatype-variant _ name2 binds2 constructor2))
  #   (and
  #    (symbol=? name1 name2)
  #    (length-andmap equiv-ast-variant-member binds1 binds2)
  #    (equiv-ast-constructor constructor1 constructor2))]
  # [(cons
  #   (s-datatype-singleton-variant _ name1 constructor1)
  #   (s-datatype-singleton-variant _ name2 constructor2))
  #  (and
  #    (symbol=? name1 name2)
  #    (equiv-ast-constructor constructor1 constructor2))]
  #  [_ #f]))
end

fun equiv-ast-constructor(c1 :: Constructor, c2 :: Constructor):
  raise("nyi constructor")
  #(match (cons c1 c2)
  #  [(cons (s-datatype-constructor _ self1 body1)
  #         (s-datatype-constructor _ self2 body2))
  #   (and
  #    (symbol=? self1 self2)
  #    (equiv-ast body1 body2))]))
end

fun equiv-ast-ann(a1, a2):
  cases(Ann) a1:
    | a_any => is-a_any(a2)
    | a_blank => is-a_blank(a2)
    | else =>
      raise("nyi equiv-ast-ann")
  end
  #  [(cons (a-name _ id1) (a-name _ id2)) (equal? id1 id2)]
  #  [(cons (a-pred _ a1 pred1) (a-pred _ a2 pred2))
  #   (and
  #    (equiv-ast-ann a1 a2)
  #    (equiv-ast pred1 pred2))]
  #  [(cons (a-arrow _ args1 ret1) (a-arrow _ args2 ret2))
  #   (and
  #    (length-andmap equiv-ast-ann args1 args2)
  #    (equiv-ast-ann ret1 ret2))]
  #  [(cons (a-method _ args1 ret1) (a-method _ args2 ret2))
  #   (and
  #    (length-andmap equiv-ast-ann args1 args2)
  #    (equiv-ast-ann ret1 ret2))]
#
#      [(cons (a-field _ name1 ann1) (a-field _ name2 ann2))
#       (and
#        (equal? name1 name2)
#        (equiv-ast-ann ann1 ann2))]
#
#      [(cons (a-record _ fields1) (a-record _ fields2))
#       (length-andmap equiv-ast-ann fields1 fields2)]
#      [(cons (a-app _ ann1 parameters1) (a-app _ ann2 parameters2))
#       (and
#        (equiv-ast-ann ann1 ann2)
#        (length-andmap equiv-ast-ann parameters1 parameters2))]
#      [(cons (a-dot _ obj1 field1) (a-dot _ obj2 field2))
#       (and
#        (equiv-ast-ann obj1 obj2)
#        (equal? field1 field2))]
#      ;; How to catch NYI things?  I wish for some sort of tag-match predicate on pairs
#      [_ #f]))
end

fun equiv-ast-fun(
      name1, params1, args1, ann1, doc1, body1, check1,
      name2, params2, args2, ann2, doc2, body2, check2):
   length-andmap(_ == _, params1, params2) and
     length-andmap(equiv-ast-bind, args1, args2) and
     equiv-ast-ann(ann1, ann2) and
     (doc1 == doc2) and
     equiv-ast(body1, body2) and
     equiv-ast(check1, check2) and
     (name1 == name2)
end

fun equiv-ast-header(h1 :: Header, h2 :: Header):
  fun equiv-import-type(f1, f2):
    cases(ImportType) f1:
      | s_file_import(n1) =>
        cases(ImportType) f2:
          | s_file_import(n2) => (n1 == n2)
          | else => false
        end
      | s_const_import(n1) =>
        cases(ImportType) f2:
          | s_const_import(n2) => (n1 == n2)
          | else => false
        end
    end
  end
  cases(Header) h1:
    | s_provide-all(_) => is-s_provide_all(h2)
    | s_provide(_, expr1) =>
      cases(Header) h2:
        | s_provide(_, expr2) => equiv-ast(expr1, expr2)
        | else => false
      end
    | s_import(_, file1, name1) =>
      cases(Header) h2:
        | s_import(_, file2, name2) =>
          equiv-import-type(file1, file2) and (name1 == name2)
        | else => false
      end
  end
end

fun equiv-ast-let-bind(lb1 :: LetBind, lb2 :: LetBind):
  cases(LetBind) lb1:
    | s_let_bind(_, bind1, value1) => 
      cases(LetBind) lb2:
        | s_let_bind(_, bind2, value2) =>
          equiv-ast-bind(bind1, bind2) and
            equiv-ast(value1, value2)
        | else => false
      end
    | s_var_bind(_, bind1, value1) => 
      cases(LetBind) lb2:
        | s_var_bind(_, bind2, value2) => 
          equiv-ast-bind(bind1, bind2) and
            equiv-ast(value1, value2)
        | else => false
      end
  end
end

fun equiv-ast-letrec-bind(lb1 :: LetrecBind, lb2 :: LetrecBind):
  cases(LetrecBind) lb1:
    | s_letrec_bind(_, bind1, value1) => 
      cases(LetrecBind) lb2:
        | s_letrec_bind(_, bind2, value2) =>
          equiv-ast-bind(bind1, bind2) and
            equiv-ast(value1, value2)
        | else => false
      end
  end
end

fun equiv-ast(ast1 :: Expr, ast2 :: Expr):
  cases (Expr) ast1:
    | s_block(_, stmts1) =>
      cases(Expr) ast2:
        | s_block(_, stmts2) => length-andmap(equiv-ast, stmts1, stmts2)
        | else => false
      end
    | s_fun(_, n1, p1, ar1, an1, d1, b1, c1) =>
      cases(Expr) ast2:
        | s_fun(_, n2, p2, ar2, an2, d2, b2, c2) =>
          equiv-ast-fun(
              n1, p1, ar1, an1, d1, b1, c1,
              n2, p2, ar2, an2, d2, b2, c2
            )
        | else => false
      end
    | s_lam(_, p1, ar1, an1, d1, b1, c1) =>
      cases(Expr) ast2:
        | s_lam(_, p2, ar2, an2, d2, b2, c2) =>
          equiv-ast-fun(
              "anon", p2, ar1, an1, d1, b1, c1,
              "anon", p2, ar2, an2, d2, b2, c2
            )
        | else => false
      end
    | s_method(_, ar1, an1, d1, b1, c1) =>
      cases(Expr) ast2:
        | s_method(_, ar2, an2, d2, b2, c2) =>
          equiv-ast-fun(
              "meth", [], ar1, an1, d1, b1, c1,
              "meth", [], ar2, an2, d2, b2, c2
            )
        | else => false
      end
    | s_check(_, body1) =>
      cases(Expr) ast2:
        | s_check(_, body2) => equiv-ast(body1, body2)
        | else => false
      end
    | s_var(_, bind1, value1) =>
      cases(Expr) ast2:
        | s_var(_, bind2, value2) =>
          equiv-ast-bind(bind1, bind2) and equiv-ast(value1, value2)
        | else => false
      end
    | s_let(_, bind1, value1) =>
      cases(Expr) ast2:
        | s_let(_, bind2, value2) =>
          equiv-ast-bind(bind1, bind2) and equiv-ast(value1, value2)
        | else => false
      end
    | s_graph(_, bindings1) =>
      cases(Expr) ast2:
        | s_graph(_, bindings2) => length-andmap(equiv-ast, bindings1, bindings2)
        | else => false
      end
    | s_list(_, values1) =>
      cases(Expr) ast2:
        | s_list(_, values2) => length-andmap(equiv-ast, values1, values2)
        | else => false
      end
    | s_op(_, op1, left1, right1) =>
      cases(Expr) ast2:
        | s_op(_, op2, left2, right2) =>
            (op1 == op2) and
              equiv-ast(left1, left2) and
              equiv-ast(right1, right2)
        | else => false
      end
    | s_check_test(_, op1, left1, right1) =>
      cases(Expr) ast2:
        | s_check_test(_, op2, left2, right2) =>
            (op1 == op2) and
              equiv-ast(left1, left2) and
              equiv-ast(right1, right2)
        | else => false
      end
    | s_user_block(_, block1) =>
      cases(Expr) ast2:
        | s_user_block(_, block2) => equiv-ast(block1, block2)
        | else => false
      end
    | s_when(_, test1, block1) =>
      cases(Expr) ast2:
        | s_when(_, test2, block2) =>
          equiv-ast(test1, test2) and equiv-ast(block1, block2)
        | else => false
      end
    | s_if(_, branches1) =>
      cases(Expr) ast2:
        | s_if(_, branches2) =>
          length-andmap(equiv-ast-if-branch, branches1, branches2)
        | else => false
      end
    | s_if_else(_, branches1, _else1) => 
      cases(Expr) ast2:
        | s_if_else(_, branches2, _else2) =>
          length-andmap(equiv-ast-if-branch, branches1, branches2) and
            equiv-ast(_else1, _else2)
        | else => false
      end
    | s_try(_, body1, id1, except1) =>
      cases(Expr) ast2:
        | s_try(_, body2, id2, except2) =>
          equiv-ast(body1, body2) and
            equiv-ast-bind(id1, id2) and
            equiv-ast(except1, except2)
        | else => false
      end
    | s_cases(_, type1, val1, branches1) => 
      cases(Expr) ast2:
        | s_cases(_, type2, val2, branches2) =>
          equiv-ast-ann(type1, type2) and
            equiv-ast(val1, val2) and
            length-andmap(equiv-ast-cases-branch, branches1, branches2)
        | else => false
      end
    | s_cases_else(_, type1, val1, branches1, _else1) =>
      cases(Expr) ast2:
        | s_cases_else(_, type2, val2, branches2, _else2) =>
          equiv-ast-ann(type1, type2) and
            equiv-ast(val1, val2) and
            length-andmap(equiv-ast-cases-branch, branches1, branches2) and
            equiv-ast(_else1, _else2)
        | else => false
      end
    | s_not(_, expr1) => 
      cases(Expr) ast2:
        | s_not(_, expr2) => equiv-ast(expr1, expr2)
        | else => false
      end
    | s_paren(_, expr1) =>
      cases(Expr) ast2:
        | s_paren(_, expr2) => equiv-ast(expr1, expr2)
        | else => false
      end
    | s_extend(_, super1, fields1) => 
      cases(Expr) ast2:
        | s_extend(_, super2, fields2) => 
          equiv-ast(super1, super2) and length-andmap(equiv-ast-member, fields1, fields2)
        | else => false
      end
    | s_update(_, super1, fields1) => 
      cases(Expr) ast2:
        | s_update(_, super2, fields2) => 
          equiv-ast(super1, super2) and length-andmap(equiv-ast-member, fields1, fields2)
        | else => false
      end
    | s_obj(_, fields1) => 
      cases(Expr) ast2:
        | s_obj(_, fields2) => length-andmap(equiv-ast-member, fields1, fields2)
        | else => false
      end
    | s_app(_, fun1, args1) =>
      cases(Expr) ast2:
        | s_app(_, fun2, args2) =>
          equiv-ast(fun1, fun2) and length-andmap(equiv-ast, args1, args2)
        | else => false
      end
    | s_left_app(_, obj1, fun1, args1) =>
      cases(Expr) ast2:
        | s_left_app(_, obj2, fun2, args2) =>
          equiv-ast(obj1, obj2) and
            equiv-ast(fun1, fun2) and
            length-andmap(equiv-ast, args1, args2)
        | else => false
      end
    | s_assign(_, id1, value1) =>
      cases(Expr) ast2:
        | s_assign(_, id2, value2) =>
          (id1 == id2) and
            equiv-ast(value1, value2)
        | else => false
      end
    | s_colon(_, obj1, field1) =>
      cases(Expr) ast2:
        | s_colon(_, obj2, field2) =>
          equiv-ast(obj1, obj2) and (field1 == field2)
        | else => false
      end
    | s_dot(_, obj1, field1) =>
      cases(Expr) ast2:
        | s_dot(_, obj2, field2) =>
          equiv-ast(obj1, obj2) and (field1 == field2)
        | else => false
      end
    | s_get-bang(_, obj1, field1) =>
      cases(Expr) ast2:
        | s_get-bang(_, obj2, field2) =>
          equiv-ast(obj1, obj2) and (field1 == field2)
        | else => false
      end
    | s_bracket(_, obj1, field1) =>
      cases(Expr) ast2:
        | s_bracket(_, obj2, field2) =>
          equiv-ast(obj1, obj2) and equiv-ast(field1, field2)
        | else => false
      end
    | s_colon_bracket(_, obj1, field1) =>
      cases(Expr) ast2:
        | s_colon_bracket(_, obj2, field2) =>
          equiv-ast(obj1, obj2) and equiv-ast(field1, field2)
        | else => false
      end
    | s_for(_, iter1, binds1, ann1, body1) =>
      cases(Expr) ast2:
        | s_for(_, iter2, binds2, ann2, body2) =>
          equiv-ast(iter1, iter2) and
            length-andmap(equiv-ast-for-binding, binds1, binds2) and
            equiv-ast-ann(ann1, ann2) and
            equiv-ast(body1, body2)
        | else => false
      end
    | s_data(_, n1, p1, m1, v1, sm1, c1) =>
      cases(Expr) ast2:
        | s_data(_, n2, p2, m2, v2, sm2, c2) =>
          (n1 == n2) and
            length-andmap(_ == _, p1, p2) and
            length-andmap(equiv-ast, m1, m2) and
            length-andmap(equiv-ast-variant, v1, v2) and
            length-andmap(equiv-ast-member, sm1, sm2) and
            equiv-ast(c1, c2)
        | else => false
      end
    | s_datatype(_, n1, p1, v1, c1) =>
      cases(Expr) ast2:
        | s_datatype(_, n2, p2, v2, c2) =>
          (n1 == n2) and
            length-andmap(_ == _, p1, p2) and
            length-andmap(equiv-ast-datatype-variant, v1, v2) and
            equiv-ast(c1, c2)
        | else => false
      end
    | s_num(_, n1) =>
      cases(Expr) ast2:
        | s_num(_, n2) => n1 == n2
        | else => false
      end
    | s_str(_, s1) =>
      cases(Expr) ast2:
        | s_str(_, s2) => s1 == s2
        | else => false
      end
    | s_bool(_, b1) => 
      cases(Expr) ast2:
        | s_bool(_, b2) => b1 == b2
        | else => false
      end
    | s_undefined(_) =>
      is-s_undefined(ast2)
    | s_id(_, id1) =>
      cases(Expr) ast2:
        | s_id(_, id2) => id1 == id2
        | else => false
      end
    | s_id_var(_, id1) =>
      cases(Expr) ast2:
        | s_id_var(_, id2) => id1 == id2
        | else => false
      end
    | s_id_letrec(_, id1) =>
      cases(Expr) ast2:
        | s_id_letrec(_, id2) => id1 == id2
        | else => false
      end
    | s_let_expr(_, let-binds1, body1) =>
      cases(Expr) ast2:
        | s_let_expr(_, let-binds2, body2) =>
          length-andmap(equiv-ast-let-bind, let-binds1, let-binds2) and
            equiv-ast(body1, body2)
        | else => false
      end
    | s_letrec(_, let-binds1, body1) =>
      cases(Expr) ast2:
        | s_letrec(_, let-binds2, body2) =>
          length-andmap(equiv-ast-letrec-bind, let-binds1, let-binds2) and
            equiv-ast(body1, body2)
        | else => false
      end
  end
end

