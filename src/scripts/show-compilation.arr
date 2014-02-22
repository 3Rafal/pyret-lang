#lang pyret

import cmdline as C
import parse-pyret as P
import "./arr/compiler/desugar.arr" as D
import "./arr/compiler/compile.arr" as CM
import "./arr/compiler/compile-structs.arr" as CS
import file as F

options = {
  width: C.next-val-default(C.Number, 80, some("w"), C.once, "Pretty-printed width")
}

parsed = C.parse-cmdline(options)

cases (C.ParsedArguments) parsed:
  | success(opts, rest) =>
    print("Success")
    cases (List) rest:
      | empty => print("Require a file name")
      | link(file, _) =>
        print("File is " + file)
        file-contents = F.file-to-string(file)
        print("")
        print("Read file:")
        print(file-contents)
        parsed = P.surface-parse(file-contents, file)
        print("")
        print("Parsed:")
        each(print, parsed.tosource().pretty(80))
        
        desugared = D.desugar(parsed, CS.standard-builtins)
        print("")
        print("Desugared:")
        each(print, desugared.tosource().pretty(80))

        comp = CM.compile-js(file-contents, file, CS.standard-builtins, {check-mode: false})
        cases(CM.CompileResult) comp:
          | ok(c) =>
            print("")
            print("Generated JS:")
            print(c.pyret-to-js-pretty())
          | err(problems) =>
            print("")
            print("Compilation failed:")
            each(print, problems.map(_.tostring()))
        end
    end
  | arg-error(m, _) =>
    each(print,  ("Error: " + m) ^ link(C.usage-info(options)))
end
print("Finished")
