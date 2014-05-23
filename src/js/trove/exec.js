define(["js/secure-loader", "js/ffi-helpers", "js/runtime-anf", "js/runtime-anf2", "trove/checker", "js/dialects-lib"], function(loader, ffi, runtimeLib, runtime2Lib, checkerLib, dialectsLib) {

  if(requirejs.isBrowser) {
    var rjs = requirejs;
    var define = window.define;
  }
  else {
    var rjs = require("requirejs");
    var define = rjs.define;
  }

  return function(RUNTIME, NAMESPACE) {
    var F = ffi(RUNTIME, NAMESPACE);

    function execWithDir(jsStr, modnameP, loaddirP, checkAllP, dialectP, params) {
      F.checkArity(6, arguments, "exec");
      RUNTIME.checkString(jsStr);
      RUNTIME.checkString(modnameP);
      RUNTIME.checkString(loaddirP);
      RUNTIME.checkBoolean(checkAllP);
      RUNTIME.checkString(dialectP);
      var str = RUNTIME.unwrap(jsStr);
      var modname = RUNTIME.unwrap(modnameP);
      var loaddir = RUNTIME.unwrap(loaddirP);
      var checkAll = RUNTIME.unwrap(checkAllP);
      var dialect = RUNTIME.unwrap(dialectP);
      var argsArray = F.toArray(params).map(RUNTIME.unwrap);
      return exec(str, modname, loaddir, checkAll, dialect, argsArray);
    }

    function exec(str, modname, loaddir, checkAll, dialect, args) {
      var name = RUNTIME.unwrap(NAMESPACE.get("gensym").app(RUNTIME.makeString("module")));
      rjs.config({ baseUrl: loaddir });

      var newRuntime = runtime2Lib.makeRuntime({ 
        stdout: function(str) { process.stdout.write(str); },
        stderr: function(str) { process.stderr.write(str); },
      });
      var dialect = dialectsLib(newRuntime, newRuntime.namespace).dialects[dialect];
      var newNamespace = dialect.makeNamespace(newRuntime);
      var fnew = ffi(newRuntime, newRuntime.namespace);
      newRuntime.setParam("command-line-arguments", args);

      var checker = newRuntime.getField(checkerLib(newRuntime, newRuntime.namespace), "provide");
      var currentChecker = newRuntime.getField(checker, "make-check-context").app(newRuntime.makeString(modname), newRuntime.makeBoolean(checkAll));
      newRuntime.setParam("current-checker", currentChecker);

      function makeResult(execRt, callingRt, r) {
        if(execRt.isSuccessResult(r)) {
          console.log("Got a success result");
          var pyretResult = r.result;
          return callingRt.makeObject({
              "success": callingRt.makeBoolean(true),
              "render-check-results": callingRt.makeFunction(function() {
                var toCall = execRt.getField(checker, "render-check-results");
                var checks = execRt.getField(pyretResult, "checks");
                callingRt.pauseStack(function(restarter) {
                  console.log("Here 1");
                    execRt.run(function(rt, ns) {
                      console.log("Here 3");
                        return toCall.app(checks);
                      }, execRt.namespace, {sync: true},
                      function(printedCheckResult) {
                        if(execRt.isSuccessResult(printedCheckResult)) {
                          if(execRt.isString(printedCheckResult.result)) {
                            restarter.resume(callingRt.makeString(execRt.unwrap(printedCheckResult.result)));
                          }
                        }
                        else if(execRt.isFailureResult(printedCheckResult)) {
                          console.error(printedCheckResult);
                          console.error(printedCheckResult.exn);
                          restarter.resume(callingRt.makeString("There was an exception while formatting the check results"));
                        }
                      });
                  });
              })
            });
        }
        else if(execRt.isFailureResult(r)) {
          console.log("Got a failing result");
          console.log(JSON.stringify(r));
          return callingRt.makeObject({
              "success": callingRt.makeBoolean(false),
              "failure": r.exn.exn,
              "render-error-message": callingRt.makeFunction(function() {
                console.log("Failing, trying to render error message");
                callingRt.pauseStack(function(restarter) {
                  execRt.runThunk(function() {
                    if(execRt.isPyretVal(r.exn.exn)) {
                      return execRt.string_append(
                        execRt.toReprJS(r.exn.exn, "tostring"),
                        execRt.makeString("\n" +
                                          execRt.printPyretStack(r.exn.pyretStack)));
                    } else {
                      return JSON.stringify(r.exn);
                    }
                  }, function(v) {
                    if(execRt.isSuccessResult(v)) {
                      return restarter.resume(v.result)
                    } else {
                      console.error("There was an exception while rendering the exception: ", r.exn, v.exn);
                    }
                  })
                });
              })
            });
        }
      }

      RUNTIME.pauseStack(function(restarter) {
        var loaded = loader.goodIdea(RUNTIME, name, str);
        loaded.fail(function(err) {
          restarter.resume(makeResult(newRuntime, RUNTIME, newRuntime.makeFailureResult(err)));
        });

        loaded.then(function(moduleVal) {

          /* run() starts the anonymous module's evaluation on a new stack
             (created by newRuntime).  Once the evaluated program finishes
             (if it ever does), the continuation is called with r as either
             a Success or Failure Result from newRuntime. */
                  console.log("Here 2");
          console.log("Module has loaded, GAS = ", newRuntime.GAS);
          newRuntime.run(moduleVal, newNamespace, {sync: true, initialGas: 20}, function(r) {
            console.log("Got a result!");
            console.log("New success?" + newRuntime.isSuccessResult(r));
            console.log("New failure?" + newRuntime.isFailureResult(r));
            console.log("Old success?" + RUNTIME.isSuccessResult(r));
            console.log("Old failure?" + RUNTIME.isFailureResult(r));
              /* makeResult handles turning values from the new runtime into values that
                 the calling runtime understands (since they don't share
                 the same instantiation of all the Pyret constructors like PObject, or the
                 same brands */

              var wrappedResult = makeResult(newRuntime, RUNTIME, r);

              /* This restarts the calling stack with the new value, which
                 used constructors from the calling runtime.  From the point of view of the
                 caller, wrappedResult is the return value of the call to exec() */
              restarter.resume(wrappedResult);
          });
        });
      });
    }
    return RUNTIME.makeObject({
      provide: RUNTIME.makeObject({
        exec: RUNTIME.makeFunction(execWithDir)
      }),
      answer: NAMESPACE.get("nothing")
    });
  };
});

