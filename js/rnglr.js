const assert = require('assert');
const cycle = require('./cyclicJSON.js');



function SrcLoc(startRow, startCol, startChar, endRow, endCol, endChar) {
  this.startRow = startRow;
  this.startCol = startCol;
  this.startChar = startChar;
  this.endRow = endRow;
  this.endCol = endCol;
  this.endChar = endChar;
}
SrcLoc.cache = {};
SrcLoc.make = function(startRow, startCol, startChar, endRow, endCol, endChar) {
  var byStartChar = SrcLoc.cache[startChar];
  if (byStartChar === undefined)
    byStartChar = SrcLoc.cache[startChar] = {};
  var byEndChar = byStartChar[endChar];
  if (byEndChar === undefined)
    byEndChar = byStartChar[endChar] = new SrcLoc(startRow, startCol, startChar, endRow, endCol, endChar);
  return byEndChar;
}
SrcLoc.prototype.toString = function(show_span) {
  var ret = this.startRow + ":" + this.startCol;
  if (show_span)
    ret += "-" + this.endRow + ":" + this.endCol;
  return ret;
}
SrcLoc.prototype.combine = function(that, inPlace) {
  assert.notEqual(that, undefined, "Can't combine " + this + " with undefined");
  if (inPlace) {
    if (this.startChar > that.startChar) {
      this.startChar = that.startChar;
      this.startRow = that.startRow;
      this.startCol = that.startCol;
    }
    if (this.endChar < that.endChar) {
      this.endChar = that.endChar;
      this.endRow = that.endRow;
      this.endCol = that.endCol;
    }
    return this;
  } else {
    if (this.startChar < that.startChar) {
      if (this.endChar < that.endChar) {
        return SrcLoc.make(this.startRow, this.startCol, this.startChar, that.endRow, that.endCol, that.endChar);
      } else {
        return SrcLoc.make(this.startRow, this.startCol, this.startChar, this.endRow, this.endCol, this.endChar);
      }
    } else {
      if (this.endChar < that.endChar) {
        return SrcLoc.make(that.startRow, that.startCol, that.startChar, that.endRow, that.endCol, that.endChar);
      } else {
        return SrcLoc.make(that.startRow, that.startCol, that.startChar, this.endRow, this.endCol, this.endChar);
      }
    }
  }
}
SrcLoc.prototype.posAtStart = function() { 
  return SrcLoc.make(this.startRow, this.startCol, this.startChar, this.startRow, this.startCol, this.startChar);
}
SrcLoc.prototype.posAtEnd = function() { 
  return SrcLoc.make(this.endRow, this.endCol, this.endChar, this.endRow, this.endCol, this.endChar);
}

//////////////////////////////////
////////// Ordered Sets //////////
//////////////////////////////////

function OrderedSet(items, comparison) {
  this.elements = {};
  this.ordered = [];
  this.comparison = comparison
  if (items instanceof OrderedSet) {
    if (!this.comparison)
      this.comparison = items.comparison;
    for (var i = 0; i < items.ordered.length; i++)
      this.add(items.ordered[i]);
  } else if (items) {
    for (var i = 0; i < items.length; i++)
      this.add(items[i]);
  }
}
OrderedSet.fromSerializable = function(obj, comparison, f) {
  var ret = new OrderedSet([], comparison);
  for (var i = 0; i < obj.length; i++) {
    if (f)
      ret.add(f(obj[i]));
    else
      ret.add(obj[i]);
  }
  return ret;
}
OrderedSet.equals = function orderedSetEquals(thiz, that) {
  if (thiz.size() !== that.size()) return false;
  for (var i = 0; i < thiz.ordered.length; i++)
    if (!that.contains(thiz.ordered[i]))
      return false;
  return true;
}
OrderedSet.prototype.toString = function(sep_lines, sorted) {
  var s = "";
  var items_strs = []
  for (var i = 0; i < this.ordered.length; i++)
    items_strs[i] = this.ordered[i].toString();
  if (sorted)
    items_strs.sort();
  for (var i = 0; i < items_strs.length; i++) {
    if (s == "")
      s += "{" + items_strs[i]
    else
      s += (sep_lines ? ",\n " : ", ") + items_strs[i];
  }
  if (s == "")
    return "{}";
  return s + "}";
}
OrderedSet.prototype.equals = function(that) { return OrderedSet.equals(this, that); }
OrderedSet.prototype.contains = function(item) {
  var key = item.toString();
  if (this.elements.hasOwnProperty(key))
    return (this.indexOfHelp(this.elements[key], item) >= 0);
  return false;
}
OrderedSet.prototype.itemsByKey = function(key) {
  var items = this.elements[key];
  if (items === undefined) return items;
  return items.slice(0);
}
OrderedSet.prototype.add = function(item) {
  var key = (item.hasOwnProperty("key") ? item.key : item.toString());
  if (this.elements.hasOwnProperty(key)) {
    var items = this.elements[key];
    var index = this.indexOfHelp(items, item);
    if (index === -1) {
      items.push(item);
      this.ordered.push(item);
      return true;
    }
  } else {
    this.elements[key] = [item];
    this.ordered.push(item);
    return true;
  }
  return false;
}
OrderedSet.prototype.indexOf = function(item) {
  return this.indexOfHelp(this.ordered, item);
}
OrderedSet.prototype.indexOfHelp = function(items, item) {
  for (var i = 0; i < items.length; i++) {
    if ((this.comparison && this.comparison(items[i], item)) ||
        ((!this.comparison) && (items[i] == item))) {
      return i;
    }
  }
  return -1;
}  
OrderedSet.prototype.remove = function(item) {
  var key = (item.hasOwnProperty("key") ? item.key : item.toString());
  if (this.elements.hasOwnProperty(key)) {
    this.ordered.splice(this.indexOf(item), 1);
    this.elements[key].splice(this.indexOfHelp(this.elements[key], item), 1);
  }
  return this;
}
OrderedSet.prototype.size = function() { return this.ordered.length; }
OrderedSet.prototype.get = function(index) { return this.ordered[index]; }
OrderedSet.prototype.union = function(that) {
  var res = new OrderedSet([], this.comparison);
  for (var i = 0; i < this.ordered.length; i++)
    res.add(this.ordered[i]);
  for (var i = 0; i < that.ordered.length; i++)
    res.add(that.ordered[i]);
  return res;
}
OrderedSet.prototype.merge = function(that) {
  var ret = false;
  for (var i = 0; i < that.ordered.length; i++)
    ret = this.add(that.ordered[i]) || ret;
  return ret;
}
OrderedSet.prototype.subtract = function(that) {
  for (var i = 0; i < that.ordered.length; i++)
    this.remove(that.ordered[i]);
  return this;
}
OrderedSet.prototype.inter = function(that) {
  var ret = new OrderedSet([], this.comparison);
  var start = this;
  if (this.size() > that.size())
    start = that;
  if (start == that)
    that = this;
  for (var i = 0; i < start.ordered.length; i++)
    if (that.contains(start.ordered[i]))
      ret.add(start.ordered[i])
  return ret;
}
OrderedSet.prototype.toSerializable = function() {
  var ret = [];
  for (var i = 0; i < this.ordered.length; i++) {
    if (this.ordered[i].toSerializable)
      ret[i] = this.ordered[i].toSerializable()
    else
      ret[i] = this.ordered[i];
  }
  return ret;
}  

//////////////////////////////////
///////////// Queues /////////////
//////////////////////////////////

function Queue(items) {
  this.items = items.slice(0);
  this.start = 0;
  this.end = items.length;
  this.length = items.length;
}
Queue.prototype.push = function(item) {
  this.items[this.end] = item;
  this.end++;
  this.length++;
}
Queue.prototype.shift = function() {
  if (this.length === 0) return undefined;
  var ret = this.items[this.start];
  this.start++;
  this.length--;
  return ret;
}
Queue.prototype.get = function(idx) {
  if (this.start + idx < this.end) return this.items[this.start + idx];
  return undefined;
}
Queue.prototype.insertAt = function(idx, item) {
  if (this.start + idx < this.end) {
    this.items.splice(this.start + idx, 0, item);
    this.end++;
    this.length++;
  } else
    this.push(item);
}
Queue.prototype.debugPrint = function() { 
  console.log("********** Debug print of queue: start = " + this.start + ", end = " + this.end + ", length = " + this.length);
  for (var i = this.start; i < this.end; i++) {
    if (this.end === i) console.log("<<-- END");
    if (this.start === i) console.log("-->> START");
    if (this.items[i].hasOwnProperty("debugPrint"))
      console.log(i + ": " + this.items[i].debugPrint());
    else
      console.log(i + ": " + this.items[i].toString(true));
  }
  if (this.items.length === this.start) console.log("-->> START");
  if (this.items.length === this.end) console.log("<<-- END");
}


//////////////////////////////////
///////////// Atoms //////////////
//////////////////////////////////

function Atom() {}
Atom.equals = function(thiz, that) {
  if (thiz === that) return true;
  if ((thiz instanceof Nonterm) && (that instanceof Nonterm) && (thiz.name == that.name)) return true;
  if ((thiz instanceof Token) && (that instanceof Token) && (thiz.name == that.name)) return true;
  return false;
}
Atom.equals.toString = function() { return "Atom.equals" };
Atom.fromSerializable = function(obj) {
  if (obj === undefined) return undefined;
  if (obj.type === "Nonterm") return new Nonterm(obj.name);
  if (obj.type === "Token") return new Token(obj.name, obj.value);
  if (obj.type === "EOF") return EOF;
  if (obj.type === "EPSILON") return EPSILON;
  if (obj.type === "HASH") return HASH;
  return null;
}
function Nonterm(name) {
  this.name = name;
}
Nonterm.prototype = Object.create(Atom.prototype);
Nonterm.prototype.toString = function() { return this.name; }
function Token(name, value) {
  this.name = name;
  if (value !== undefined)
    this.value = value;
  else
    this.value = name;
}
Nonterm.prototype.toSerializable = function() { return {type: "Nonterm", name: this.name}; }
Token.prototype = Object.create(Atom.prototype);
Token.prototype.toString = function(showVal) { 
  if (showVal && this.name !== this.value)
    return "('" + this.name + " " + JSON.stringify(this.value) + ")";
  else
    return "'" + this.name; 
}
Token.prototype.toSerializable = function() { return {type: "Token", name: this.name, value: this.value}; }

const EOF = Object.create(Token.prototype, 
                          {name: {enumerable: true, value: "EOF"}, 
                           toString: {value: function() { return "$"; }},
                           toSerializable: {value: function() { return {type:"EOF"}; } }});
const EPSILON = Object.create(Atom.prototype, 
                              {name: {enumerable: true, value: "EPSILON"}, 
                               toString: {value: function() { return "ε"; }},
                               toSerializable: {value: function() { return {type:"EPSILON"}; } }});
const HASH = Object.create(Atom.prototype, 
                              {name: {enumerable: true, value: "HASH"}, 
                               toString: {value: function() { return "#"; }},
                               toSerializable: {value: function() { return {type:"HASH"}; } }});

//////////////////////////////////
//////////// Actions /////////////
//////////////////////////////////

function Action() { }
Action.equals = function actionEquals(thiz, that) {
  return (thiz.type === that.type && Rule.equals(thiz.rule, that.rule) && thiz.dest == that.dest);
}
Action.equals.toString = function() { return "Action.equals"; }
Action.prototype.toSerializable = function() { return this.toString(true); }
Action.fromSerializable = function (rulesByOldId) { return function(str) {
  if (str === undefined) return undefined;
  var parts = str.split(" ");
  if (parts[0] === "Reduce") return new ReduceAction(rulesByOldId[parts[1]], parts[2]);
  if (parts[0] === "Push") return new PushAction(parseInt(parts[1]));
  if (parts[0] === "Accept") return new AcceptAction();
  return null;
} }
function ReduceAction(rule, f) {
  this.type = "Reduce";
  this.rule = rule;
  this.f = f;
  assert.notEqual(f, undefined, "Bad f value for rule " + rule);
}
ReduceAction.prototype = Object.create(Action.prototype);
ReduceAction.prototype.toSerializable = function() { return "Reduce " + this.rule.id; }
ReduceAction.prototype.toString = function(hideRule) { 
  if (hideRule)
    return "Reduce " + this.rule.id;
  else
    return "Reduce(" + this.rule.id + ":" + this.rule.asString + ", m" + this.rule.position + ", f" + this.f + ")";
}
ReduceAction.prototype.equals = function(that) { return (that instanceof ReduceAction) && (this.rule == that.rule); }
function PushAction(dest) {
  this.type = "Push";
  this.dest = dest;
}
PushAction.prototype = Object.create(Action.prototype);
PushAction.prototype.toString = function() { return "Push " + this.dest; }
PushAction.prototype.equals = function(that) { return (that instanceof PushAction) && (this.dest == that.dest); }
function AcceptAction() {
  this.type = "Accept";
}
AcceptAction.prototype = Object.create(Action.prototype);
AcceptAction.prototype.toString = function() { return "Accept"; }
AcceptAction.prototype.equals = function(that) { return (that instanceof AcceptAction); }

//////////////////////////////////
///////////// Rules //////////////
//////////////////////////////////

// name :: string
// symbols :: array of Atoms
// lookahead :: Atom or undefined
// position :: Number or undefined
// action :: Function or undefined
function Rule(name, symbols, lookahead, position, action) {
  this.id = "r" + Rule.NextRuleId++;
  this.name = name;
  this.symbols = symbols;
  this.lookahead = lookahead
  this.action = action;
  if (action === undefined)
    this.action = Rule.defaultAction
  this.position = position || 0;
  var s = this.name.toString() + " =>";
  var c = s
  for (var i = 0; i < this.symbols.length; i++) {
    if (i === this.position)
      s += " .";
    s += " " + this.symbols[i].toString();
    c += " " + this.symbols[i].toString();
  }
  this.coreString = c;
  if (this.position === this.symbols.length)
    s += " .";
  if (this.lookahead)
    s = "[" + s + ", " + this.lookahead.toString() + "]";
  this.asString = s;
}
Rule.defaultASTToString = function() {
  var toStr = "(" + this.name; 
  for (var i = 0; i < this.kids.length; i++) {
    toStr += " " + this.kids[i].toString(true);
  }
  toStr += ")";
  return toStr; 
}
Rule.defaultAction = function(kids, curPos) {
  var useful_kids = [];
  for (var i = 0; i < kids.length; i++) {
    if (kids[i].shouldInline === true) useful_kids = useful_kids.concat(kids[i].kids);
    else useful_kids.push(kids[i]);
  }
  var pos = (kids.length > 0 ? kids[0].pos.combine(curPos) : curPos);
  return { name: this.name, kids: useful_kids, toString: Rule.defaultASTToString, pos: pos };
}
Rule.defaultAction.toString = function() { return "Rule.defaultAction"; }

Rule.ListCons = function(hd, tl, shouldInline) {
  var ret = function(kids, curPos) {
    var useful_kids = [];
    for (var i = 0; i < kids.length; i++) {
      if (kids[i].name === hd) {
        if (kids[i].shouldInline === true)
          useful_kids = useful_kids.concat(kids[i].kids);
        else
          useful_kids.push(kids[i]);
      } else if (kids[i].name === tl) useful_kids = useful_kids.concat(kids[i].kids); 
    }
    var pos = (kids.length > 0 ? kids[0].pos.combine(curPos) : curPos);
    return { name: tl, kids: useful_kids, toString: Rule.defaultASTToString, pos: pos,
             shouldInline: shouldInline };
  }
  if (shouldInline) {
    ret.toString = function() { return "Rule.ListCons(" + JSON.stringify(hd) + ", " + JSON.stringify(tl) + ", true)"; }
  }
  else {
    ret.toString = function() { return "Rule.ListCons(" + JSON.stringify(hd) + ", " + JSON.stringify(tl) + ")"; }
  }
  return ret;
}

Rule.Inline = function(kids, curPos) {
  var ret = Rule.defaultAction.call(this, kids, curPos);
  ret.shouldInline = true;
  return ret;
}
Rule.Inline.toString = function() { return "Rule.Inline"; }

Rule.KeepOnly = function(names, shouldInline) {
  var name_dict = {};
  for (var i = 0; i < names.length; i++)
    name_dict[names[i]] = true;
  var ret = function(kids, curPos) {
    var useful_kids = [];
    for (var i = 0; i < kids.length; i++) {
      if (name_dict[kids[i].name] === true) {
        if (kids[i].shouldInline === true)
          useful_kids = useful_kids.concat(kids[i].kids);
        else
          useful_kids.push(kids[i]);
      }
    }
    var pos = (kids.length > 0 ? kids[0].pos.combine(curPos) : curPos);
    return { name: this.name, kids: useful_kids, toString: Rule.defaultASTToString, pos: pos, 
             shouldInline: shouldInline };
  }
  if (shouldInline)
    ret.toString = function() { return "Rule.KeepOnly([" + JSON.stringify(names) + "], true)"; };
  else
    ret.toString = function() { return "Rule.KeepOnly([" + JSON.stringify(names) + "])"; };
  return ret;
}

var RuleFactory = {};
RuleFactory.cache = {};
RuleFactory.byId = {};
RuleFactory.make = function(name, symbols, lookahead, pos, action) {
  if (action === undefined)
    action = Rule.defaultAction
  pos = pos || 0;
  var findByName = RuleFactory.cache[name];
  if (findByName) {
    var findBySymbols = findByName[symbols];
    if (findBySymbols) {
      var findByLookahead = findBySymbols[lookahead];
      if (findByLookahead) {
        var findByPos = findByLookahead[pos];
        if (findByPos) {
          var findByAction = findByPos[action];
          if (findByAction) return findByAction;
          else {
            var rule = new Rule(name, symbols, lookahead, pos, action);
            RuleFactory.byId[rule.id] = rule;
            findByPos[action] = rule;
            return rule;
          }
        } else {
          var rule = new Rule(name, symbols, lookahead, pos, action);
          RuleFactory.byId[rule.id] = rule;
          var byAction = {}; byAction[action] = rule;
          findByLookahead[pos] = byAction;
          return rule;
        }
      } else {
        var rule = new Rule(name, symbols, lookahead, pos, action);
        RuleFactory.byId[rule.id] = rule;
        var byAction = {}; byAction[action] = rule;
        var byPos = {}; byPos[pos] = byAction;
        findBySymbols[lookahead] = byPos;
        return rule;
      }
    } else {
      var rule = new Rule(name, symbols, lookahead, pos, action);
      RuleFactory.byId[rule.id] = rule;
      var byAction = {}; byAction[action] = rule;
      var byPos = {}; byPos[pos] = byAction;
      var byLookahead = {}; byLookahead[lookahead] = byPos;
      findByName[symbols] = byLookahead;
      return rule;
    }
  } else {
    var rule = new Rule(name, symbols, lookahead, pos, action);
    RuleFactory.byId[rule.id] = rule;
    var byAction = {}; byAction[action] = rule;
    var byPos = {}; byPos[pos] = byAction;
    var byLookahead = {}; byLookahead[lookahead] = byPos;
    var bySymbols = {}; bySymbols[symbols] = byLookahead;
    RuleFactory.cache[name] = {}; RuleFactory.cache[name] = bySymbols;
    return rule;
  }
}
Rule.fromSerializable = function(rulesByOldId, id) {
  var obj = rulesByOldId[id];
  if (obj.hasOwnProperty("like")) {
    var base = Rule.fromSerializable(rulesByOldId, obj.like);
    var lookahead = obj.lookahead;
    return RuleFactory.make(base.name, base.symbols, Atom.fromSerializable(lookahead), base.position, base.action);
  } else {
    var sym = [];
    for (var i = 0; i < obj.symbols.length; i++) {
      sym[i] = Atom.fromSerializable(obj.symbols[i]);
    }
    return RuleFactory.make(obj.name, sym, Atom.fromSerializable(obj.lookahead), obj.position, eval(obj.action));
  }
}

Rule.NextRuleId = 0;
Rule.equals = function(thiz, that) {
  if (thiz === that) return true;
  if (thiz === undefined || that === undefined) return false;
  return (thiz.id === that.id) ||
    (thiz.name == that.name && 
     thiz.symbols == that.symbols && 
     thiz.lookahead == that.lookahead && 
     thiz.action == that.action && 
     thiz.position == that.position);
}
Rule.equalsCore = function(thiz, that) {
  if (thiz === that) return true;
  if (thiz === undefined || that === undefined) return false;
  return (thiz.id === that.id) ||
    (thiz.name == that.name && 
     thiz.symbols == that.symbols && 
     thiz.action == that.action && 
     thiz.position == that.position);
}
Rule.prototype = {
  toString: function() { return this.asString; },
  withLookahead: function(lookahead) { 
    return RuleFactory.make(this.name, this.symbols, lookahead, this.position, this.action); 
  },
  toSerializable: function() {
    var ret = {};
    if (this.lookahead) {
      ret.lookahead = this.lookahead.toSerializable();
      ret.like = this.withLookahead(undefined).id;
      return ret;
    }
    ret.name = this.name;
    if (this.action)
      ret.action = this.action.toString();
    ret.position = this.position;
    ret.symbols = [];
    for (var i = 0; i < this.symbols.length; i++)
      ret.symbols[i] = this.symbols[i].toSerializable();
    return ret;
  }
}



function Link(prev, val) {
  this.prev = prev;
  this.val = val;
  this.linkId = Link.NextLinkId++;
}
Link.NextLinkId = 0;
Link.prototype.toString = function() {
  return this.prev.state + "<-(" + this.linkId + (this.reduced ? "r" : "") + ")-" + this.val;
}



function ShiftPair(gssNode, state) {
  this.gssNode = gssNode;
  this.state = state;
}
ShiftPair.prototype.toString = function() { return "Shift(" + this.gssNode.toString() + ", " + this.state + ")"; }
function ReductionItem(gssNode, rule, m, f, label) {
  this.gssNode = gssNode;
  this.rule = rule;
  this.m = m;
  this.f = f;
  this.label = label;
}
ReductionItem.prototype.toString = function() {
  return "RedItem(" + this.gssNode + ", " + this.rule + ", " + this.m + ", " + this.f + ", " + this.label + ")";
}
function GSSNode(label) {
  this.gssId = GSSNode.NextNodeId++;
  this.label = label;
  this.key = label;
  this.links = [];
  GSSNode.allNodes.push(this);
}
GSSNode.NextNodeId = 0;
GSSNode.allNodes = [];
GSSNode.prototype.toString = function() { 
  return "GSSNode(#" + this.gssId + ",s" + this.parentSetId + ":st" + this.label + ")"; 
}
GSSNode.prototype.forPathsOfLength = function(len, callback) {
  if (len === 0) {
    callback({labels: [], leftSib: this}); 
  } else {
    assert(this.links.length > 0, "Can't find any paths of length " + len + " from " + this)
    for (var i = 0; i < this.links.length; i++)
      pathLengthHelp(this.links[i], len, [], [this.toString()], callback);
  }
}
function pathLengthHelp(link, len, labels, stack, callback) {
  labels[len - 1] = link.val;
  stack.push(link.prev.toString());
  if (len == 1) { 
    // console.log("Constructed path via [" + stack + "]");
    // console.log("Calling callback with [" + labels + "] and leftSib.state " + link.prev.label);
    callback({labels: labels, leftSib: link.prev}); 
  } else {
    var prev_links = link.prev.links;
    assert(prev_links.length > 0, "Can't find any paths of length " + len + " from " + this)
    for (var i = 0; i < prev_links.length; i++)
      pathLengthHelp(prev_links[i], len - 1, labels, stack, callback);
  }
  stack.pop();
}
// GSSNode.prototype.forPathsOfLengthUsing = function(len, callback, link) {
//   if (len === 0) {
//     return; // No way to have zero path-length while using link
//   } else {
//     var found = false;
//     console.log("    Looking for " + link);
//     for (var i = 0; i < this.links.length; i++) {
//       console.log("      Link " + i + ": " + this.links[i]);
//       if (this.links[i] === link) {
//         console.log("        ***** HOORAY! Index " + i + ": Found " + link)
//         found = true;
//         break;
//       }
//     }
//     if (!found) return;
//     console.log("In fPOLUsing for state " + this.id + ":" + this.state
//                 + ", link.prev = " + link.prev.id + ":" + link.prev.state
//                 + ", link.val = " + link.val + "@" + link.val.pos.toString(true)
//                 + " and len = " + len);
//     var links = [];
//     var stack = ["" + this.id + ":" + this.state];
//     pathLengthHelp(link, len, links, stack, callback);
//   }
// }
  


var allowNull = false;
function SPPFNode(label, pos) {
  if (!allowNull)
    assert(pos !== undefined && pos !== null);
  this.sppfId = SPPFNode.NextId++;
  this.label = label;
  this.pos = pos;
  this.rule = undefined;
  this.kids = undefined;
  this.ambig = undefined;
  SPPFNode.allNodes.push(this);
}
SPPFNode.allNodes = [];
SPPFNode.NextId = 0;
SPPFNode.prototype.toString = function() {
  var posString = "null";
  if (this.pos)
    posString = this.pos.toString();
  var ruleAmbig = "";
  if (this.rule)
    ruleAmbig = this.rule.toString();
  else if (this.ambig)
    ruleAmbig = "ambig";
  else if (this.label instanceof Token)
    ruleAmbig = "<Token " + this.label.toString(true) + ">";
  else
    ruleAmbig = "<unknown>";
  return "SPPFNode(" + this.sppfId + ", " + this.label.toString(true) + "@" + posString + " " + ruleAmbig + ")";
}
SPPFNode.prototype.addChildren = function(rule, kids) {
  if (this.kids === undefined && this.ambig === undefined) {
    this.kids = kids;
    this.rule = rule;
  } else if (this.ambig === undefined) {
    this.ambig = [];
    this.ambig.push({kids: this.kids, rule: this.rule}); 
    this.ambig.push({kids: kids, rule: rule});
    delete this.kids; delete this.rule;
  } else {
    this.ambig.push({kids: kids, rule: rule});
  }
}

//////////////////////////////////
//////////// Grammars ////////////
//////////////////////////////////

function Grammar(name, start) {
  this.name = name;
  this.rules = {};
  this.start = start;
  this.rnTable = [];
  this.acceptStates = [];
  this.atoms = new OrderedSet([EOF, EPSILON], Atom.equals);
  this.tokens = new OrderedSet([EOF, EPSILON], Atom.equals);
  this.nonterms = new OrderedSet([], Atom.equals);
}

Grammar.fromSerializable = function(obj) {
  var g = new Grammar(obj.name, obj.start);
  var rulesByOldId = {};
  GSSNode.NextNodeId = 0;
  Link.NextLinkId = 0;
  SPPFNode.NextId = 0
  for (var id in obj.rulesByOldId) {
    rulesByOldId[id] = Rule.fromSerializable(obj.rulesByOldId, id);
  }
  for (var i = 0; i < obj.rules.length; i++)
    g.addRule(rulesByOldId[obj.rules[i]]);
  g.rnTable = [];
  for (var i = 0; i < obj.rnTable.length; i++) {
    var tableRow = obj.rnTable[i];
    var newRow = g.rnTable[i] = {};
    for (var j = 0; j < g.atoms.size(); j++) {
      var atom = g.atoms.get(j);
      newRow[atom] = {push: undefined, reductions: new OrderedSet([], Action.equals)};
      if (atom in tableRow) {
        if (tableRow[atom].accept)
          newRow[atom].accept = new AcceptAction();
        if (tableRow[atom].push) {
          assert.equal(newRow[atom].push, undefined, "Already have a push action for atom " + atom);
          newRow[atom].push = new PushAction(tableRow[atom].push);
        }
        if (tableRow[atom].reductions) {
          for (var k = 0; k < tableRow[atom].reductions.length; k++) {
            var red = tableRow[atom].reductions[k];
            newRow[atom].reductions.add(new ReduceAction(rulesByOldId[red[0]], red[1]));
          }
        }
      }
    }
  }
  g.acceptStates = [];
  for (var i = 0; i < obj.acceptStates.length; i++)
    g.acceptStates[obj.acceptStates[i]] = true;
  g.derivable = {};
  for (var name in obj.derivable) {
    g.derivable[name] = {};
    for (var i = 0; i < obj.derivable[name].length; i++)
      g.derivable[name][obj.derivable[name][i]] = true;
  }
  g.mode = obj.mode;
  g.eSPPFs = [];
  g.I = obj.I;
  var Iinv = {};
  for (var name in obj.I)
    Iinv[obj.I[name]] = name;
  allowNull = true;
  for (var i = 0; i < obj.eSPPFs.length; i++) {
    var label = obj.eSPPFs[i].label;
    if (label === "EPSILON")
      label = EPSILON;
    g.eSPPFs[i] = {null: new SPPFNode(label, null)};
  }
  allowNull = false;
  for (var i = 0; i < obj.eSPPFs.length; i++) {
    var src = obj.eSPPFs[i];
    var dest = g.eSPPFs[i].null;
    if (src.kids) {
      var kids = [];
      for (var j = 0; j < src.kids.length; j++)
        kids.push(g.eSPPFs[src.kids[j]].null);
      dest.addChildren(rulesByOldId[src.rule], kids);
    }
  }
  return g;
}



Grammar.prototype = {
  resetParser: function() {
    this.rnTable = [];
    this.acceptStates = [];
    delete this.first;
    delete this.nontermFirst;
    delete this.states;
  },
  initializeParser: function() {
    console.log("Initializing " + this.name);
    var new_start;
    if (!this.initialized) {
      new_start = "START";
      while (this.rules.hasOwnProperty(new_start))
        new_start += "_";
      this.addRule(new_start, [new Nonterm(this.start)]);
      this.start = new_start;
      this.initialized = true;
    }
    var orig_start = this.rules[this.start][0].symbols[0];
    console.log("Grammar productions:");
    for (var name in this.rules)
      for (var i = 0; i < this.rules[name].length; i++)
        console.log("  " + this.rules[name][i].toString(true));
    console.log("Computing first sets");
    this.resetParser();
    this.computeFirstSets();
    console.log("Computing derivability");
    this.computeDerivability();
    console.log("Computing states");
    this.computeStateKernels();
    console.log("Computing required nullable parts");
    this.computeRequiredNullableParts();
    console.log("Computing RN Table");
    this.computeRNTable();
    this.mode = "RNGLR";
    console.log("Done initializing " + this.name);
  },
  parse: function(token_stream) {
    if (this.mode === "RNGLR")
      return this.parseRNGLR(token_stream);
    return "Unknown parsing mode -- can't actually parse!"
  },
  toString: function() {
    var s = "Grammar " + this.name + ": (initial rule " + this.start + ")\n";
    for (var name in this.rules) {
      var rules = this.rules[name];
      for (var i = 0; i < rules.length; i++)
        s += rules[i].toString() + "\n";
    }
    return s;
  },

  toSerializable: function() {
    var ret = {};
    ret.start = this.start;
    ret.name = this.name;
    ret.acceptStates = [];
    for (var i = 0; i < this.acceptStates.length; i++)
      if (this.acceptStates[i])
        ret.acceptStates.push(i);
    ret.mode = this.mode;
    ret.derivable = {};
    for (var name in this.derivable) {
      ret.derivable[name] = [];
      for (var der in this.derivable[name])
        ret.derivable[name].push(der);
    }
    ret.rulesByOldId = {};
    ret.rules = [];
    for (var name in this.rules) {
      for (var i = 0; i < this.rules[name].length; i++) {
        var rule = this.rules[name][i];
        var id = rule.id;
        ret.rulesByOldId[id] = rule.toSerializable();
        ret.rules.push(id);
        var rule_noLookahead = rule.withLookahead(undefined);
        ret.rulesByOldId[rule_noLookahead.id] = rule_noLookahead.toSerializable();
      }
    }
    ret.rnTable = []; // TODO: Fix this
    for (var i = 0; i < this.rnTable.length; i++) {
      var tableRow = this.rnTable[i];
      ret.rnTable[i] = {};
      for (var name in tableRow) {
        if (tableRow[name].push === undefined && !tableRow[name].accept && tableRow[name].reductions.size() === 0) {
          //ret.rnTable[i][name] = "empty";
        } else {
          var entry = tableRow[name];
          var dest = ret.rnTable[i][name] = {};
          if (entry.accept) dest.accept = true;
          if (entry.push !== undefined) {
            dest.push = entry.push.dest;
          }
          if (entry.reductions.size() > 0) {
            dest.reductions = [];
            for (var j = 0; j < entry.reductions.size(); j++) {
              var red = entry.reductions.get(j)
              dest.reductions.push([red.rule.id, red.f]);
              ret.rulesByOldId[red.rule.id] = red.rule.toSerializable();
              var rule_noLookahead = red.rule.withLookahead(undefined);
              ret.rulesByOldId[rule_noLookahead.id] = rule_noLookahead.toSerializable();
            }
          }
        }
      }
    }
    ret.I = this.I;
    ret.eSPPFs = [];
    for (var i = 0; i < this.eSPPFs.length; i++) {
      var null_eSPPF = this.eSPPFs[i].null;
      var label = null_eSPPF.label;
      if (label === EPSILON) {
        label = "EPSILON";
      }
      if (null_eSPPF.kids) {
        var kids = [];
        for (var j = 0; j < null_eSPPF.kids.length; j++)
          kids.push(null_eSPPF.kids[j].sppfId);
        ret.eSPPFs[i] = {label: label, kids: kids, rule: null_eSPPF.rule.id};
      } else {
        ret.eSPPFs[i] = {label: label};
      }
    }
    return ret;
  },

  addRule: function(name, symbols, action) {
    var new_rule;
    if (name instanceof Rule) {
      new_rule = name;
      name = new_rule.name;
      symbols = new_rule.symbols;
    } else {
      new_rule = RuleFactory.make(name, symbols, undefined, undefined, action);
    }
    if (!(this.rules.hasOwnProperty(name)))
      this.rules[name] = [];
    this.rules[name].push(new_rule);
    this.atoms.add(new Nonterm(name));
    this.nonterms.add(new Nonterm(name));
    for (var i = 0; i < symbols.length; i++) {
      this.atoms.add(symbols[i]);
      if (symbols[i] instanceof Nonterm)
        this.nonterms.add(symbols[i])
      else
        this.tokens.add(symbols[i])
    }
    return new_rule;
  },

  //////////////////////////////////
  // Computes what nonterminals can derive other nonterminals in one or more steps,
  // i.e. A ->+ B for two nonterminals A and B (possibly the same)
  //////////////////////////////////
  computeDerivability: function() {
    this.derivable = {}
    for (var i = 0; i < this.nonterms.size(); i++)
      this.derivable[this.nonterms.get(i)] = {};
    var changed = true;
    while(changed) {
      changed = false;
      // console.log("\nNew loop...");
      for (var name in this.rules) {
        var rules = this.rules[name]
        for (var i = 0; i < rules.length; i++) {
          var rule = rules[i];
          // console.log("Processing rule [" + rule + "]");
          if (rule.symbols.length === 0) {
            // if (!this.derivable[name][EPSILON])
            //   console.log("  " + name + " can derive EPSILON via rule " + rule);
            changed = changed || (!this.derivable[name][EPSILON]);
            this.derivable[name][EPSILON] = true; // Rule <name> is nullable
          }
          for (var j = 0; j < rule.symbols.length; j++) {
            var sym = rule.symbols[j]
            if ((sym instanceof Token) && (sym !== EOF)) {
              // console.log("  Rule [" + rule + "] isn't nullable due to " + sym + " so skipping rest");
              break; // A token in the RHS of a rule means it can't derive a nonterminal on its own
            }
            var restNullable = true;
            for (k = j + 1; k < rule.symbols.length; k++) {
              if (rule.symbols[k] === EOF) continue;
              if ((rule.symbols[k] instanceof Token) || 
                  (this.derivable[rule.symbols[k]][EPSILON] !== true)) {
                restNullable = false;
                break;
              }
            }
            if (restNullable) {
              // if (!this.derivable[name][sym])
              //   console.log("  " + name + " can derive " + sym + " via [" + rule + "]");
              changed = changed || (!this.derivable[name][sym]);
              this.derivable[name][sym] = true;
            }
            if ((!this.derivable[sym]) || this.derivable[sym][EPSILON] !== true) {
              // console.log("Rule [" + rule + "] isn't nullable after " + sym + " so skipping rest");
              break; // This nonterminal isn't nullable, so skip the rest of the rule
            }
          }
        }
      }

      for (var i = 0; i < this.nonterms.size(); i++) {
        var term_i = this.nonterms.get(i);
        for (var j = 0; j < this.nonterms.size(); j++) {
          var term_j = this.nonterms.get(j);
          if (i == j || !this.derivable[term_i][term_j]) continue;
          if (this.derivable[term_j][EPSILON] && !this.derivable[term_i][EPSILON]) {
            // console.log(term_i + " can derive EPSILON via " + term_j);
            this.derivable[term_i][EPSILON] = true;
          }
          for (var k = 0; k < this.nonterms.size(); k++) {
            var term_k = this.nonterms.get(k);
            if (j == k || !this.derivable[term_j][term_k]) continue;
            // if (!this.derivable[term_i][term_k])
            //   console.log(term_i + " can derive " + term_k + " via " + term_j);
            changed = changed || (!this.derivable[term_i][term_k])
            this.derivable[term_i][term_k] = true;
          }
        }
      }
    }
    // console.log("Done");
  },

  //////////////////////////////////
  // Computes the set of first tokens in a rule
  // If a rule is nullable, then EPSILON is one possible token
  //////////////////////////////////
  computeFirstSets: function() {
    var thiz = this;
    var changed = true;
    function addFirst(name, token) {
      var ret = !(token.toString() in thiz.first[name])
      thiz.first[name][token.toString()] = token;
      return ret;
    }
    function merge(dest, source) {
      var ret = false;
      for (var tok in thiz.first[source])
        if (thiz.first[source][tok] !== EPSILON)
          ret = addFirst(dest, thiz.first[source][tok]) || ret;
      return ret;
    }
    this.first = {};
    this.nontermFirst = {};
    for (var name in this.rules) {
      if (this.rules.hasOwnProperty(name)) {
        this.first[name] = {};
        this.nontermFirst[name] = new OrderedSet([name], Atom.equals);
        for (var i = 0; i < this.rules[name].length; i++)
          if (this.rules[name][i].symbols.length === 0)
            addFirst(name, EPSILON);
      }
    }
    while (changed) {
      changed = false;
      for (var name in this.rules) {
        var name_rules = this.rules[name];
        for (var i = 0; i < name_rules.length; i++) {
          var name_rule = name_rules[i];
          var allNullable = true;
          for (var j = 0; j < name_rule.symbols.length; j++) {
            if (name_rule.symbols[j] instanceof Nonterm) {
              changed = merge(name, name_rule.symbols[j]) || changed;
              if (this.nontermFirst[name_rule.symbols[j]] === undefined)
                assert(false, "Couldn't find a nontermFirst for " + name_rule.symbols[j]);
              this.nontermFirst[name].merge(this.nontermFirst[name_rule.symbols[j]]);
              if (this.first[name_rule.symbols[j]][EPSILON] !== EPSILON) {
                allNullable = false;
                break;
              }
            } else {
              changed = addFirst(name, name_rule.symbols[j]) || changed;
              allNullable = false;
              break;
            }
          }
          if (allNullable) {
            addFirst(name, EPSILON);
          }
        }
      }
    }
    for (var name in this.first) {
      for (var i in this.first[name]) {
        assert.ok(this.first[name][i] instanceof Atom,
          "This.first[" + name + "][" + i + "] = " + this.first[name][i]);
      }
    }
  },


  //////////////////////////////////
  // Computes the tokens that can immediately follow the specified position
  // in the current rule.  This is a subset of the Follow set for the given
  // nonterminal, and is therefore more precise and less prone to producing
  // parsing conflicts.
  //////////////////////////////////
  computeFollowAtPosition: function(rule, pos) {
    var ret = new OrderedSet([], Atom.equals);
    if (rule.lookahead)
      return this.computeFirstOfStrings(rule.symbols.slice(pos), [rule.lookahead]);
    else
      return this.computeFirstOfStrings(rule.symbols.slice(pos));
  },

  //////////////////////////////////
  // Lifts the first relation from non-terminals to strings of grammar symbols
  computeFirstOfStrings: function() {
    var ret = new OrderedSet([], Atom.equals);
    var nullable = true;
    for (var i = 0; i < arguments.length; i++) {
      nullable = true;
      var syms_i = arguments[i];
      // console.log("syms[" + i + "] = [" + syms_i + "], length = " + syms_i.length);
      for (var j = 0; j < syms_i.length; j++) {
        if (syms_i[j] instanceof Token || syms_i[j] === HASH) { // Tokens aren't nullable, so we're done
          ret.add(syms_i[j]);
          nullable = false;
          break;
        } else {
          var first = this.first[syms_i[j]];
          if (first === undefined) {
            console.log("WTF? syms_i[j] = " + syms_i[j] + " but first is undefined");
          }
          for (var name in first) {
            if (first[name] !== EPSILON)
              ret.add(first[name]);
          }
          if (first[EPSILON] === undefined) { // This nonterminal isn't nullable, so we're done
            nullable = false;
            break;
          }
        }
      }
      if (!nullable) break;
    }
    if (nullable)
      ret.add(EPSILON);
    return ret;
  },

  //////////////////////////////////
  // Computes the LR(1) closure of a rule set: 
  // For a given rule [A -> a.Bb, x] in the set, it adds [B -> .g, y]
  // for all [B -> g] in the grammar, and all y in FIRST(bx).
  // 
  // If inline = true, then it mutates the provided argument
  // otherwise it constructs a new set and returns that.
  completeClosure: function(rule_set, inline) {
    var ret = inline ? rule_set : new OrderedSet(rule_set);
    var worklist = new Queue(ret.ordered);
    while (worklist.length > 0) {
      var rule = worklist.shift();
      if (rule.position < rule.symbols.length) {
        var next_symbol = rule.symbols[rule.position];
        if (next_symbol instanceof Nonterm) {
          var next = this.computeFollowAtPosition(rule, rule.position + 1);
          // console.log("next(" + rule + ") = " + next);
          var rules_to_add = this.rules[next_symbol]
          for (var j = 0; j < rules_to_add.length; j++) {
            var rule_to_add = rules_to_add[j];
            for (var k = 0; k < next.size(); k++) {
              var new_rule = RuleFactory.make(rule_to_add.name, rule_to_add.symbols, next.get(k), 0, rule_to_add.action)
              if (!ret.contains(new_rule)) {
                ret.add(new_rule);
                worklist.push(new_rule);
              }
            }
          }
        }
      }
    }
    return ret;
  },
  
  //////////////////////////////////
  // Computes the kernel of the LR(1) Goto set for a given kernel and symbol
  // Dragon book, p241
  computeGotoKernel: function(i, rule_set, symbol) {
    // console.log("--> Rule_set #" + i + " = " + rule_set + ", symbol = " + symbol);
    var ret = new OrderedSet([], Rule.equals);
    for (var i = 0; i < rule_set.size(); i++) {
      var rule = rule_set.get(i);
      // console.log("    Processing rule " + rule);
      if (rule.position < rule.symbols.length) {
        if (rule.symbols[rule.position].toString() == symbol) {
          var new_rule = RuleFactory.make(rule.name, rule.symbols, undefined, rule.position + 1, rule.action);
          // console.log("      Pushing " + symbol + " over in rule " + rule + " ==> " + new_rule);
          ret.add(new_rule);
        }
        if (rule.symbols[rule.position] instanceof Nonterm) {
          var C = rule.symbols[rule.position];
          var ntFirst = this.nontermFirst[C];
          // console.log("      nontermFirst[" + C + "] = " + ntFirst.toString());
          // console.log("      first[" + C + "] = " + JSON.stringify(this.first[C]));
          for (var idx = 0; idx < ntFirst.size(); idx++) {
            var a = ntFirst.get(idx);
            var rules_a = this.rules[a];
            for (var j = 0; j < rules_a.length; j++) {
              var rule_a = rules_a[j];
              // console.log("      Rule " + rule + " can derive " + a + " so examining " + rule_a + " for "+ symbol);
              if (rule_a.symbols.length > 0 && rule_a.symbols[0].toString() == symbol) {
                // console.log("      Adding " + rule_a);
                var new_rule = RuleFactory.make(rule_a.name, rule_a.symbols, undefined, 1, rule_a.action);
                ret.add(new_rule);
              }
            }
          }
        }
      }
    }
    // console.log("<-- Result = " + ret);
    return ret;
  },

  reducer: function(U, R, Q, N, i, cur_tok) {
    // cur_tok = token #i+1: i starts at index 0, and tokens start at index 1
    // U is an array of sets of GSS nodes
    // R is the worklist of pending reductions
    // Q is the set of (GSS node, token) pairs of pending shifts
    // N is the set of SPPF nodes created in this step
    // cur_tok is the current token
    var item = R.shift();
    // console.log("In reducer, i = " + i + ", cur_tok = " + cur_tok.toString(true) + ", and item = " + item);
    var v = item.gssNode; // GSS node from which the reduction is to be applied
    var X = item.rule.name; // the name of the reduction rule
    var m = item.m; // the length of the RHS of the reduction rule (maybe just item.rule.position?)
    var f = item.f; // the index of the required nullable part at the righthand end of the reduction
                    // or 0 if the reduction isn't right-nullable
    var y = item.label; // the SPPF node labels the first edge of the path down which the reduction is applied
                         // (if m = 0 then y = epsilon) [sic]
    var y_m = (m !== 0 ? y : undefined)
    var U_i = U[i]
    const thiz = this;
    v.forPathsOfLength(m > 0 ? (m - 1) : 0, function(p) {
      // console.log("Found path " + JSON.stringify(p, null, "  "));
      // p.labels contain the edge labels of the path
      var u = p.leftSib;
      var k = u.label;
      var pl = thiz.rnTable[k][X].push;
      if (pl !== undefined) {
        // console.log("k = " + k + ", X = " + X + ", pl = " + pl);
        var l = pl.dest;
        var z = undefined;
        if (m === 0)
          z = thiz.getEpsilonSPPF(f, cur_tok.pos.posAtStart());
        else {
          var c = u.parentSetId;
          var nodes_X = N[X];
          if (nodes_X === undefined)
            nodes_X = N[X] = {};
          z = nodes_X[c];
          if (z === undefined) {
            var pos = cur_tok.pos;
            if (p.labels.length > 0) {
              pos = pos.combine(p.labels[0].pos);
            }
            z = nodes_X[c] = new SPPFNode(X, pos);
          }
        }
        // console.log("z = " + z); // XXX Serializing of eSPPFs isn't working
        var w = U_i.itemsByKey(l);
        if (w !== undefined) {
          assert(w.length == 1, "Should not have multiple items with key " + l + " in set U[" + i + "]");
          w = w[0];
        }
        if (w !== undefined) {
          // console.log("1. Adding link from " + w + " to " + u + " labelled " + z);
          if (thiz.addLink(/*from*/w, /*to*/u, /*labelled*/z)) {
            if (m !== 0) {
              var reductions = thiz.getActions(l, cur_tok).reductions;
              for (var r = 0; r < reductions.size(); r++) {
                var red = reductions.get(r);
                if (red.rule.position !== 0)
                  R.push(new ReductionItem(u, red.rule, red.rule.position, red.f, z));
              }
            }
          }
        } else {
          w = new GSSNode(/*labelled*/l);
          w.parentSetId = U_i.id;
          U_i.add(w);
          // console.log("Added " + w + " to U[" + i + "] ==> " + U_i);
          // console.log("2. Adding link from " + w + " to " + u + " labelled " + z);
          thiz.addLink(/*from*/w,/*to*/u,/*labelled*/z);
          var actions = thiz.getActions(l, cur_tok);
          var ph = actions.push;
          if (ph !== undefined)
            Q.push(new ShiftPair(w, ph.dest));
          var reductions = actions.reductions;
          // console.log("reductions(" + l + ", " + cur_tok.toString(true) + ") = " + reductions);
          for (var r = 0; r < reductions.size(); r++) {
            var red = reductions.get(r);
            if (red.rule.position === 0)
              // the label here is irrelevant, because m == 0 means the rest of the rule derives EPSILON
              R.push(new ReductionItem(w, red.rule, 0, red.f, EPSILON)); 
          }
          if (m !== 0) {
            for (var r = 0; r < reductions.size(); r++) {
              var red = reductions.get(r);
              if (red.rule.position !== 0)
                R.push(new ReductionItem(u, red.rule, red.rule.position, red.f, z));
            }
          }
          // console.log("R.length = " + R.length);
          // R.debugPrint();
        }
        if (m !== 0) {
          var labels = p.labels.slice(0);
          labels.push(y_m);
          thiz.addChildren(item.rule, z, labels, f, cur_tok.pos.posAtEnd());
        }
      }
    });
  },

  addLink: function(rightSib, leftSib, val) {
    var link = undefined;
    for (var i = 0; i < rightSib.links.length; i++) {
      if (rightSib.links[i].prev === leftSib) {
        link = rightSib.links[i];
        break;
      }
    }
    if (link === undefined) {
      link = new Link(leftSib, val);
      rightSib.links.push(link);
      // console.log("Linking " + leftSib.toString() + " <-- " + rightSib.toString() + " with val " + val + "@" + val.pos);
      return link;
    } else {
      // console.log("Link already exists between " + leftSib.toString() + " <-- " + rightSib.toString());
      return undefined;
    }
  },

  shifter: function(U, R, Q, N, i, cur_tok, next_tok) {
    // cur_tok = token #i+1: i starts at index 0, and tokens start at index 1
    // next_tok = token #i+2
    // U is an array of sets of GSS nodes
    // R is the worklist of pending reductions
    // Q is the set of (GSS node, token) pairs of pending shifts
    // N is the set of SPPF nodes created in this step
    if (cur_tok !== EOF) { // if i != d, in the paper, where d is the last token number
      // Q.debugPrint();
      var Qprime = new Queue([]);
      var z = new SPPFNode(cur_tok, cur_tok.pos);
      var U_i1 = U[i+1] = new OrderedSet([]);
      U_i1.id = i + 1;
      while (Q.length > 0) {
        var item = Q.shift();
        var v = item.gssNode;
        var k = item.state;
        var w = U_i1.itemsByKey(k);
        // console.log("item = " + item + ", k = " + k + " and therefore w = " + w);
        if (w !== undefined) {
          assert(w.length == 1, "Should not have multiple items with key " + k + " in set U[" + i + "]");
          w = w[0];
        }
        if (w !== undefined) {
          this.addLink(/*from*/w, /*to*/v, /*labelled*/z);
          var reductions = this.getActions(k, next_tok).reductions;
          for (var r = 0; r < reductions.size(); r++) {
            var red = reductions.get(r);
            if (red.rule.position !== 0)
              R.push(new ReductionItem(v, red.rule, red.rule.position, red.f, z));
          }
        } else {
          w = new GSSNode(/*labelled*/k);
          w.parentSetId = U_i1.id;
          U_i1.add(w);
          // console.log("Added " + w + " to U[" + (i + 1) + "] ==> " + U_i1);
          this.addLink(/*from*/w, /*to*/v, /*labelled*/z);

          var actions = this.getActions(k, next_tok);
          // console.log("next_tok = " + next_tok.toString(true) + ", k = " + k + ", actions = " + JSON.stringify(actions));
          var ph = actions.push;
          if (ph !== undefined) {
            var sp = new ShiftPair(w, ph.dest);
            // console.log("Pushing " + sp + " onto Q'");
            Qprime.push(sp);
          }
          var reductions = actions.reductions;
          // console.log("Reductions for k = " + k + " next_tok = " + next_tok + " are " + reductions);
          for (var r = 0; r < reductions.size(); r++) {
            var red = reductions.get(r);
            // console.log("red.f = " + red.f + ", red.rule.position = " + red.rule.position);
            if (red.rule.position !== 0) {
              R.push(new ReductionItem(v, red.rule, red.rule.position, red.f, z));
            }
          }
          for (var r = 0; r < reductions.size(); r++) {
            var red = reductions.get(r);
            if (red.rule.position === 0) {
              // the label here is irrelevant, because m == 0 means the rest of the rule derives EPSILON
              R.push(new ReductionItem(w, red.rule, 0, red.f, EPSILON)); 
            }
          }
          // console.log("R = ");
          // R.debugPrint();
        }
      }
      while (Qprime.length > 0)
        Q.push(Qprime.shift());
      // console.log("At the end of shifter(" + i + "), Q = ");
      // Q.debugPrint();
    }
  },

  addChildren: function(rule, y, kids, f, pos) {
    var lambda = kids.slice(0);
    if (f !== 0)
      lambda.push(this.getEpsilonSPPF(f, pos));
    // Find lambda in the kids of y
    function examine(y_rule, y_kids) {
      if (y_rule !== rule) return false;
      if (y_kids.length !== lambda.length) return false;
      for (var i = 0; i < y_kids.length; i++)
        if (y_kids[i] !== lambda[i]) return false;
      return true;
    }
    var found = false;
    if (y.kids) {
      found = examine(y.rule, y.kids);
    } else if (y.ambig) {
      for (var i = 0; i < y.ambig.length; i++)
        if (examine(y.ambig[i].rule, y.ambig[i].kids)) {
          found = true;
          break;
        }
    }
    if (!found)
      y.addChildren(rule, lambda);
  },

  getActions: function(state, tok) {
    var tableRow = this.rnTable[state];
    var actions1 = tableRow[tok];
    return actions1;
  },
  
  printSPPFasDot: function() {
    var ret = [];
    ret.push("digraph " + this.name + "_SPPF {");
    ret.push("  rankdir=RL; clusterrank=local;");
    ret.push("  // Nodes");
    for (var i = 0; i < SPPFNode.allNodes.length; i++) {
      var node = SPPFNode.allNodes[i];
      var style = "";
      if (node.inline)
        style = ", style=dashed";
      var label = "SPPFNode #" + node.sppfId;
      if (node.inline)
        label += "\nInlined e-SPPF for " + node.label;
      else
        label += "\nLabel: " + node.label.toString(true);
      if (node.rule)
        label += "\nRule: " + node.rule.toString();
      else if (node.ambig)
        label += "\nMultiple derivations";

      ret.push("  " + node.sppfId + " [label=" + JSON.stringify(label) + style + "];");
      if (node.ambig !== undefined) {
        for (var j = 0; j < node.ambig.length; j++) {
          ret.push("  \"" + node.sppfId + "_" + j 
                   + "\" [label=" + JSON.stringify(node.ambig[j].rule.toString()) +", shape=box];");
        }
      }
    }
    ret.push("  // Edges");
    for (var i = 0; i < SPPFNode.allNodes.length; i++) {
      var node = SPPFNode.allNodes[i];
      if (node.kids !== undefined)
        for (var j = 0; j < node.kids.length; j++)
          ret.push("  " + node.sppfId + " -> " + node.kids[j].sppfId
                   + " [label=\"" + j + "\"];");
      else if (node.ambig !== undefined) {
        for (var j = 0; j < node.ambig.length; j++) {
          ret.push("  " + node.sppfId + " -> \"" + node.sppfId + "_" + j + "\";");
          for (k = 0; k < node.ambig[j].kids.length; k++)
            ret.push("  \"" + node.sppfId + "_" + j + "\" -> " + node.ambig[j].kids[k].sppfId 
                     + " [label=\"" + k + "\"];");
        }
      }
    }
    ret.push("}");
    return ret.join("\n");
  },

  printGSSasDot: function() {
    var ret = [];
    ret.push("digraph " + this.name + "_GSS {");
    ret.push("  rankdir=RL; clusterrank=local;");
    ret.push("  // Nodes");
    for (var i = 0; i < GSSNode.allNodes.length; i++) {
      var node = GSSNode.allNodes[i];
      ret.push("  " + node.gssId + "[label=" + JSON.stringify(node.toString()) + "];");
    }
    ret.push("  // Ranks");
    for (var i = 0; i < this.U.length; i++) {
      var s = "";
      for (var j = 0; j < this.U[i].size(); j++)
        s += " " + this.U[i].get(j).gssId + ";";
      ret.push("  subgraph cluster" + i + " {");
      ret.push("    rank = same; color=black;");
      if (i > 0)
        ret.push("    label=\"Token " + i + "\"");
      ret.push("    " + s);
      ret.push("  }");
    }
    ret.push("  // Edges");
    for (var i = 0; i < GSSNode.allNodes.length; i++) {
      var node = GSSNode.allNodes[i];
      for (var j = 0; j < node.links.length; j++)
        ret.push("  " + node.gssId + " -> " + node.links[j].prev.gssId 
                 + "[label=" + JSON.stringify(node.links[j].val.toString()) + "]"
                 //+ "[label=" + JSON.stringify(JSON.decycle(node.links[j].val), null, "  ") + "]"
                 + ";");
    }
    ret.push("}");
    return ret.join("\n");
  },

  //////////////////////////////////
  // The RNGLR algorithm
  // Following Scott & Johnstone '06, TOPLAS 28:4
  //////////////////////////////////
  parseRNGLR: function(token_source) {
    if (token_source.isEmpty()) {
      if (this.acceptStates[0])
        return this.getEpsilonSPPF(this.I[this.start], SrcLoc.make(0,0,0,0,0,0));
      else {
        console.log("There are zero tokens available, but the grammar does not accept the empty string");
        return null;
      }
    } else {
      var v0 = new GSSNode(0);
      var U0 = new OrderedSet([v0]);
      U0.id = 0;
      v0.parentSetId = U0.id;
      this.U = [];
      this.U[0] = U0;
      var R = new Queue([]);
      var Q = new Queue([]);
      var hasNext = true;
      var cur_tok = token_source.next(); // need to peek at first token
      var actions = this.getActions(0, cur_tok);
      // console.log("Actions[0][" + cur_tok.toString(true) + "] = " + JSON.stringify(actions));
      var pk = actions.push;
      if (pk !== undefined)
        Q.push(new ShiftPair(v0, pk.dest));
      // console.log("Q = ");
      // Q.debugPrint();
      var reductions = actions.reductions;
      for (var r = 0; r < reductions.size(); r++) {
        var red = reductions.get(r);
        if (red.rule.position === 0)
          // Again, label shouldn't matter because length is 0
          R.push(new ReductionItem(v0, red.rule, 0, red.f, EPSILON));
      }
      // console.log("R = ");
      // R.debugPrint();
      var i = 0;
      while (hasNext && this.U[i].size() > 0) {
        var N = new Queue([]);
        // console.log("Phase 1: reducing due to token #" + i + ": " + cur_tok.toString(true));
        while (R.length > 0) {
          this.reducer(this.U, R, Q, N, i, cur_tok);
        }
        hasNext = token_source.hasNext();
        var next_tok = token_source.next();
        // console.log("Phase 2: shifting token #" + i + ": " + cur_tok.toString(true));
        this.shifter(this.U, R, Q, N, i, cur_tok, next_tok);
        if (next_tok)
          cur_tok = next_tok;
        i++;
      }
      console.log("DONE WITH LOOP, i = " + i 
                  + ", last token = " + cur_tok.toString(true) + "@" + cur_tok.pos.toString(true));
      if (!hasNext) i--;
      console.log("Finalizing: i = " + i + " and U[i] = " + this.U[i]);
      for (var acc = 0; acc < this.acceptStates.length; acc++) {
        if (this.acceptStates[acc]) {
          console.log("Searching for " + acc);
          var t = this.U[i].itemsByKey(acc);
          if (t !== undefined) {
            assert(t.length == 1, "Should not have multiple items with key " + acc + " in set U[" + i + "]");
            t = t[0];
          }
          if (t !== undefined) {
            console.log("Parse success!");
            var link = undefined;
            for (var j = 0; j < t.links.length; j++) {
              if (t.links[j].prev === v0) {
                link = t.links[j];
                break;
              }
            }
            if (link !== undefined) {
              return link.val;
            } else
              console.log("Couldn't find correct link in " + JSON.stringify(JSON.decycle(t), null, "  "));
          } else {
            console.log("Parse failure");
          }
        }
      }
    }
  },

  constructAllParses: function(sppfNode, indent) {
    if (sppfNode.label instanceof Token) {
      // console.log(indent + "<-- returning [" + sppfNode.label.toString(true) + "]");
      return [sppfNode.label];
    }
    var options = undefined;
    if (sppfNode.ambig)
      options = sppfNode.ambig;
    else
      options = [{kids: sppfNode.kids, rule: sppfNode.rule}];
    var ret = [];
    // console.log(indent + options.length + " options for " + sppfNode);
    for (var i = 0; i < options.length; i++) {
      var kids = options[i].kids;
      var rule = options[i].rule;
      // console.log(indent + "-->" + i + ": sppfNode.label = " + sppfNode.label + " and rule = " + rule + ", kids.length = " + kids.length + ", sppfNode.pos = " + sppfNode.pos);
      var kidsParses = [];
      for (var j = 0; j < kids.length; j++) {
        if (kids[j].rule === undefined && kids[j].ambig === undefined && kids[j].inline === true) {
          for (k = 0; k < kids[j].kids.length; k++) {
            // console.log(indent + "inlining " + kids[j].kids[k]);
            kidsParses.push([kids[j].kids[k].rule.action(kids[j].kids[k].kids, kids[j].kids[k].pos)]);
          }
        } else {
          // console.log(indent + "  --> constructing all parses for kids[" + j + "]");
          kidsParses.push(this.constructAllParses(kids[j], indent + "    "));
        }
      }
      ret = ret.concat(this.cartesian(kidsParses, 0, [], 
                                      function(kids) { return rule.action(kids, sppfNode.pos); }));
    }
    return ret;
  },
  cartesian: function(arrays, idx, arr, callback) {
    if (arrays.length == idx) return callback(arr);
    var ret = [];
    for (var i = 0; i < arrays[idx].length; i++) {
      ret = ret.concat(this.cartesian(arrays, idx+1, arr.concat(arrays[idx][i]), callback));
    }
    return ret;
  },

  countAllParses: function(sppfNode) {
    if (sppfNode.label instanceof Token) return 1;
    if (sppfNode.kids) {
      var tot = 1;
      for (var i = 0; i < sppfNode.kids.length; i++)
        tot *= this.countAllParses(sppfNode.kids[i]);
      return tot;
    } else if (sppfNode.ambig) {
      console.log("Found an ambiguous node: " + sppfNode);
      var tot = 0;
      for (var i = 0; i < sppfNode.ambig.length; i++) {
        var part = 1;
        for (var j = 0; j < sppfNode.ambig[i].kids.length; j++)
          part *= this.countAllParses(sppfNode.ambig[i].kids[j]);
        tot += part;
      }
      return tot;
    } else
      return 0;
  },

  constructUniqueParse: function(sppfNode) {
    if (sppfNode.label instanceof Token) {
      return sppfNode.label;
    } else if (sppfNode.ambig)
      throw("Not a unique parse");
    var kidsParses = [];
    var kids = sppfNode.kids;
    for (var j = 0; j < kids.length; j++) {
      if (kids[j].rule === undefined && kids[j].ambig === undefined && kids[j].inline === true) {
        for (k = 0; k < kids[j].kids.length; k++) {
          kidsParses.push(kids[j].kids[k].rule.action(kids[j].kids[k].kids, kids[j].kids[k].pos));
        }
      } else {
        kidsParses.push(this.constructUniqueParse(kids[j]));
      }
    }
    return sppfNode.rule.action(kidsParses, sppfNode.pos);
  },

  checkPositionContainment: function(sppfNode) {
    var violations = [];
    function helper(node) {
      var pos = node.pos;
      if (node.kids) {
        for (var i = 0; i < node.kids.length; i++) {
          var kidPos = node.kids[i].pos;
          if (kidPos.startChar < pos.startChar || kidPos.endChar > pos.endChar) {
            violations.push(node);
            break;
          }
        }
      } else if (node.ambig) {
        for (var i = 0; i < node.ambig.length; i++) {
          var kids = node.ambig[i].kids;
          var shouldBreak = false
          for (var j = 0; j < kids.lenth; j++) {
            var kidPos = kids[j].pos;
            if (kidPos.startChar < pos.startChar || kidPos.endChar > pos.endChar) {
              violations.push(node);
              shouldBreak = true;
              break;
            }
          }
          if (shouldBreak) break;
        }
      }
    }
    helper(sppfNode);
    if (violations.length > 0) return violations;
    return false;
  },

  computeRequiredNullableParts: function() {
    // The I dictionary is an index of all nullable nonterminals and (nonempty) strings of 
    // nonterminals that appear as right-hand tails in rules in the grammar.
    // The eSPPFs table is a dictionary indexed first by I value and second by position.
    // We already ensure that position objects are singletons, and this second-level
    // dictionary ensures that e-SPPFs are singletons too, for each position in the 
    // parse tree for which they are needed.  This helps ensure that finding existing links
    // doesn't create duplicates and therefore does't cause duplicate parses, later.
    allowNull = true;
    this.I = {};
    this.I[EPSILON] = 0;
    this.eSPPFs = [];
    this.eSPPFs[0] = {null: new SPPFNode(EPSILON, null)};
    // Initialize all eSPPFs to empty nodes
    for (var name in this.rules) {
      if (this.derivable[name][EPSILON] !== true) continue;
      var name_eSPPF = new SPPFNode(name, null);
      this.I[name] = this.eSPPFs.length;
      this.eSPPFs.push({null: name_eSPPF});
    }
    // Compute the e-closure of the rules
    for (var name in this.rules) {
      if (this.derivable[name][EPSILON] !== true) continue;
      var rules_name = this.rules[name];
      var name_eSPPF = this.eSPPFs[this.I[name]].null;
      for (var i = 0; i < rules_name.length; i++) {
        var rule = rules_name[i];
        if (this.computeFirstOfStrings(rule.symbols).contains(EPSILON)) {
          var kids = [];
          for (var j = 0; j < rule.symbols.length; j++) {
            kids.push(this.eSPPFs[this.I[rule.symbols[j]]].null);
          }
          name_eSPPF.addChildren(rule, kids);
        }
      }
    }
    // Compute required nullable parts
    for (var name in this.rules) {
      var rules_name = this.rules[name];
      for (var i = 0; i < rules_name.length; i++) {
        var rule = rules_name[i];
        for (var j = 1/*note: not 0*/; j < rule.symbols.length; j++) {
          var slice = rule.symbols.slice(j)
          if (this.computeFirstOfStrings(slice).contains(EPSILON) && this.I[slice] === undefined) {
            var eSPPF_slice = new SPPFNode("" + slice, null);
            eSPPF_slice.inline = true;
            var kids = [];
            for (var k = 0; k < slice.length; k++)
              kids[k] = this.eSPPFs[this.I[slice[k]]].null;
            eSPPF_slice.kids = kids;
            this.I[slice] = this.eSPPFs.length;
            this.eSPPFs.push({null: eSPPF_slice});
          }
        }
      }
    }
    allowNull = false;
  },
  getI: function(rule) {
    var ret = undefined;
    if (rule.position === 0) ret = this.I[rule.name];
    else if (rule.position === rule.symbols.length) ret = this.I[EPSILON];
    else ret = this.I[rule.symbols.slice(rule.position)];
    return ret;
  },
  getEpsilonSPPF: function(i, pos) {
    function find(node, cache) {
      for (var i = 0; i < cache.length; i++) {
        if (cache[i].key === node) {
          return cache[i].value;
        }
      }
      return undefined;
    }
    function clone(node, cache) {
      var ret = find(node, cache);
      if (ret !== undefined) return ret;
      ret = {};
      cache.push({key: node, value: ret});
      ret.sppfId = node.sppfId;
      ret.name = node.name;
      ret.label = node.label;
      ret.pos = pos;
      ret.toString = node.toString;
      ret.rule = node.rule;
      ret.inline = node.inline;
      if (node.kids !== undefined) {
        ret.kids = [];
        for (var i = 0; i < node.kids.length; i++) {
          ret.kids[i] = clone(node.kids[i], cache);
        }
      } else if (node.ambig !== undefined) {
        ret.ambig = [];
        for (var i = 0; i < node.ambig.length; i++) {
          var kids = [];
          ret.ambig.push({kids: kids, rule: node.ambig[i].rule});
          for (var j = 0; j < node.ambig[i].kids.length; j++) {
            kids[j] = clone(node.ambig[i].kids[j], cache);
          }
        }
      }
      return ret;
    }
    var byI = this.eSPPFs[i];
    var ret = byI[pos];
    if (ret === undefined)
      ret = byI[pos] = clone(byI[null], []);
    return ret;
  },

  computeRNTable: function() {
    const thiz = this;
    function initTables(index) {
      var tableRow = thiz.rnTable[index];
      if (tableRow === undefined)
        tableRow = thiz.rnTable[index] = {};
      for (var k = 0; k < thiz.atoms.size(); k++) {
        if (tableRow[thiz.atoms.get(k)] === undefined)
          tableRow[thiz.atoms.get(k)] = {push: undefined, reductions: new OrderedSet([], Action.equals)};
      }
    }
    

    initTables(0);
    if (this.derivable[this.start][EPSILON] === true) {
      this.acceptStates[0] = true;
      this.rnTable[0][EOF].accept = new AcceptAction();
    }
    for (var i = 0; i < this.states.size(); i++) {
      var state_i = this.states.get(i);
      initTables(i);
      var full_state = this.completeClosure(state_i);
      for (var j = 0; j < full_state.size(); j++) {
        var rule_j = full_state.get(j);
        if (rule_j.name === this.start && rule_j.position === rule_j.symbols.length && rule_j.lookahead === EOF) {
          this.acceptStates[i] = true;
          this.rnTable[i][EOF].accept = new AcceptAction();
        } else if (rule_j.name !== this.start && 
                   this.computeFollowAtPosition(rule_j.withLookahead(undefined), 
                                                rule_j.position).contains(EPSILON)) {
            this.rnTable[i][rule_j.lookahead].reductions.add(new ReduceAction(rule_j, this.getI(rule_j)));
        }
      }
    }
  },


  //////////////////////////////////
  // Algorithm 4.13 (p242-243) in Dragon book
  computeStateKernels: function() {
    var init_rule = this.rules[this.start][0].withLookahead(EOF);
    this.init_set = new OrderedSet([init_rule], Rule.equalsCore);
    var kernelStates = new OrderedSet([this.init_set], OrderedSet.equals);
    this.rnTable = [];
    // Step 1
    var worklist = new Queue([this.init_set]);
    var state_num = -1;
    while (worklist.length > 0) {
      var set = worklist.shift();
      state_num++;
      this.rnTable[state_num] = undefined;
      for (var j = 0; j < this.atoms.size(); j++) {
        var atom_j = this.atoms.get(j);
        var new_set = this.computeGotoKernel(state_num, set, atom_j);
        if (new_set.size() > 0) {
          var gotoStateNum = undefined;
          if (kernelStates.add(new_set)) {
            gotoStateNum = kernelStates.size() - 1;
            worklist.push(new_set);
          } else {
            gotoStateNum = kernelStates.indexOf(new_set);
          }
          // console.log(state_num + ":" + set + " goes to " + gotoStateNum + ":" + new_set + " via symbol " + atom_j);
          var tableRow = this.rnTable[state_num];
          if (tableRow === undefined)
            tableRow = this.rnTable[state_num] = {};
          var tableCell = tableRow[atom_j];
          if (tableCell === undefined)
            tableCell = tableRow[atom_j] = {push: undefined, reductions: new OrderedSet([], Action.equals)};
          if (tableCell.push !== undefined && tableCell.push.dest !== gotoStateNum)
            throw ("Already have a push action for atom " + atom_j + " in state " + state_num + ": supposed to goto state " + tableCell.push.dest + " and now need to go to " + gotoStateNum);
          tableCell.push = new PushAction(gotoStateNum);
        }
      }
    }
    console.log("Done with step 1");
    // Step 2
    this.states = [];
    var spontLookaheads = {};
    var propLookaheads = {};
    for (var i = 0; i < kernelStates.size(); i++) {
      this.states.push(new OrderedSet([], Rule.equals));
      spontLookaheads[i] = {};
      propLookaheads[i] = {};
    }
    init_rule = this.rules[this.start][0];
    spontLookaheads[0][init_rule.id] = new OrderedSet([EOF], Atom.equals);
    var closureCache = {}
    for (var i = 0; i < kernelStates.size(); i++) {
      for (var j = 0; j < this.atoms.size(); j++) {
        this.applyLookaheads(closureCache, spontLookaheads, propLookaheads, kernelStates.get(i), i, this.atoms.get(j));
        // console.log("i = " + i + " j = " + this.atoms.get(j));
      }
    }
    console.log("Done with step 2");
    // Step 3
    var allLookaheads = {}
    for (var i = 0; i < kernelStates.size(); i++) {
      allLookaheads[i] = {};
      for (var j in spontLookaheads[i]) {
        // console.log("i = " + i + ", j = " + j + ", spontLookaheads[i][j] = " + spontLookaheads[i][j]);
        allLookaheads[i][j] = new OrderedSet(spontLookaheads[i][j]);
      }
    }
    console.log("Done with step 3");
    // Step 4
    // console.log("\n\n\n");
    // console.log("spontLookaheads = " + JSON.stringify(spontLookaheads, null, "  "));
    // console.log("propLookaheads = " + JSON.stringify(propLookaheads, null, "  "));
    var changed = true;
    var pass = 0;
    while (changed) {
      changed = false;
      pass++;
      for (var i = 0; i < kernelStates.size(); i++) {
        var state_i = kernelStates.get(i);
        var rnTable_i = this.rnTable[i];
        for (var x in rnTable_i) {
          var action = rnTable_i[x].push;
          if (action !== undefined) {
            var gotoState = action.dest;
            for (var j = 0; j < state_i.size(); j++) {
              var rule_j = state_i.get(j).withLookahead(undefined);
              var prop = propLookaheads[i][rule_j.id] ? propLookaheads[i][rule_j.id][gotoState] : undefined;
              var look = allLookaheads[i][rule_j.id];
              if (prop !== undefined && look !== undefined) {
                for (var k = 0; k < prop.size(); k++) {
                  var id_k = prop.get(k);
                  if (allLookaheads[gotoState][id_k] === undefined)
                    allLookaheads[gotoState][id_k] = new OrderedSet([], Atom.equals);
                  changed = allLookaheads[gotoState][id_k].merge(look) || changed;
                }
              }
            }
          }
        }
      }
    }
    console.log("Done with step 4");
    // console.log("allLookaheads = " + JSON.stringify(allLookaheads, null, "  "));
    // console.log("All rules:")
    // for (var r in RuleFactory.byId)
    //   console.log(r + ": " + RuleFactory.byId[r]);
    // Step 5 -- expand
    for (var i = 0; i < kernelStates.size(); i++) {
      var kernelState_i = kernelStates.get(i);
      var state_i = this.states[i];
      for (var j = 0; j < kernelState_i.size(); j++) {
        var rule_j = kernelState_i.get(j).withLookahead(undefined);
        var lookahead = allLookaheads[i][rule_j.id];
        if (lookahead) {
          for (var k = 0; k < lookahead.size(); k++)
            state_i.add(RuleFactory.make(rule_j.name, rule_j.symbols, lookahead.get(k), rule_j.position, rule_j.action));
        }
      }
    }
    this.states = new OrderedSet(this.states, OrderedSet.equals);
  },

  //////////////////////////////////
  // Algorithm 4.12 (p242) in Dragon book
  applyLookaheads: function(closureCache, spont, prop, rule_set, set_num, symbol) {
    if (this.rnTable[set_num] === undefined) return;
    if (this.rnTable[set_num][symbol] === undefined) return;
    var goto_set_num = undefined;
    var action = this.rnTable[set_num][symbol].push;
    if (action !== undefined) {
      if (goto_set_num !== undefined) {
        console.log("Failure! rnTable contains multiple PushActions for set #" + set_num + " and symbol " + symbol + ": " + actions.toString(true));
        throw(false);
      } else {
        goto_set_num = action.dest;
      }
    }
    
    for (var i = 0; i < rule_set.size(); i++) {
      var rule = rule_set.get(i).withLookahead(undefined);
      var jPrime_rule = RuleFactory.make(rule.name, rule.symbols, HASH, rule.position, rule.action);
      var jPrime = closureCache[jPrime_rule];
      if (jPrime === undefined)
        jPrime = closureCache[jPrime_rule] = this.completeClosure(new OrderedSet([jPrime_rule], Rule.equals), true);
      for (var j = 0; j < jPrime.size(); j++) {
        var rule_j = jPrime.get(j);
        if (rule_j.position < rule_j.symbols.length && rule_j.symbols[rule_j.position].toString() == symbol) {
          if (rule_j.lookahead !== HASH) {
            var new_rule = RuleFactory.make(rule_j.name, rule_j.symbols, undefined, rule_j.position + 1, rule_j.action);
            if (spont[goto_set_num][new_rule.id] === undefined)
              spont[goto_set_num][new_rule.id] = new OrderedSet([], Atom.equals);
            spont[goto_set_num][new_rule.id].add(rule_j.lookahead);
          } else {
            var new_rule = RuleFactory.make(rule_j.name, rule_j.symbols, undefined, rule_j.position + 1, rule_j.action);
            for (var k = 0; k < rule_set.size(); k++) {
              var rule_k = rule_set.get(k).withLookahead(undefined);
              if (Rule.equalsCore(rule, rule_k)) {
                if (prop[set_num][rule_k.id] === undefined)
                  prop[set_num][rule_k.id] = {};
                if (prop[set_num][rule_k.id][goto_set_num] === undefined)
                  prop[set_num][rule_k.id][goto_set_num] = new OrderedSet([]);
                prop[set_num][rule_k.id][goto_set_num].add(new_rule.id);
              }
            }
          }
        }
      }
    }
  },




  printTables: function() {
    var ret = "";
    for (var i = 0; i < this.rnTable.length; i++) {
      var str_action = ""
      for (var j = 0; j < this.atoms.size(); j++) {
        actions = this.rnTable[i][this.atoms.get(j)]
        if (actions.accept)
          str_action += "\n    On " + this.atoms.get(j) + ", " + actions.accept;
        if (actions.push !== undefined)
          str_action += "\n    On " + this.atoms.get(j) + ", " + actions.push;
        if (actions.reductions && actions.reductions.size() > 0)
          str_action += "\n    On " + this.atoms.get(j) + ", " + actions.reductions;
      }
      var s = "In state #" + i + ":";
      if (this.acceptStates[i])
        s += " (ACCEPT STATE)";
      if (str_action)
        s += "\n  Actions:" + str_action;
      if (s !== "") s += "\n";
      ret += s;
    }
    return ret;
  },

  checkForCycles: function() {
    var cyclic = []
    for (var name in this.rules)
      if (this.derivable[name][name])
        cyclic.push(name);
    if (cyclic.length == 0) return false;
    return cyclic;
  }

  // //////////////////////////////////
  // // A LALR(1) ambiguity is a state/token pair that has multiple enabled actions
  // // Returns a list of warning messages
  // //////////////////////////////////
  // checkForLALRAmbiguity: function() {
  //   var ambiguities = []
  //   for (var i = 0; i < this.rnTable.length; i++) {
  //     var tableRow = this.rnTable[i];
  //     for (var name in tableRow) {
  //       if (tableRow.hasOwnProperty(name)) {
  //         var actions = tableRow[name];
  //         if (actions.size() > 1) {
  //           ambiguities.push("In state #" + i + ", conflicting actions on token " + name + ": " + actions);
  //         }
  //       }
  //     }
  //   }
  //   return ambiguities;
  // },

}



exports.Atom = Atom
exports.Nonterm = Nonterm
exports.Token = Token
exports.Rule = Rule
exports.Grammar = Grammar
exports.OrderedSet = OrderedSet
exports.EOF = EOF
exports.EPSILON = EPSILON
exports.SrcLoc = SrcLoc
