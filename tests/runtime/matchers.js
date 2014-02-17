
define(["../../lib/js-numbers/src/js-numbers"], function (jsnums) {
    console.log("loading matchers");

    function addPyretMatchers(jasmine) {
        jasmine.addMatchers({
            toHaveEmptyDict : function() {
                return (this.actual.dict !== undefined) && (Object.keys(this.actual.dict).length === 0);
            },
            toHaveNoBrands : function() {
                for(var i in this.actual) {
                  if(i.indexOf("$brand") === 0) { return false; }
                  return true;
                }
            },
            //Tests equality with ===, must be exact same
            toBeIdentical : function(expect) {
                return this.actual === expect;
            },
            toBeSameAs : function(rt, expect) {
                return rt.same(this.actual, expect);
            },
            toBigEqual : function(expect) {
                return jsnums['equals'](this.actual, jsnums.fromFixnum(expect));
            },
            //Tests equality of bignums
            toBeBig : function(expect) {
                return jsnums['equals'](this.actual, expect);
            },
            toBeSuccess : function(rt) {
                return rt.isSuccessResult(this.actual);
            }
        });
    }

    return { addPyretMatchers: addPyretMatchers };

});
