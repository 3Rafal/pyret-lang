#lang pyret

provide *
import ast as A

data CompileEnvironment:
  | compile-env(bindings :: List<CompileBinding>)
end

data CompileResult<C>:
  | ok(code :: C)
  | err(problems :: List<CompileError>)
end

data CompileError:
  | wf-err(msg :: String, loc :: A.Loc) with:
    tostring(self): "well-formedness: " + self.msg + " at " + tostring(self.loc) end
  | wf-err-split(msg :: String, loc :: List<A.Loc>) with:
    tostring(self): "well-formedness: " + self.msg + " at " + self.loc.map(tostring).join-str(", ") end
  | unbound-id(id :: A.Expr) with:
    tostring(self):
      "Identifier " + tostring(self.id.id) + " is used at " + tostring(self.id.l) + ", but is not defined"
    end
  | unbound-var(id :: String, loc :: Loc) with:
    tostring(self):
      "Assigning to unbound variable " + self.id + " at " + tostring(self.loc)
    end
  | pointless-var(loc :: Loc) with:
    tostring(self):
      "The anonymous mutable variable at " + tostring(self.loc) + " can never be re-used"
    end
  | pointless-shadow(loc :: Loc) with:
    tostring(self):
      "The anonymous identifier at " + tostring(self.loc) + " can't actually shadow anything"
    end
  | bad-assignment(id :: String, loc :: Loc, prev-loc :: Loc) with:
    tostring(self):
      "Identifier " + self.id + " is assigned at " + tostring(self.loc)
        + ", but its definition at " + tostring(self.prev-loc) + " is not assignable."
        + "  (Only names declared with var are assignable.)"
    end
  | mixed-id-var(id :: String, var-loc :: Loc, id-loc :: Loc) with:
    tostring(self):
      self.id + " is declared as both a variable (at " + tostring(self.var-loc) + ")"
        + " and an identifier (at " + tostring(self.id-loc) + ")"
    end
  | shadow-id(id :: String, new-loc :: Loc, old-loc :: Loc) with:
    tostring(self):
      "Identifier " + self.id + " is declared at " + tostring(self.new-loc)
        + ", but is already declared at " + tostring(self.old-loc)
    end
  | duplicate-id(id :: String, new-loc :: Loc, old-loc :: Loc) with:
    tostring(self):
      "Identifier " + self.id + " is declared twice, at " + tostring(self.new-loc)
        + " and at " + tostring(self.old-loc)
    end
end

data CompileBinding:
  | builtin-id(id :: String)
  | module-bindings(name :: String, bindings :: List<String>)
end

runtime-builtins =
  list.map(builtin-id, [
    "test-print",
    "print",
    "display",
    "print-error",
    "display-error",
    "tostring",
    "torepr",
    "brander",
    "raise",
    "nothing",
    "builtins",
    "is-nothing",
    "is-number",
    "is-string",
    "is-boolean",
    "is-object",
    "is-function",
    "gensym",
    "random",
    "run-task",
    "_plus",
    "_minus",
    "_times",
    "_divide",
    "_lessthan",
    "_lessequal",
    "_greaterthan",
    "_greaterequal",
    "string-contains",
    "string-append",
    "string-length",
    "string-tonumber",
    "string-repeat",
    "string-substring",
    "string-replace",
    "string-split",
    "string-char-at",
    "string-toupper",
    "string-tolower",
    "string-explode",
    "string-index-of",
    "num-max",
    "num-min",
    "num-abs",
    "num-sin",
    "num-cos",
    "num-tan",
    "num-asin",
    "num-acos",
    "num-atan",
    "num-modulo",
    "num-truncate",
    "num-sqrt",
    "num-ceiling",
    "num-floor",
    "num-log",
    "num-exp",
    "num-exact",
    "num-is-integer",
    "num-expt",
    "num-tostring"
])

no-builtins = compile-env([])

minimal-builtins = compile-env(runtime-builtins)

standard-builtins = compile-env(
    runtime-builtins + [
      builtin-id("_link"),
      builtin-id("_empty"),
      module-bindings("list", [
          "List",
          "is-empty",
          "is-link",
          "empty",
          "link",
          "range",
          "repeat",
          "filter",
          "partition",
          "split-at",
          "any",
          "find",
          "map",
          "map2",
          "map3",
          "map4",
          "map_n",
          "map2_n",
          "map3_n",
          "map4_n",
          "each",
          "each2",
          "each3",
          "each4",
          "each_n",
          "each2_n",
          "each3_n",
          "each4_n",
          "fold",
          "fold2",
          "fold3",
          "fold4",
          "index"
          ]),
      module-bindings("option", [
          "Option",
          "is-none",
          "is-some",
          "none",
          "some"
          ]),
      module-bindings("error", []),
      module-bindings("sets", [
          "set",
          "tree-set",
          "list-set"
        ])
    ])
