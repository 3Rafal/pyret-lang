var PYRET = (function () {
  function makeRuntime() {
    //Base of all objects
    function PBase() {}
    function isPBase(v) { return v instanceof PBase; }
    PBase.prototype = {
      dict: {},
      brands: [],
      app: (function() { throwPyretException("Cannot apply this data type");}),
      type : 'base'
    };

    //Nothing
    function PNothing(){}
    function makeNothing() {return new PNothing();}
    PNothing.prototype = Object.create(PBase.prototype);
    function isNothing(val) {return val instanceof PNothing;}

    function PMethod(f) {
      this.method = f;
      this.brands = [];
    }
    function makeMethod(f, doc) { 
        var meth =  new PMethod(f); 
        meth.dict = {};
        meth.dict["_doc"] = makeString(doc);
        
        var _fun = new PMethod((function(me) {
            return  makeFunction(me.method, me.dict._doc);
        }));
        _fun.dict = {};
        _fun.dict["_doc"] = makeString("");
        _fun.dict["_fun"] = _fun;

        meth.dict._fun = _fun;

        return meth;
    } 
    function isMethod(v) { return v instanceof PMethod; }
    PMethod.prototype = Object.create(PBase.prototype);
    PMethod.prototype.app = function() { throwPyretException( "Cannot apply method directly."); };
    PMethod.prototype.getType = function() {return 'method';};
    PMethod.prototype.clone = (function() {
        newMet = makeMethod(this.method);
        return newMet;
return     });
    PMethod.prototype.toString = function() {return 'fun ... end'}

    //Throws An Error
    function throwPyretException(message){
       throw makeObj({'message' : makeString(String(message))});
    }

    //Checks to see that an object is a function and returns it, raises error otherwise
    function checkFun(o) {
        if(isFunction(o)) {return o;}
        throwPyretException( 'check-fun: expected function, got ' + o.getType());
    }

    //Wraps to ensure # arguments correct
    //Broken
   var checkArgs= function(fn) {
       return function() {
           if (arguments.length < fn.length) {
                throw(["Expected", fn.length, "arguments, but got", arguments.length, ". The ", arguments.length ,
                    (arguments.length > 1 ? " arguments provided were" : "argument provided was"), ].join(" "));
                    }
                    return fn.apply(this, arguments);
                };
   } 
    
    function PFunction(f) {
      this.app = f;
      this.brands = [];
    }
    function makeFunction(f,doc) { 
        var fun = new PFunction(f); 
        fun.dict ={};
        fun.dict._doc = doc;
        fun.dict._method = makeMethod(function(me) {
            return makeMethod(me.app, me.dict._doc);
        });

        return fun;
    }
    function isFunction(v) { return v instanceof PFunction; }
    PFunction.prototype = Object.create(PBase.prototype);
    PFunction.prototype.getType = (function() {return 'function';});
    PFunction.prototype.toString = function() {return 'fun(): end'}
    PFunction.prototype.clone = (function() {
        var newFun = makeFunction(this.app);
        return newFun;
    });
        

    function typeCheck(arg1, type1, arg2, type2, name){
        if (!(type1(arg1) && type2(arg2))) {
            raiseTypeError(arg1,arg2, name);
        }
        return;
    }

    function raiseTypeError(arg1, arg2, name) {
        throwPyretException("Bad args to prim: " + name +" : " + arg1.toString() + ", " + arg2.toString());
    }


    /**********************************
    * Numbers
    ***********************************/
    function checkBothNum(arg1, arg2, fname) {
        typeCheck(arg1, isNumber, arg2, isNumber, fname);
        return;
    }

    var numberDict = {
      _add: makeMethod(function(left, right) {
        checkBothNum(left, right, 'plus');
        return makeNumber(left.n + right.n);
      }),
      _plus: makeMethod(function(left, right) {
        checkBothNum(left, right, 'plus');
        return makeNumber(left.n + right.n);
      }),
      _minus: makeMethod(function(left, right) {
        checkBothNum(left, right, 'minus');
        return makeNumber(left.n - right.n);
      }),
      _divide: makeMethod(function(left, right) {
        checkBothNum(left, right, 'divide');
        if(right.n === 0) {throwPyretException('Division by zero');}
        return makeNumber(left.n / right.n);
      }),
      _times: makeMethod(function(left, right) {
        checkBothNum(left, right, 'times');
        return makeNumber(left.n * right.n);
      }),
      _lessthan: makeMethod(function(left, right) {
        checkBothNum(left, right, 'lessthan');
        return makeBoolean(left.n < right.n);
      }),
      _greaterthan: makeMethod(function(left, right) {
        checkBothNum(left, right, 'greaterthan');
        return makeBoolean(left.n > right.n);
      }),
      _lessequal: makeMethod(function(left, right) {
        checkBothNum(left, right, 'lessequal');
        return makeBoolean(left.n <= right.n);
      }),
      _greaterequal: makeMethod(function(left, right) {
        checkBothNum(left, right, 'greaterequal');
        return makeBoolean(left.n >= right.n);
      }),
      max: makeMethod(function(left, right) {
        checkBothNum(left, right, 'max');
        return makeBoolean(Math.max(left.n, right.n));
      }),
      min: makeMethod(function(left, right) {
        checkBothNum(left, right, 'min');
        return makeBoolean(Math.min(left.n, right.n));
      }),
      abs: makeMethod(function(left, right) {
        checkBothNum(left, right, 'abs');
        return makeBoolean(Math.abs(left.n, right.n));
      }),
      modulo: makeMethod(function(left, right) {
        checkBothNum(left, right, 'modulo');
        return makeBoolean(left.n % right.n);
      }),
      tostring : makeMethod(function(me) {
        return makeString(String(me.n));
      }),
      _torepr : makeMethod(function(me) {
        return makeString(String(me.n));
      }),
      floor : makeMethod(function(me) {
        return makeNumber(Math.floor(me.n).toFixed(1));
      }),
      ceiling : makeMethod(function(me) {
        return makeNumber(Math.ceil(me.n).toFixed(1));
      }),
      exp: makeMethod(function(me) {
        return makeNumber(Math.exp(me.n));
      }),
      expt: makeMethod(function(me, pow) {
        return makeNumber(Math.pow(me.n, pow.n));
      }),
      _equals: makeMethod(function(me, other) {
        return makeBoolean(me.n === other.n);
      }),
      sin : makeMethod(function(me) {
        return makeNumber(Math.sin(me.n));
      }),
      cos : makeMethod(function(me) {
        return makeNumber(Math.cos(me.n));
      }),
      tan : makeMethod(function(me) {
        return makeNumber(Math.tan(me.n));
      }),
      asin : makeMethod(function(me) {
        return makeNumber(Math.asin(me.n));
      }),
      acos : makeMethod(function(me) {
        return makeNumber(Math.acos(me.n));
      }),
      atan : makeMethod(function(me) {
        return makeNumber(Math.atan(me.n));
      }),
      sqr : makeMethod(function(me) {
        return makeNumber(Math.pow(me.n,2));
      }),
      sqrt : makeMethod(function(me) {
        return makeNumber(Math.sqrt(me.n));
      }),
      truncate : makeMethod(function(me) {
        return makeNumber(Math.round(me.n));
      }),
      exact : makeMethod(function(me) {
        return makeNumber(me.n);
      }),
      log : makeMethod(function(me) {
        return makeNumber(Math.log(me.n));
      }),
    };

    function PNumber(n) {
      this.n = n;
      this.brands = [];
    }
    function makeNumber(n) { return new PNumber(n); }
    function isNumber(v) { return v instanceof PNumber; }
     PNumber.prototype = Object.create(PBase.prototype);
     PNumber.prototype.dict=  numberDict;    
     PNumber.prototype.toString = (function() {return String(this.n);});
     PNumber.prototype.clone = (function() {
        var newNum = makeNumber(this.n);
        return newNum;
     });
     PNumber.prototype.getType = function(){return 'number';};


    /**********************************
    * Strings
    ***********************************/

    var stringDict = {
      _plus: makeMethod(function(left, right) {
        return makeString(left.s + right.s);
      }),
      tostring : makeMethod(function(me) {
        return makeString(me.s);
      }),
      contains: makeMethod(function(me, sub){
        return makeBoolean(me.s.indexOf(sub) != -1);
      }),
      'char-at': makeMethod(function(me, n) {
        return makeString(String(me.s.charAt(n)));
      }),
      replace: makeMethod(function(me, forStr, withStr) {
          return makeString(me.s.replace(new RegExp(forStr,"g"), withStr));
      }),
      tonumber: makeMethod(function(me) {
          toNum = Number(me.s);
          if(!isNaN(toNum)) {
            return makeNumber(Number(me.s));
          }
          else {
              return makeNothing();
          }
      }),
      substring: makeMethod(function(me, start, stop) {
        return makeString(me.s.substring(start,stop));
      }),
      append : makeMethod(function(me, o) {
        return makeString(me.s + o.s);
      }),
      length : makeMethod(function(me) {
        return makeNumber(me.s.length);
      }),
      repeat : makeMethod(function(me, n) {
        var result = "";i
        for(var x = n.n; x>0; n.n--){
           result = result + me.s;
        }
        return makeString(result);
      }),

      _greatereqaul : makeMethod(function(me, n) {
        return makeBoolean(me.s >= n.s);
      }),
      _greaterthan : makeMethod(function(me, n) {
        return makeBoolean(me.s > n.s);
      }),
      _lessequal : makeMethod(function(me, n) {
        return makeBoolean(me.s <= n.s);
      }),
      _lessthan : makeMethod(function(me, n) {
        return makeBoolean(me.s < n.s);
      }),
      _equals : makeMethod(function(me, x) {
        return makeBoolean(me.s === x.s);
      }),
      _torepr : makeMethod(function(me) {
          return '"'+me.s+'"';
      }),
    };

    function PString(s) {
      this.s = s;
      this.brands = [];
    }
    function makeString(s) { return new PString(s); }
    function isString(v) { return v instanceof PString; }
    PString.prototype = Object.create(PBase.prototype);
    PString.prototype.dict = stringDict;
    PString.prototype.toString = (function() {return this.s;});
    PString.prototype.clone = (function() {
        var newStr = makeString(this.s);
        return newStr;
     });
    PString.prototype.getType = function() {return 'string';};

    /**********************************
    * Booleans
    ***********************************/
    var booleanDict = {
        _and : makeMethod(function(left, right) {
            if(!isBoolean(left)) {
                raiseTypeError(left, right, 'and');
            }
            if(left.b) {
                var rightVal = right.app();
                if(!isBoolean(rightVal)) {
                    raiseTypeError(left, right, 'and');
                }
                return makeBoolean(rightVal.b);
            }
            else {
                return makeBoolean(false);
            }
        }),

        _or : makeMethod(function(left, right) {
            if(!isBoolean(left)) {
                raiseTypeError(left, right, 'or');
            }
            if(left.b) {
                return makeBoolean(true);
            }
            else {
                var rightVal = right.app();
                if(!isBoolean(rightVal)) {
                    raiseTypeError(left, right, 'or');
                }
                return makeBoolean(rightVal.b);
            }
        }),

      _not: makeMethod(function(me) {
        return makeBoolean(!(me.b));
      }),

      _tostring: makeMethod(function(me) {
       return toRepr(me); 
      }),   
      _torepr: makeMethod(function(me) {
       return makeString(String(me.b)); 
      }),   
      _equals: makeMethod(function(me, other) {
        if(!(isBoolean(other))){return makeBoolean(false);}
       return makeBoolean(me.b === other.b); 
      }),   
    };

    //Checks that something is a boolean, returns its boolean value
    function checkBool(b) {
        if(isBoolean(b)) {
            return b.b;
        }
        else {
            throwPyretException('check-bool: expected boolean, got ' + b.getType());
        }
    }
        
    function PBoolean(b) {
      this.b = b;
      this.brands = [];
    }
    function makeBoolean(b) { return new PBoolean(b); }
    function isBoolean(v) { return v instanceof PBoolean; }
    PBoolean.prototype = Object.create(PBase.prototype);
    PBoolean.prototype.dict = booleanDict;
    PBoolean.prototype.toString = (function() {return String(this.b);});
    PBoolean.prototype.clone = (function() {
        var newBool = makeBoolean(this.b);
        return newBool;
    });
    PBoolean.prototype.getType = function() {return String(this.b);};

    function equal(val1, val2) {
      if(isNumber(val1) && isNumber(val2)) {
        return val1.n === val2.n;
      }
      else if (isString(val1) && isString(val2)) {
        return val1.s === val2.s;
      }
      else if (isBoolean(val1) && isBoolean(val2)) {
        return val1.b === val2.b;
      }
      return val1 === val2;
    }

    function toRepr(val) {
      if(isNumber(val)) {
        return makeString(String(val.n));
      }
      else if (isString(val)) {
        return makeString('"' + val.s + '"');
      }
      else if(isBoolean(val)) {
        return makeString(String(val.b));
      }
      else if (isFunction(val)) {
        return makeString("fun(): end");
      }
      else if (isMethod(val)) {
        return makeString("method: end");
      }
      else if(isLink(val)) {
        var rep = "[" ;
        var items  = [];
        var remain = val;
        do {
            items.push(toRepr(remain.dict.first).s)
            remain = remain.dict.rest;
        } while(!isEmpty(remain));
        rep += items.join(", ") + "]";
        return makeString(rep);
      }
      else if(isEmpty(val)) {
        return makeString("[]");
      }
      else if (isObj(val)) {
        if(val.isPlaceholder) {
            return makeString("cyclic-field");
        }
        
        if(val.dict.hasOwnProperty('_torepr')) {
            return getField(val, 'torepr').app();
        }

        var fields = [];
        for(f in val.dict) {
            fields.push(f + ": " + val.dict[f].toString());
        }
        return makeString('{' +fields.join(", ")+ '}');
      }
      else if(isNothing(val)) {//Nothing
        return makeString("nothing");
      }
      throwPyretException("toStringJS on an unknown type: " + val);
    }

    function getField(val, str) {
      var fieldVal = val.dict[str];
      if (isMethod(fieldVal)) {
        return makeFunction(function() {
          var argList = Array.prototype.slice.call(arguments);
          return fieldVal.method.apply(null, [val].concat(argList));
        });
      } else {
        if(fieldVal === undefined) {
            throwPyretException(str + " was not found on " + toRepr(val).s);
        }
        if(fieldVal.isMutable) {    
            throwPyretException('Cannot look up mutable field "'+ str +'" using dot or bracket');
        }
        if(fieldVal.isPlaceholder) {    
            return getField(fieldVal, 'get').app();
        }
        return fieldVal;
      }
    }
    function getColonField(val, str) {
      var fieldVal = val.dict[str];
        if(fieldVal === undefined) {
            throwPyretException(str + " was not found on " + toRepr(val).s);
        }
        return fieldVal;
      }
    function getMutField(val, str) {
      var fieldVal = val.dict[str];
      if (isMethod(fieldVal)) {
        return makeFunction(function() {
          var argList = Array.prototype.slice.call(arguments);
          return fieldVal.method.apply(null, [val].concat(argList));
        });
      } else {
        if(fieldVal === undefined) {
            throwPyretException(str + " was not found on " + toRepr(val).s);
        }
        return fieldVal;
      }
    }

    var testPrintOutput = "";
    function testPrint(val) {
      var str = toRepr(val).s;
      console.log("testPrint: ", val, str); testPrintOutput += str + "\n";
      return val;
    }

    function NormalResult(val, namespace) {
      this.val = val;
      this.namespace = namespace;
    }
    function makeNormalResult(val, ns) { return new NormalResult(val, ns); }

    function FailResult(exn) {
      this.exn = exn;
    }
    function makeFailResult(exn) { return new FailResult(exn); }

    function errToJSON(exn) {if(isObj(exn)){return  exn.dict['message'].s;} else {var res = exn.s; if(res === undefined) {return exn;} return res;}}

    /**********************************
    * Objects
    ***********************************/
    function PObj(d) {
      this.dict = d;
      this.brands = [];
      //this.dict['_torepr'] = makeMethod(function(me) {
        //return toRepr(me);
      //});
    }
    function makeObj(b) { return new PObj(b); }
    function isObj(v) { return v instanceof PObj; }
    PObj.prototype = Object.create(PBase.prototype);
    PObj.prototype.clone = (function() {
        //We don't need to do deep cloning, but we *do* need to clone the dict
        var newDict = {};
        for(var key in this.dict) {
            newDict[key] = this.dict[key];
        }
        var newObj = makeObj(newDict);
        return newObj;
    });
    PObj.prototype.getType = function() {return 'object';};
    PObj.prototype.extendWith = function(fields) {
        var newObj = this.clone();
        var allNewFields = true;
        for(var field in fields) {
            if(newObj.dict.hasOwnProperty(field)) {
               allNewFields = false;
            }
            newObj.dict[field] = fields[field];
        }
        newObj.brands = [];
        if(allNewFields) {
            for(var brand in this.brands){
                newObj.brands[brand] = this.brands[brand];
            }
        }

        return newObj;
    }
    PObj.prototype.updateWith = function(fields) {
        var newObj = this; //Don't clone, this is mutation
        for(var field in fields) {
            if(newObj.dict[field].isMutable) {
                newObj.dict[field].set(fields[field]);
            }
            else throwPyretException("Attempted to update a non-mutable field");
        }
        return newObj;
    }
    PObj.prototype.toString = function() {
        var fields = "";
        for(var f in this.dict) {
            fields += f + ": " + dict[f].toString();
        }
        return '{' +fields+ '}';
    }

    /**********************************
    * Builtins
    ***********************************/
    //Brander
    var brandCount = 0;
    brander = makeFunction(function() {
    var myBrand = brandCount++; 
    var branderDict = {
        brand: makeFunction(function(toBrand) {
            var newO = toBrand.clone();
            newO.brands = toBrand.brands.slice(0);
            newO.brands.push(myBrand);
            return newO;
        }),
        test: makeFunction(function(o) {
            return makeBoolean(o.brands.indexOf(myBrand) != -1);
        }),
    };
    return makeObj(branderDict);
    });

    //Raise
    raise = makeFunction(function(expr) {
        throwPyretException(expr); });

    //Error
    errorDict = {
        'make-error' : makeFunction(function(s) {
            //Assuming s is a Pyret Exception
            return s.exnVal;
        })
    };
    error = makeObj(errorDict);

    //check-brand
    checkBrand = makeFunction(function(test, obj, msg){
        if(isFunction(test)){
            if(test.app(obj).b) {
                return obj;
            }
            else {
               throwPyretException("typecheck failed; expected " + msg  + " and got\n" + toRepr(obj).s); 
            }
        }
        else {
            throwPyretException("Check brand with non-function");
        }
    });

    //Placeholder
    var makePlaceholder = makeFunction(function() {
        var isSet = false;
        var value = undefined;
        var guards = [];
        function getPlaceholderDict(){  return {
            get : makeMethod(function(me) { 
               if(isSet){
                   return value;
               }
               else {
                  throwPyretException("Tried to get value from uninitialized placeholder");
               }
            }),

            guard : makeMethod(function(me, guard) {
               if(isSet) {
                   throwPyretException("Tried to add guard on an already-initialized placeholder");
                }
               else {
                    guards.push(guard);
               }
               return {};
            }),

            set : makeMethod(function(me, val) {
                if(isSet) {
                    throwPyretException("Tried to set value in already-initialized placeholder");
                }
                for(var g in guards) {
                    var test = guards[g].app(val);
                    if(isBoolean(test)) {
                        if(!test.b) {
                        throwPyretException("Guard failed");
                        }
                    }
                    else {
                        throwPyretException("Test did not result in boolean");
                    }
                }
                value = val;
                isSet = true;
                return value;
            }),

           tostring : makeMethod(function(me) {
            return makeString("cyclic-field");
           }),

           _torepr : makeMethod(function(me) {
                return makeString("cyclic-field");
            }),
            
           _equals : makeMethod(function(me,other) {
                return makeBoolean(me === other);  
           }),
        };}
        
        var obj = makeObj(getPlaceholderDict());
        obj.isPlaceholder = true;
        obj.clone = (function() {
            //We don't need to do deep cloning, but we *do* need to clone the dict
            var newDict = {};
            for(var key in this.dict) {
                newDict[key] = this.dict[key];
            }
            var newObj = makeObj(newDict);
            newObj.isPlaceholder = true;
            return newObj;
         });
        return obj;
    });

    var mutClone = function(val, r, w) {
        return function clone() {
            //We don't need to do deep cloning, but we *do* need to clone the dict
            var newDict = {};
            for(var key in this.dict) {
                newDict[key] = this.dict[key];
            }
            var newObj = makeObj(newDict);
            
            newObj.isMutable = true;
            
           newObj.set = (function(newVal) { 
            var  wVal = w.app(newVal);
            if(!(isBoolean(wVal) && wVal.b)) {
                throwPyretException('Predicate failed upon set');
            }
                return a = newVal;
            });
            
           newObj.r = r;
           newObj.w = w;
           newObj.a = val;

           newObj.clone = clone;
           return newObj;
    }
};
    //Muteable
    function makeMutable(val, r, w) {
        var a = val;

        if(!isFunction(r)) {
            throwPyretException('typecheck failed; expected Function and got\n' + toRepr(r).s);
        }
        if(!isFunction(w)) {
            throwPyretException('typecheck failed; expected Function and got\n' + toRepr(w).s);
        }

        var mut = makeObj({
            tostring: makeMethod(function(me) {
            return makeString("mutable-field");
            }),
            'get': makeMethod(function(me) {
            
            var  readVal = r.app(a);
            if(!(isBoolean(readVal) && readVal.b)) {
                throwPyretException('Predicate failed upon read ');
            }
                return a;
            }),

            '_equals' : makeMethod(function(me, other) {
                return makeBoolean(me === other);
            }),
        });

        mut.set = (function(newVal) { 
            var  wVal = w.app(newVal);
                throwPyretException('Predicate failed upon set');
                return (a = newVal);
            });

        mut.isMutable = true;
        
        mut.clone = mutClone(val, r,w);
        return mut;
    };


    function isMutable(val) {
        return makeBoolean(Boolean(val.isMutable));
    }

    var alwaysTrue = makeFunction(function() {return makeBoolean(true);});
    function makeSimpleMutable(val) {return makeMutable(val,alwaysTrue, alwaysTrue);}

    //List
    function PList() {
      this.brands = [];
    }
    function makeList() { return new PList(); }
    function isList(v) { return v instanceof PList; }
    PList.prototype = Object.create(PObj.prototype);
   
    function Empty() {this.dict = {}; this.brands=[];}
    Empty.prototype = Object.create(PList.prototype);
    function makeEmpty() {
        var e = new Empty(); 
        e.dict ={ 
            length : makeMethod(function(me) {
            return makeNumber(0);
            }),
            _plus : makeMethod(function(me, toConcat) {
                return me.concat(toConcat);
            }),
        
            map : makeMethod(function(me,f) {
                return makeEmpty();
            }),

            _equals : makeMethod(function(me, other) {
                return makeBoolean(isEmpty(other));
            }),

            'is-empty' : makeBoolean(true),
            'is-link' :  makeBoolean(false),
        };
        
        e.concat = function concat(toConcat) {
        return toConcat;
        };
        return e;
    }
    function isEmpty(v) {
        return v instanceof Empty;
    }

    function Link(f,r) {
        this.dict = {};
        this.dict.first = f;
        this.dict.rest = r;
        this.brands = [];
    }
    Link.prototype = Object.create(PList.prototype);
    function makeLink(f, r) {
        var e = new Link(f,r);
        
        e.dict.length = makeMethod(function(me) {
        return makeNumber(1 + me.dict['rest']['length'].method(me['dict']['rest']).n);
        });

        e.dict._plus = makeMethod(function(me, toConcat) {
            return me.concat(toConcat);
        });

        
        e.concat = function concat(toConcat) {
                return makeLink(this.dict.first, this.dict.rest.concat(toConcat));
        }
    
        e.dict.map = makeMethod(function(me, f) {
            checkFun(f);

            return makeLink(f.app(me.dict.first), me.dict.rest.dict.map.method(me.dict.rest, f));
        });

        e.dict._equals = makeMethod(function(me, other) {
            if(!(isLink(other))) 
                {return makeBoolean(false);}
            if(equiv(me.dict.first, other.dict.first)) {
                return equiv(me.dict.rest, other.dict.rest);
            }
            else {
                return makeBoolean(false);
            }
        });


        e.dict['is-empty'] =makeBoolean(false);
        e.dict['is-link'] = makeBoolean(true);
        return e;
      }

    function isLink(v) {
        return v instanceof Link;
    }
    function PyretException(exnVal) {
      this.exnVal = exnVal;
    }
    function makePyretException(exnVal) {
      return new PyretException(exnVal);
    }
    function throwPyretException(exnVal) {
      throw makePyretException(exnVal);
    }

    function errToJSON(exn) {
      return JSON.stringify({exn: String(exn)})
    }

    listDict  = {
        //empty : makeMethod(function(me) {
            //return makeEmpty(); 
        //}),
        empty : makeEmpty(),
        link : makeMethod(function(me, f, r) {
            return makeLink(f,r); 
        }),
    }
    var list = makeObj(listDict);

    //Equiv
    function equiv(obj1, obj2) {
        if(obj1.dict.hasOwnProperty("_equals")) {
            return getField(obj1, "_equals").app(obj2);
        }
        else if(Object.keys(obj1.dict).length == Object.keys(obj2.dict).length) { return makeBoolean(isAllSame(obj1, obj2));}
        else {return makeBoolean(false);}
    }

    function isAllSame(obj1, obj2) {
        if(isMethod(obj1) || isFunction(obj1)) {
            return false;
        }
       
        for(key in obj1.dict){
            if(obj2.dict.hasOwnProperty(key)) {
                if(!(equiv(obj1.dict[key], obj2.dict[key]).b)) {
                    return false;
                }
            }
            else {
                return false;
            }
        }

        return true;
    }  /* 
    return 
      nothing: makeNothing(),
      makeNumber: makeNumber,
      makeString: makeString,
      makeBoolean: makeBoolean,
      isNumber: isNumber,
      isString: isString,
      isBoolean: isBoolean,
      checkBool: checkBool,
      
      makeFunction: makeFunction,
      isFunction: isFunction,
      checkFun: checkFun,

      makeMethod: makeMethod,
      isMethod: isMethod,

      makeObj: makeObj,
      isObj: isObj,
     
      //Builtins
      brander:brander,
      raise:raise,
      error:error,

      //Builtins Obj
      builtins : makeObj(
      {
      equiv: makeFunction(equiv),

      "has-field" : makeFunction(function(prim, field) {
        return makeBoolean(prim.dict.hasOwnProperty(field));
      }),
    
      }),

      equal: equal,
      getField: getField,
      getMutField: getMutField,
      getColonField: getColonField,
      getTestPrintOutput: function(val) {
        return testPrintOutput + toRepr(val).s;
      },
      NormalResult: NormalResult,
      FailResult: FailResult,
      makeNormalResult: makeNormalResult,
      makeFailResult: makeFailResult,
      toReprJS: toRepr,
      errToJSON: errToJSON,

      ids:{},

     "test-print": makeFunction(testPrint),

      "is-number": makeFunction(function(x){return makeBoolean(isNumber(x));}),
      "is-string": makeFunction(function(x){return makeBoolean(isString(x));}),
      "is-bool": makeFunction(function(x){return makeBoolean(isBoolean(x));}),
      "is-function": makeFunction(function(x){return makeBoolean(isFunction(x));}),
      "is-method": makeFunction(function(x){return makeBoolean(isMethod(x));}),
//      "to-string": makeFunction(function(x){return makeString(x.toString());}),
      "is-mutable" : makeFunction(isMutable),
      "is-placeholder" : makeFunction(function(x) {return makeBoolean(Boolean(x.isPlaceholder));}),
      "check-brand": checkBrand,
      "mk-placeholder": makePlaceholder,
      "mk-mutable": makeFunction(makeMutable),
      "mk-simple-mutable": makeFunction(makeSimpleMutable),
      "Number": makeFunction(function(x){return makeBoolean(isNumber(x));}),
      "String": makeFunction(function(x){return makeBoolean(isString(x));}),

      "list" : list,
      "link" : makeFunction(makeLink),
      "empty" :makeFunction(makeEmpty),

      "List" : makeFunction(function(x){return makeBoolean(isList(x));}),
      "Empty" : makeFunction(function(x){return makeBoolean(isEmpty(x));}),
      "Link" : makeFunction(function(x){return makeBoolean(isLink(x));}),
      "is-list" : makeFunction(function(x){return makeBoolean(isList(x));}),
      "is-empty" : makeFunction(function(x){return makeBoolean(isEmpty(x));}),
      "is-link" : makeFunction(function(x){return makeBoolean(isLink(x));}),
      "torepr" : makeFunction(toRepr),
      "tostring" : makeFunction(function(x) {
        return getField(x, 'tostring').app();
      }), 
      "prim-has-field" : makeFunction(function(prim, field) {
        return makeBoolean(prim.dict.hasOwnProperty(field));
      }),
      "prim-num-keys" : makeFunction(function(prim) {
          if(isNothing(prim)) {return makeNumber(0);}
        return makeNumber(Object.keys(prim.dict).length);
      }),
      "prim-keys" : makeFunction(function(prim) {
        var myKeys = makeEmpty();
        for(key in prim.dict) {
            myKeys = makeLink(makeString(String(key)), myKeys);
        }
        return myKeys;
      }),
=======*/
    return{
      namespace: Namespace({
        nothing: {},
        "torepr" : makeFunction(toRepr),
        "test-print": makeFunction(testPrint),
         brander:brander,
        "check-brand": checkBrand,
        'Function': makeFunction(function(obj) {
            return makeBoolean(isFunction(obj));
            //TODO: what does function do?
        }),
        'Number': makeFunction(function(x){return makeBoolean(isNumber(x));}),
        'String': makeFunction(function(x) {
            return makeBoolean(isString(x)); //TODO: Implement with toString
        }),
        builtins: makeObj({
            'Eq': makeFunction(function(){
                var b = brander.app();
                return makeObj(
                    {
                        brand: makeFunction(function(obj){
                                return getField(b,'brand').app(obj);
                        }),
                        extend: makeFunction(function(obj){
                            return obj.extendWith({
                            'eq': makeMethod(function(me, other){
                                    return makeBoolean(getField(b,'test').app(me).b && getField(b, 'test').app(other).b);
                                },""),
                            });
                        }),
                    }); 
            }),
            
            equiv: makeFunction(equiv),

            "has-field" : makeFunction(function(prim, field) {
              return makeBoolean(prim.dict.hasOwnProperty(field));
              }),
        }),
        //Raise
          raise: raise,
        //is-*
          "is-number": makeFunction(function(x){return makeBoolean(isNumber(x));}),
          "is-string": makeFunction(function(x){return makeBoolean(isString(x));}),
          "is-bool": makeFunction(function(x){return makeBoolean(isBoolean(x));}),
          "is-function": makeFunction(function(x){return makeBoolean(isFunction(x));}),
          "is-method": makeFunction(function(x){return makeBoolean(isMethod(x));}),
          "is-mutable" : makeFunction(function(x) {return makeBoolean(Boolean(x.isMutable));}),
          "is-placeholder" : makeFunction(function(x) {return makeBoolean(Boolean(x.isPlaceholder));}),
          "is-object" : makeFunction(function(x) {return makeBoolean(isObj(x));}),
          "prim-num-keys" : makeFunction(function(prim) {
              if(isNothing(prim)) {return makeNumber(0);}
            return makeNumber(Object.keys(prim.dict).length);
          }),
          "prim-keys" : makeFunction(function(prim) {
            var myKeys = makeEmpty();
            for(key in prim.dict) {
                myKeys = makeLink(makeString(String(key)), myKeys);
            }
            return myKeys;
      }),
      "prim-has-field" : makeFunction(function(prim, field) {
        return makeBoolean(prim.dict.hasOwnProperty(field));
      }),
      "tostring" : makeFunction(function(x) {
        return getField(x, 'tostring').app();
      }), 

      "mk-placeholder": makePlaceholder,
      "mk-mutable": makeFunction(makeMutable),
      "mk-simple-mutable": makeFunction(makeSimpleMutable),
      equiv: makeFunction(equiv),
      list: list,
      error: error,
      }),
      runtime: {
        makeNumber: makeNumber,
        isNumber: isNumber,
        equal: equal,
        getField: getField,
        getTestPrintOutput: function(val) {
          return testPrintOutput + toRepr(val).s;
        },
        NormalResult: NormalResult,
        FailResult: FailResult,
        PyretException: PyretException,
        makeNormalResult: makeNormalResult,
        makeFailResult: makeFailResult,
        makePyretException: makePyretException,
        toReprJS: toRepr,
        errToJSON: errToJSON,
        
        //prims
          makeString: makeString,
          makeBoolean: makeBoolean,
          isNumber: isNumber,
          isString: isString,
          isBoolean: isBoolean,
          checkBool: checkBool,
          
          makeFunction: makeFunction,
          isFunction: isFunction,
          checkFun: checkFun,

          makeMethod: makeMethod,
          isMethod: isMethod,

          makeObj: makeObj,
          isObj: isObj,
        //etc
          equal: equal,
          getField: getField,
          getMutField: getMutField,
          getColonField: getColonField,
      }
    }
  }

  return {
    makeRuntime: makeRuntime
  };
})();
