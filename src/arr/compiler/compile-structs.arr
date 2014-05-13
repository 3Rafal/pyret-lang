#lang pyret

provide *
import ast as A

data PyretDialect:
  | Pyret
  | Bootstrap
end

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
  | reserved-name(loc :: Loc, id :: String) with:
    tostring(self):
      "well-formedness: cannot use " + self.id + " as an identifier at " + tostring(self.loc) end
  | zero-fraction(loc, numerator) with:
    tostring(self):
      "well-formedness: fraction literal with zero denominator (numerator was " + tostring(self.numerator) + " at " + tostring(self.loc)
    end
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
        + ", but its definition at " + self.prev-loc.format(not(self.loc.same-file(self.prev-loc)))
        + " is not assignable.  (Only names declared with var are assignable.)"
    end
  | mixed-id-var(id :: String, var-loc :: Loc, id-loc :: Loc) with:
    tostring(self):
      self.id + " is declared as both a variable (at " + tostring(self.var-loc) + ")"
        + " and an identifier (at " + self.id-loc.format(not(self.var-loc.same-file(self.id-loc))) + ")"
    end
  | shadow-id(id :: String, new-loc :: Loc, old-loc :: Loc) with:
    tostring(self):
      "Identifier " + self.id + " is declared at " + tostring(self.new-loc)
        + ", but is already declared at " + self.old-loc.format(not(self.new-loc.same-file(self.old-loc)))
    end
  | duplicate-id(id :: String, new-loc :: Loc, old-loc :: Loc) with:
    tostring(self):
      "Identifier " + self.id + " is declared twice, at " + tostring(self.new-loc)
        + " and at " + self.old-loc.format(not(self.new-loc.same-file(self.old-loc)))
    end
end

data CompileBinding:
  | builtin-id(id :: String)
  | module-bindings(name :: String, bindings :: List<String>)
end

runtime-builtins = list.map(builtin-id, [
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
  "not",
  "is-nothing",
  "is-number",
  "is-string",
  "is-boolean",
  "is-object",
  "is-function",
  "is-raw-array",
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
  "strings-equal",
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
  "nums-equal",
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
  "num-sqr",
  "num-ceiling",
  "num-floor",
  "num-log",
  "num-exp",
  "num-exact",
  "num-is-integer",
  "num-is-fixnum",
  "num-expt",
  "num-tostring",
  "raw-array-get",
  "raw-array-set",
  "raw-array-of",
  "raw-array-length",
  "raw-array-to-list"
])

no-builtins = compile-env([])

minimal-builtins = compile-env(runtime-builtins)

bootstrap-builtins = compile-env(
  [module-bindings("list", [
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
  ])] +
  runtime-builtins + list.map(builtin-id, [
  

  "_link",
  "_empty",

  # new arithmetic aliases  
  "add",
  "sub",
  "div",
  "mul",
  "less",
  "greater",
  "greaterequal",
  "lessequal",

  "both",
  "either",
  "not",

  "max",
  "min",
  "abs",
  "sin",
  "cos",
  "tan",
  "asin",
  "acos",
  "atan",
  "modulo",
  "truncate",
  "sqrt",
  "sqr",
  "ceiling",
  "floor",
  "log",
  "exp",
  "exact",
  "is-integer",
  "is-fixnum",
  "expt",

  # from js/trove/image.js
  "circle",
  "is-image-color",
  "is-mode",
  "is-x-place",
  "is-y-place",
  "is-angle",
  "is-side-count",
  "is-step-count",
  "is-image",
  "bitmap-url",
  "open-image-url",
  "image-url",
  "images-equal",
  "text",
  "normal",
  "text-font",
  "overlay",
  "middle",
  "overlay-xy",
  "overlay-align",
  "underlay",
  "middle",
  "underlay-xy",
  "underlay-align",
  "beside-align",
  "beside",
 "above",
  "middle",
  "above-align",
  "empty-scene",
  "put-image",
  "place-image",
  "place-image-align",
  "rotate",
  "scale",
  "scale-xy",
  "flip-horizontal",
  "flip-vertical",
  "frame",
  "crop",
  "line",
  "add-line",
  "scene-line",
  "square",
  "rectangle",
  "regular-polygon",
  "ellipse",
  "triangle",
  "triangle-sas",
  "triangle-sss",
  "triangle-ass",
  "triangle-ssa",
  "triangle-aas",
  "triangle-asa",
  "triangle-saa",
  "right-triangle",
  "isosceles-triangle",
  "star",
  "star-sized",
  "radial-star",
  "star-polygon",
  "rhombus",
  "image-to-color-list",
  "color-list-to-image",
  "color-list-to-bitmap",
  "image-width",
  "image-height",
  "image-baseline",
  "name-to-color",

  # from js/trove/world.js
  "big-bang",
  "on-tick",
  "on-tick-n",
  "to-draw",
  "on-mouse",
  "on-key",
  "stop-when",
  "is-key-equal"
  ])
)

standard-builtins = compile-env(
    runtime-builtins + [
      builtin-id("_link"),
      builtin-id("_empty"),
      module-bindings("arrays", [
          "array",
          "build-array",
          "array-from-list",
          "is-array"
        ]),
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

