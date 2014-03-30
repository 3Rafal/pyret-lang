define([], function() {

  //: -> (code -> printing it on the repl)
  function makeRepl(container, repl, runtime) {
    var items = [];
    var pointer = -1;
    var current = "";
    function loadItem() {
      CM.setValue(items[pointer]);
    }
    function saveItem() {
      items.unshift(CM.getValue());
    }
    function prevItem() {
      if (pointer === -1) {
        current = CM.getValue();
      }
      if (pointer < items.length - 1) {
        pointer++;
        loadItem();
      }
    }
    function nextItem() {
      if (pointer >= 1) {
        pointer--;
        loadItem();
      } else if (pointer === 0) {
        CM.setValue(current);
        pointer--;
      }
    }

    var promptContainer = jQuery("<div id='prompt-container'>");
    var prompt = jQuery("<div>").addClass("repl-prompt");
    promptContainer.append(prompt);

    var output = jQuery("<div id='output' class='cm-s-default'>");
    runtime.stdout = function(str) {
      ct_log(str);
      output.append($("<div>").text(str));
    };

    var clearDiv = jQuery("<div class='clear'>");

    var clearRepl = function() {
      output.empty();
      promptContainer.hide();
      promptContainer.fadeIn(100);
      lastNameRun = 'interactions';
      lastEditorRun = null;
    };

    var clearButton = $("<button>").addClass("blueButton").text("Clear")
      .click(clearRepl);
    var breakButton = $("<button>").addClass("blueButton").text("Stop")
      .click(clearRepl);
    container.append(clearButton).append(breakButton).append(output).append(promptContainer).
      append(clearDiv);


    var runCode = function (src, uiOptions, options) {
      breakButton.attr("disabled", false);
      CM.setOption("readOnly", "nocursor");
      CM.getDoc().eachLine(function (line) {
        CM.addLineClass(line, 'background', 'cptteach-fixed');
      });
      output.empty();
      promptContainer.hide();
      promptContainer.fadeIn(100);
      var defaultReturnHandler = options.check ? checkModePrettyPrint : prettyPrint;
      var thisReturnHandler;
      if (uiOptions.wrappingReturnHandler) {
        thisReturnHandler = uiOptions.wrappingReturnHandler(output);
      } else {
        thisReturnHandler = uiOptions.handleReturn || defaultReturnHandler;
      }
      var thisError;
      if (uiOptions.wrappingOnError) {
        thisError = uiOptions.wrappingOnError(output);
      } else {
        thisError = uiOptions.error || onError;
      }
      var thisWrite = uiOptions.write || write;
      lastNameRun = uiOptions.name || "interactions";
      lastEditorRun = uiOptions.cm || null;
      evaluator.runRepl(uiOptions.name || "run", src, clear, enablePrompt(thisReturnHandler), thisWrite, enablePrompt(thisError), options);
    };

    var enablePrompt = function (handler) { return function (result) {
        breakButton.attr("disabled", true);
        CM.setValue("");
        CM.setOption("readOnly", false);
        CM.getDoc().eachLine(function (line) {
          CM.removeLineClass(line, 'background', 'cptteach-fixed');
        });
        output.get(0).scrollTop = output.get(0).scrollHeight;
        return handler(result);
      };
    }

    var runner = makeLoggingRunCode(function(code, opts, replOpts){
          items.unshift(code);
          pointer = -1;
          var echoContainer = $("<div>");
          var echo = $("<textarea class='repl-echo CodeMirror'>");
          echoContainer.append(echo);
          write(echoContainer);
          var echoCM = CodeMirror.fromTextArea(echo[0], { readOnly: 'nocursor' });
          echoCM.setValue(code);
          write(jQuery('<br/>'));
          breakButton.attr("disabled", false);
          CM.setOption("readOnly", "nocursor");
          CM.getDoc().eachLine(function (line) {
            CM.addLineClass(line, 'background', 'cptteach-fixed');
          });
          makeHighlightingRunCode(runtime, function(src, uiOptions, options) {
            evaluator.runRepl('interactions',
                        src,
                        clear,
                        enablePrompt(uiOptions.wrappingReturnHandler(output)),
                        write,
                        enablePrompt(uiOptions.wrappingOnError(output)),
                        merge(options, _.merge(replOpts, {check: true})));
          })(code, merge(opts, {name: lastNameRun, cm: lastEditorRun || echoCM}), replOpts);
        },
        "interactions");

    var CM = makeEditor(prompt, {
      simpleEditor: true,
      run: runner,
      initial: "",
      cmOptions: {
        extraKeys: {
          'Enter': function(cm) { runner(cm.getValue(), {cm: cm}, {check: true, "type-env": false }); },
          'Shift-Enter': "newlineAndIndent",
          'Up': prevItem,
          'Down': nextItem,
          'Ctrl-Up': "goLineUp",
          'Ctrl-Alt-Up': "goLineUp",
          'Ctrl-Down': "goLineDown",
          'Ctrl-Alt-Down': "goLineDown"
        }
      }
    });

    var lastNameRun = 'interactions';
    var lastEditorRun = null;

    var write = function(dom) {
      output.append(dom);
    };

    var clear = function() {
      allowInput(CM, true)();
    };

    var onError = function(err, editor) {
      ct_log("onError: ", err);
      if (err.message) {
        write(jQuery('<span/>').css('color', 'red').append(err.message));
        write(jQuery('<br/>'));
      }
      clear();
    };

    var prettyPrint = function(result) {
      if (result.hasOwnProperty('_constructorName')) {
        switch(result._constructorName.val) {
        case 'p-num':
        case 'p-bool':
        case 'p-str':
        case 'p-object':
        case 'p-fun':
        case 'p-method':
          whalesongFFI.callPyretFun(
              whalesongFFI.getPyretLib("torepr"),
              [result],
              function(s) {
                var str = pyretMaps.getPrim(s);
                write(jQuery("<pre class='repl-output'>").text(str));
                write(jQuery('<br/>'));
              }, function(e) {
                ct_err("Failed to tostring: ", result);
              });
          return true;
        case 'p-nothing':
          return true;
        default:
          return false;
        }
      } else {
        console.log(result);
        return false;
      }
    };

    var checkModePrettyPrint = function(obj) {
      function drawSuccess(name, message) {
        return $("<div>").text(name +  ": " + message)
          .addClass("check check-success")
          .append("<br/>");
      }
      function drawFailure(name, message) {
        return $('<div>').text(name + ": " + message)
          .addClass("check check-failure")
          .append("<br/>");
      }
      var dict = pyretMaps.toDictionary(obj);
      var blockResults = pyretMaps.toDictionary(pyretMaps.get(dict, "results"));
      function getPrimField(v, field) {
        return pyretMaps.getPrim(pyretMaps.get(pyretMaps.toDictionary(v), field));
      }

      pyretMaps.map(blockResults, function(result) {
        pyretMaps.map(pyretMaps.toDictionary(result), function(checkBlockResult) {
          var cbDict = pyretMaps.toDictionary(checkBlockResult);
          var container = $("<div>");
          var message = $("<p>");
          var name = getPrimField(checkBlockResult, "name");
          container.append("<p>").text(name);
          container.append(message);
          container.addClass("check-block");
          if (pyretMaps.hasKey(cbDict, "err")) {
            var messageText = pyretMaps.get(cbDict, "err");
            if (pyretMaps.hasKey(pyretMaps.toDictionary(messageText), "message")) {
              messageText = getPrimField(pyretMaps.get(cbDict, "err"), "message");
            } else {
              messageText = pyretMaps.getPrim(pyretMaps.get(cbDict, "err"));
            }
            message.text("Check block ended in error: " + messageText);
            container.css({
              "background-color": "red"
            });
          }


          pyretMaps.map(pyretMaps.toDictionary(pyretMaps.get(pyretMaps.toDictionary(checkBlockResult), "results")), function(individualResult) {
            if (pyretMaps.hasKey(pyretMaps.toDictionary(individualResult), "reason")) {
              container.append(drawFailure(
                  getPrimField(individualResult, "name"),
                  getPrimField(individualResult, "reason")));
            } else {
              container.append(drawSuccess(
                  getPrimField(individualResult, "name"),
                  "Success!"));
            }
          });
          output.append(container);
        });
      });
      return true;
    }

    var evaluator = makeEvaluator(container, repl, runtime, prettyPrint);


    var onBreak = function() {
      breakButton.attr("disabled", true);
      evaluator.requestBreak(clear);
    };


    var allowInput = function(CM, clear) { return function() {
      if (clear) {
        CM.setValue("");
      }

      CM.setOption("readOnly", false);;
      CM.getDoc().eachLine(function (line) {
        CM.removeLineClass(line, 'background', 'cptteach-fixed');
      });
      breakButton.attr("disabled", true);

      CM.focus();
    } };

    var onReset = function() {
      evaluator.requestReset(function() {
        output.empty();
        clear();
      });
    };



    breakButton.attr("disabled", true);
    breakButton.click(onBreak);

    return runCode;
  }

  function makeEvaluator(container, repl, runtime, handleReturnValue) {
    var runMainCode = function(name, src, afterRun, returnHandler, writer, onError, options) {
      repl.restartInteractions(src).then(function(result) {
        if(runtime.isSuccessResult(result)) {
          returnHandler(result);
        } else {
          onError(result);
        }
      });
    };

    var runReplCode = function(name, src, afterRun, returnHandler, writer, onError, options) {
      repl.run(src).then(function(result) {
        if(runtime.isSuccessResult(result)) {
          returnHandler(result);
        } else {
          onError(result);
        }
      });
    };

    var breakFun = function(afterBreak) {
      repl.pause(afterBreak);
    };

    var resetFun = function(afterReset) {
      repl.restartInteractions("").then(afterReset);
    };

    return {runMain: runMainCode, runRepl: runReplCode, requestBreak: breakFun, requestReset: resetFun};
  }

  function namedRunner(runFun, name) {
    return function(src, uiOptions, langOptions) {
      runFun(src, merge(uiOptions, { name: name }), langOptions);
    };
  }

  function makeLoggingRunCode(codeRunner, name) {
    return codeRunner;
/*
    var toLog = [];
    function codeLog(src, uiOpts, replOpts) {
      toLog.push({name: name, url: String(window.location), src: src, name: uiOpts.name, time: String(Date.now())});
    }
    function sendLog() {
      if(toLog.length > 0) {
        $.ajax("/notification/code_run", {
          type: "POST",
          dataType: "json",
          data: {run_events: JSON.stringify(toLog)}
        });
        toLog = [];
      }
      window.setTimeout(sendLog, 30000);
    }
    sendLog();
    
    return namedRunner(function(src, uiOpts, replOpts) {
      codeLog(src, uiOpts, replOpts);
      codeRunner(src, uiOpts, replOpts);
    }, name);
*/
  }
  
  return {
    makeRepl: makeRepl
  };


});
