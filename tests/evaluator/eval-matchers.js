define(["./eval", "../runtime/matchers"], function(e, matchers) {
  console.log("eval-matchers body");

  function makeEvalCheckers(jasmine, runtime) {
    matchers.addPyretMatchers(jasmine);
    function gf(o, s) { return runtime.getField(o, s); }
    var pending = [];

    function checkEvalsTo(str, answer) {
      var i = pending.push(false);
      e.evalPyret(runtime, str, {}, function(result) {
        expect(result).toBeSuccess(runtime);
        var actual = gf(result.result, "answer");
        console.log("Comparing ", runtime.toReprJS(actual), runtime.toReprJS(answer));
        expect(actual).toBeSameAs(runtime, answer);
        pending[i - 1] = true;
      });
    }
    function checkError(str, exnPred) {
      var i = pending.push(false);
      e.evalPyret(runtime, str, {}, function(result) {
        expect(result).toBeFailure(runtime);
        if (runtime.isFailureResult(result)) {
          var exn = result.exn;
          expect(exn).toPassPredicate(exnPred);
        }
        pending[i - 1] = true;
      });
    }
    function wait(done) {
      setTimeout(function() {
          if(pending.filter(function(p) { return p === false; }).length === 0) {
            done();
          }
          else {
            setTimeout(function() { wait(done); });
          }
        },
        100);
    }
    return {
      checkEvalsTo: checkEvalsTo,
      checkError: checkError,
      wait: wait
    };
  }

  return {
    makeEvalCheckers: makeEvalCheckers
  };

});
