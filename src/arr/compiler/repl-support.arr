#lang pyret

provide *
import "compiler/compile-structs.arr" as C
import ast as A



fun add-global-binding(env :: C.CompileEnvironment, name :: String):
  cases(C.CompileEnvironment) env:
    | compile-env(bindings, type-bindings) =>
      C.compile-env(link(C.builtin-id(name), bindings), type-bindings)
  end
end

fun make-provide-all(p :: A.Program):
  doc: "Make the program simply provide all (for the repl)"
  cases(A.Program) p:
    | s-program(l, _, _, imports, body) =>
      A.s-program(l, A.s-provide-all(l), A.s-provide-types-all(l), imports, body)
  end
end

