'use strict';

var StringMap = require('./lib/stringmap/stringmap.js');

var FUNC_REGEX   = /^fn=(.+)$/;
var NAME_REGEX   = /^(.*)\s([^\s]*):(\d+)$/;
var NEWLINE      = '\n';
var DEFAULT_NAME = '(anonymous function)';
var DEFAULT_FILE = '(unknown)';
var DEFAULT_LINE = '(?)';

var NO_DIFFERENCE = 'NO_DIFFERENCE';
var THRESHOLD_FACTOR = .05;


var fs = require('fs');
// var _  = require('lodash');

// var compareHits = function (a, b) {
//   return b.self_hits - a.self_hits;
// }

// var compareNames = function (a, b) {
//   if (a.full_name < b.full_name) {
//     return -1;
//   }
//   if (a.full_name > b.full_name) {
//     return 1;
//   }
//   return 0;
// }

// return StringMap :: keys -> values,
//   keys:   full_name :: <string>
//   values: [{name :: <string>, self_hits :: <number>,
//            self_ms :: <number>}]
function readFile(filename, keepUnknowns) {
  var src = fs.readFileSync(filename, {'encoding': 'UTF-8'});
  var lines = src.split(NEWLINE);

  var functionMap = {};

  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(FUNC_REGEX);
    if (match) {
      var theseData = lines[i+1].split(' ');
      var selfMs    = parseInt(theseData[1]);
      var selfHits  = parseInt(theseData[2]);

      var fnName    = match[1];
      var nameData  = fnName.match(NAME_REGEX);
      var name      = nameData[1] || DEFAULT_NAME;
      var file      = nameData[2] || DEFAULT_FILE;
      var line      = nameData[3] || DEFAULT_LINE;

      var includeMe = keepUnknowns ||
        ((file !== DEFAULT_FILE) && (line !== DEFAULT_LINE));

      if (includeMe) {
        var newObj = {
            name: name,
            file: file,
            line: line,
            self_ms: selfMs,
            self_hits: selfHits
          };

        if (functionMap.hasOwnProperty(fnName)) {
          functionMap[fnName].push(newObj);  
        } else {
          functionMap[fnName] = [newObj];
        }
        
      };
    }
  }
  return new StringMap(functionMap);  
}

// @param functions :: StringMap
// return [keys] for which there are more than one callgrind entry
function getDuplicates (functions) {
  var keys = [];
  functions.forEach(function (v, k) {
    if (v.length > 1) {
      keys.push(k);
    }
  });
  return keys;
}

// @param functions :: StringMap
function totalByKey (functions, key) {
  var total = 0;
  functions.forEach(function (v, k) {
    for (var i = v.length - 1; i >= 0; i--) {
      total += v[i][key];
    };    
  });
  return total;
}

function totalMs (functions) {
  return totalByKey(functions, 'self_ms')
}

function totalHits (functions) {
  return totalByKey(functions, 'self_hits')
}

function assertSameSource(obj1, obj2) {
  console.assert(obj1.name === obj2.name);
  console.assert(obj1.file === obj2.file);
  console.assert(obj1.line === obj2.line);
}

function percentageDiff (num1, num2) {
  if (num1 === 0) {
    return 0;
  } else {
    return ((100 * (num2 - num1))/num1)  
  }
}

function diff (file1, file2) {
  var functions1 = readFile(file1, false);
  var functions2 = readFile(file2, false);

  var ms2 = totalMs(functions2);
  var ms1 = totalMs(functions1);
  var hits2 = totalHits(functions2);
  var hits1 = totalHits(functions1);

  var relMsDiff   = percentageDiff(ms1, ms2);
  var relHitsDiff = percentageDiff(hits1, hits2);

  var relMsDiffABS   = Math.abs(relMsDiff);
  var relHitsDiffABS = Math.abs(relHitsDiff);

  // console.log('absolute ms diff:  ', ms2 - ms1);
  // console.log('absolute hits diff:', hits2 - hits1);
  // console.log('relative ms diff:  ', relMsDiff.toFixed(2) + '%');
  // console.log('relative hits diff:', relHitsDiff.toFixed(2) + '%');

  var difference = new StringMap();

  var thresholdMs   = THRESHOLD_FACTOR * Math.abs(ms2 - ms1);
  var thresholdHits = THRESHOLD_FACTOR * Math.abs(hits2 - hits1);

  // console.log('thresholds:', thresholdMs, thresholdHits);

  functions1.forEach(function (v1, k) {
    var obj1 = v1[0];

    if (functions2.has(k)) {
      var obj2 = functions2.get(k)[0];

      assertSameSource(obj1, obj2);

      var newObj = {
          name: obj1.name,
          file: obj1.file,
          line: obj1.line,
          self_ms_diff: obj2.self_ms - obj1.self_ms,
          self_hits_diff: obj2.self_hits - obj1.self_hits
        };

      var msPercentDiff   = Math.abs(percentageDiff(obj1.self_ms, obj2.self_ms));
      var hitsPercentDiff = Math.abs(percentageDiff(obj1.self_hits, obj2.self_hits));
      
      var includeMe =
        msPercentDiff > relMsDiffABS
          && Math.abs(newObj.self_ms_diff) > thresholdMs
          && hitsPercentDiff > relHitsDiffABS
          && Math.abs(newObj.self_hits_diff) > thresholdHits;

      // console.log(msPercentDiff, relMsDiffABS.toFixed(2), newObj.self_ms_diff, thresholdMs);

      if (includeMe) {
        difference.set(k, newObj);  
      } else {
        // difference.set(k, NO_DIFFERENCE);
      };
    } else {
      //console.log('Function <' + k + '> missing from second profile.');
    }
  });

  return difference;

}

/******************************************************************************/

var numArgs = process.argv.length;

if (numArgs === 3) {
  /* single file */
  var functions = readFile(process.argv[2], true);
  
  console.log('ms:  ', totalMs(functions));
  console.log('hits:', totalHits(functions));

} else if (numArgs === 4) {
  /* diff of two files */
  var file1 = process.argv[2];
  var file2 = process.argv[3];


  var difference = diff(file1, file2);

  console.log(difference.items());

  // difference.forEach(function (obj, k) {
  //   if (obj !== NO_DIFFERENCE) {
  //    console.log(obj);  
  //   };
  // });

} else {
  console.log('Usage: node analyze-callgrind.js <file.profile>+')
}



