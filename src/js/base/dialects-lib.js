define(["js/runtime-util", 
        "js/pyret-tokenizer", "js/pyret-parser", "compiler/compile-structs.arr",
        "js/bootstrap-tokenizer", "js/bootstrap-parser", "js/bootstrap-un-tokenizer", "js/bootstrap-un-parser", "js/bootstrap-namespace"], 
function(util, 
         PT, PG, PCS,
         BT, BG, BUT, BUG, BN) {
  return util.memoModule("dialects-lib", function(RUNTIME, NAMESPACE) {
    function get(obj, fld) { return RUNTIME.getField(obj, fld); }
    var pcs = get(PCS(RUNTIME, NAMESPACE), "provide");
    var dialects = {
      "Pyret": { 
        Tokenizer: PT.Tokenizer, 
        Grammar: PG.PyretGrammar,
        UnTokenizer: PT.Tokenizer, 
        UnGrammar: PG.PyretGrammar,
        makeNamespace: function(rt) { return rt.namespace; },
        compileEnv: get(pcs, "standard-builtins")
      },
      "Bootstrap": { 
        Tokenizer: BT.Tokenizer, 
        UnTokenizer: BUT.Tokenizer,
        Grammar: BG.BootstrapGrammar, 
        UnGrammar: BUG.BootstrapGrammar,
        makeNamespace: BN.create,
        compileEnv: get(pcs, "bootstrap-builtins")
      }
    }

    return {
      dialects: dialects,
      defaultDialect: "Pyret"
    };
  });
});



