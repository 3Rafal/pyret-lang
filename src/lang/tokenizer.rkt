#lang racket/base

(require parser-tools/lex
         ragg/support
         racket/set
         racket/port
         racket/list
         "grammar.rkt")
(provide tokenize)

(define NAME 'NAME)
(define NUMBER 'NUMBER)
(define STRING 'STRING)
(define WS 'WS)
(define ENDMARKER 'ENDMARKER)
(define COMMENT 'COMMENT)
(define BACKSLASH 'BACKSLASH)
(define PARENSPACE 'PARENSPACE)
(define PARENNOSPACE 'PARENNOSPACE)

(define-lex-abbrev
  identifier-chars
  (union #\_ (char-range #\a #\z) (char-range #\A #\Z)))

;; NOTE(dbp): '-' is lexed as misc, so that it can be used as a prefix for
;; numbers as well as for binops
(define-lex-abbrev
  operator-chars
  (union "+" "-" "*" "/" "<=" ">=" "==" "<>" "<" ">"))

(define (get-middle-pos n pos)
  (position (+ n (position-offset pos))
            (position-line pos)
            (+ n (position-col pos))))
  
(define (tokenize ip)
  (port-count-lines! ip)
  (define extra-token #f)
  (define my-lexer
    (lexer-src-pos
     ;; open parenthesis: preceded by space and not
     ;; NOTE(dbp): we handle this specially so that we can parse
     ;; function application and binary operators unambiguously. By
     ;; doing this at the tokenizer level, we don't need to deal
     ;; with whitespace in the grammar.
     ["(("
      (let [(middle-pos (get-middle-pos 1 start-pos))]
      (return-without-pos
       (list (position-token (token PARENNOSPACE "(") start-pos middle-pos)
             (position-token (token PARENSPACE "(") middle-pos end-pos))))]
     [(concatenation operator-chars "(")
      (let* [(op (substring lexeme 0
                           (- (string-length lexeme) 1)))
            (op-len (string-length op))
            (middle-pos (get-middle-pos op-len start-pos))]
        (return-without-pos
         (list (position-token (token op op) start-pos middle-pos)
               (position-token (token PARENSPACE "(") middle-pos end-pos))))]
     [(concatenation whitespace "(")
      (token PARENSPACE "(")]
     ["("
      (token PARENNOSPACE "(")]
     ;; names
     [(concatenation identifier-chars
                     (repetition 0 +inf.0
                                 (union #\- numeric identifier-chars)))
      ;; NOTE(dbp): we are getting literals from the grammar and making
      ;; them not be NAME anymore.
      (cond [(set-member? all-token-types (string->symbol lexeme))
             (token (string->symbol lexeme) lexeme)]
            [else
             (token NAME lexeme)])]
     ;; numbers
     [(concatenation
       (repetition 1 +inf.0 numeric)
       (union ""
              (concatenation
               #\.
               (repetition 1 +inf.0 numeric))))
      (token NUMBER lexeme)]
     ;; strings
     [(concatenation
       "\""
       (repetition 0 +inf.0 (union "\\\"" (intersection
                                           (char-complement #\")
                                           (char-complement #\newline))))
       "\"")
      (token STRING lexeme)]
     [(concatenation
       "'"
       (repetition 0 +inf.0 (union "\\'" (intersection
                                          (char-complement #\')
                                          (char-complement #\newline))))
       "'")
      (token STRING lexeme)]
     ;; brackets
     [(union "[" "]" "{" "}" ")")
      (token lexeme lexeme)]
     ;; whitespace
     [whitespace
      (token WS lexeme #:skip? #t)]
     ;; operators
     [operator-chars
      (token lexeme lexeme)]
     ;; misc
     [(union "." "," "->" "::" ":" "|" "=>" "^" "=" ":=")
      (token lexeme lexeme)]
     ;; comments
     [(concatenation #\# (repetition 0 +inf.0
                                     (char-complement #\newline)))
      (token COMMENT lexeme #:skip? #t)]
     ;; semicolons - for the to-be-removed do notation
     [#\;
      (token lexeme lexeme)]
     ;; backslash - for the to-be-changed lambda notation
     [#\\
      (token BACKSLASH lexeme)]
     ;; end terminator
     [(eof)
      (void)]
     ))
    (define (next-token)
      (if extra-token
          (let [(rv extra-token)]
            (set! extra-token #f)
            rv)
          (let [(tokens (my-lexer ip))]
            (cond
             [(list? tokens) (set! extra-token (second tokens))
                             (first tokens)]
             [else tokens]))))
    next-token)
