#lang scribble/manual
@(require "../scribble-api.rkt")

@title{Pyret Documentation}

@nested{ This document has detailed information on the Pyret grammar and the
behavior of its expression forms and built-in libraries. It is unfortunately
incomplete and a work in progress; the language is moving somewhat quickly and
the documentation sometimes lags, especially with respect to libraries. If you
want to do something in a program and you can't find how in this document,
feel free to post a message on the
@link["https://groups.google.com/forum/#!forum/pyret-discuss" "Pyret discussion
list"], and we'll be happy to help.  }


@include-section["Pyret-Tutorial/lander.scrbl"]

@include-section["language-concepts.scrbl"]

@include-section["libraries.scrbl"]

@include-section["trove/globals.scrbl"]

