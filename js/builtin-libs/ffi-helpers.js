define(["builtin-libs/list"], function(listLib) {
  return function(RUNTIME, NAMESPACE) {
      var L = RUNTIME.getField(listLib(RUNTIME, NAMESPACE), "provide");
      return {
          makeList: function(arr) {
            var lst = RUNTIME.getField(L, "empty");
            for(var i = arr.length - 1; i >= 0; i--) {
              lst = RUNTIME.getField(L, "link").app(arr[i], lst); 
            }
            return lst;
          }
        }

    };
});
