#lang pyret

import cmdline as C
import file as F
import string-dict as D
import file("compile.arr") as CM
import file("compile-lib.arr") as CL
import file("compile-structs.arr") as CS
import file("cli-module-loader.arr") as CLI
import file("locators/builtin.arr") as B
import format as Format
import either as E
#import file("initialize-trove.arr") as IT
import render-error-display as RED
format = Format.format
Either = E.Either
left = E.left
right = E.right


fun main(args):
  options = [D.string-dict:
    "compile-module-js",
      C.next-val(C.String, C.once, "Pyret (.arr) file to compile"),
    "build-standalone",
      C.next-val(C.String, C.once, "Main Pyret (.arr) file to build as a standalone"),
    "build-runnable",
      C.next-val(C.String, C.once, "Main Pyret (.arr) file to build as a standalone"),
    "require-config",
      C.next-val(C.String, C.once, "JSON file to use for requirejs configuration of build-runnable"),
    "build",
      C.next-val(C.String, C.once, "Pyret (.arr) file to build"),
    "run",
      C.next-val(C.String, C.once, "Pyret (.arr) file to compile and run"),
    "builtin-js-dir",
      C.next-val(C.String, C.once, "Directory to find the source of builtin js modules"),
    "builtin-arr-dir",
      C.next-val(C.String, C.once, "Directory to find the source of builtin arr modules"),
    "compiled-dir",
      C.next-val-default(C.String, "compiled", none, C.once, "Directory to save compiled files to"),
    "library",
      C.flag(C.once, "Don't auto-import basics like list, option, etc."),
    "module-load-dir",
      C.next-val-default(C.String, ".", none, C.once, "Base directory to search for modules"),
    "check-all",
      C.flag(C.once, "Run checks all modules (not just the main module)"),
    "no-check-mode",
      C.flag(C.once, "Skip checks"),
    "allow-shadow",
      C.flag(C.once, "Run without checking for shadowed variables"),
    "improper-tail-calls",
      C.flag(C.once, "Run without proper tail calls"),
    "type-check",
      C.flag(C.once, "Type-check the program during compilation")
  ]
  
  params-parsed = C.parse-args(options, args)

  fun err-less(e1, e2):
    if (e1.loc.before(e2.loc)): true
    else if (e1.loc.after(e2.loc)): false
    else: tostring(e1) < tostring(e2)
    end
  end
  
  cases(C.ParsedArguments) params-parsed:
    | success(r, rest) => 
      check-mode = not(r.has-key("no-check-mode") or r.has-key("library"))
      allow-shadowed = r.has-key("allow-shadow")
      libs =
        if r.has-key("library"): CS.minimal-imports
        else: CS.standard-imports end
      module-dir = r.get-value("module-load-dir")
      check-all = r.has-key("check-all")
      type-check = r.has-key("type-check")
      tail-calls = not(r.has-key("improper-tail-calls"))
      compiled-dir = r.get-value("compiled-dir")
      when r.has-key("builtin-js-dir"):
        B.set-builtin-js-dir(r.get-value("builtin-js-dir"))
      end
      when r.has-key("builtin-arr-dir"):
        B.set-builtin-arr-dir(r.get-value("builtin-arr-dir"))
      end
      if not(is-empty(rest)):
        program-name = rest.first
        var result = CM.compile-js(
          CM.start,
          F.file-to-string(program-name),
          program-name,
          CS.standard-builtins,
          libs,
          {
            check-mode : check-mode,
            allow-shadowed : allow-shadowed,
            collect-all: false,
            type-check: type-check,
            ignore-unbound: false,
            proper-tail-calls: tail-calls,
            compile-module: false,
            compiled-cache: compiled-dir
          }
          ).result
        cases(CS.CompileResult) result:
          | ok(_) =>
            #var comp-object = result.code
            #result := nothing
            raise("No longer supported")
            #|
            var exec-result = X.exec(comp-object.pyret-to-js-runnable(), program-name, module-dir, check-all, rest)
            comp-object := nothing
            if (exec-result.success):
              when check-mode:
                results-str = exec-result.render-check-results()
                print(results-str)
                when not(string-contains(results-str, "Looks shipshape")) and
                  not(string-contains(results-str, "The program didn't define any tests")):
                  raise("There were test errors")
                end
              end
            else:
              print(exec-result.render-error-message())
              raise("There were execution errors")
            end
            |#
          | err(errors) =>
            print-error("Compilation errors:")
            for lists.each(e from errors):
              print-error(RED.display-to-string(e.render-reason(), torepr, empty))
            end
            raise("There were compilation errors")
        end
      else:
        if r.has-key("build-runnable"):
          CLI.build-runnable-standalone(
              r.get-value("build-runnable"), 
              r.get-value("require-config"),
              {
                check-mode : check-mode,
                type-check : type-check,
                allow-shadowed : allow-shadowed,
                collect-all: false,
                ignore-unbound: false,
                proper-tail-calls: tail-calls,
                compile-module: true,
                compiled-cache: compiled-dir
              })
        else if r.has-key("build-standalone"):
          CLI.build-require-standalone(r.get-value("build-standalone"), {
              check-mode : check-mode,
              type-check : type-check,
              allow-shadowed : allow-shadowed,
              collect-all: false,
              ignore-unbound: false,
              proper-tail-calls: tail-calls,
              compile-module: true,
              compiled-cache: compiled-dir
            })
        else if r.has-key("build"):
          result = CLI.compile(r.get-value("build"),
            {
              check-mode : check-mode,
              type-check : type-check,
              allow-shadowed : allow-shadowed,
              collect-all: false,
              ignore-unbound: false,
              proper-tail-calls: tail-calls,
              compile-module: false # weird, but accurate for now
            })
          failures = filter(CS.is-err, result.loadables)
          when is-link(failures):
            for each(f from failures):
              for lists.each(e from f.errors):
                print-error(tostring(e))
              end
              raise("There were compilation errors")
            end
          end
        else if r.has-key("run"):
          CLI.run(r.get-value("run"),
            {
              check-mode : check-mode,
              type-check : type-check,
              allow-shadowed : allow-shadowed,
              collect-all: false,
              ignore-unbound: false,
              proper-tail-calls: true,
              compile-module: false
            })
        else if r.has-key("compile-module-js"):
          var result = CM.compile-js(
            CM.start,
            F.file-to-string(r.get-value("compile-module-js")),
            r.get-value("compile-module-js"),
            CS.standard-builtins,
            libs,
            {
              check-mode : check-mode,
              type-check : type-check,
              allow-shadowed : allow-shadowed,
              collect-all: false,
              ignore-unbound: false,
              proper-tail-calls: tail-calls,
              compile-module: false # weird, but accurate for now
            }
            ).result
          cases(CS.CompileResult) result:
            | ok(_) =>
              comp-object = result.code
              result := nothing
              comp-object.print-js-runnable(display)
            | err(errors) =>
              print-error("Compilation errors:")
              for lists.each(e from errors):
                print-error(RED.display-to-string(e.render-reason(), torepr, empty))
              end
              raise("There were compilation errors")
          end
        else:
          print(C.usage-info(options).join-str("\n"))
          raise("Unknown command line options")
        end
      end
    | arg-error(message, partial) =>
      print(message)
      print(C.usage-info(options).join-str("\n"))
  end
end

_ = main(C.args)
