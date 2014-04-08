var r = require("requirejs");

r.config({
  waitSeconds: 15000,
  baseUrl: "../..",
  paths: {
    trove: "build/phase1/trove",
    js: "build/phase1/js",
    compiler: "build/phase1/arr/compiler"
  }
});

console.log("Starting all-spec");

r([
    "./tests/evaluator/constants",
    "./tests/evaluator/conditionals",
    "./tests/evaluator/data",
    "./tests/evaluator/errors",
    "./tests/evaluator/well-formed",
    "./tests/evaluator/stack"
    ], function (
      constants,
      conditionals,
      data,
      errors,
      well_formed,
      stack
    ) {
  constants.performTest();
  conditionals.performTest();
  data.performTest();
  errors.performTest();
  well_formed.performTest();
//  stack.performTest();
}, function(err) {
  console.log("Require failed! ", err);

});
