#lang pyret

import cmdline as C
import file as F
import exec as X
import string-dict as D
import "./compile.arr" as CM
import "./compile-structs.arr" as CS


fun main(args):
  options = {
      compile-standalone-js:
        C.next-val(C.String, C.once, "Pyret (.arr) file to compile"),
      compile-module-js:
        C.next-val(C.String, C.once, "Pyret (.arr) file to compile"),
      library:
        C.flag(C.once, "Don't auto-import basics like list, option, etc."),
      libs:
        C.next-val(C.String, C.many, "Paths to files to include as builtin libraries"),
      no-check-mode:
        C.flag(C.once, "Skip checks")
    }

  params-parsed = C.parse-args(options, args)

  cases(C.ParsedArguments) params-parsed:
    | success(r, rest) => 
      check-mode = r.has-key("no-check-mode")
      libs = if r.has-key("library"): CS.no-builtins else: CS.standard-builtins end
      if not is-empty(rest):
        program-name = rest.first
        result = CM.compile-js(
          F.file-to-string(program-name),
          program-name,
          libs,
          {
            check-mode : check-mode
          }
        )
        cases(CS.CompileResult) result:
          | ok(comp-object) => X.exec(comp-object.pyret-to-js-runnable(), rest)
          | err(_) => result
        end
      else:
        result = if r.has-key("compile-standalone-js"):
            CM.compile-standalone-js-file(
              r.get("compile-standalone-js"),
              libs,
              {
                check-mode : check-mode
              }
            )
          else if r.has-key("compile-module-js"):
            CM.compile-js(
              F.file-to-string(r.get("compile-module-js")),
              r.get("compile-module-js"),
              libs,
              {
                check-mode : check-mode
              }
            )
          else:
            print(C.usage-info(options).join-str("\n"))
            raise("Unknown command line options")
          end
        cases(CS.CompileResult) result:
          | ok(comp-object) => comp-object.print-js-runnable(display)
          | err(e) =>
            print-error(e.tostring())
        end
      end
    | arg-error(message, partial) =>
      print(message)
      print(C.usage-info(options).join-str("\n"))
  end
end

_ = main(C.args)
