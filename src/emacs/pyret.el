(defvar pyret-mode-hook nil)
(defun pyret-smart-tab ()
  "This smart tab is minibuffer compliant: it acts as usual in
    the minibuffer. Else, if mark is active, indents region. Else if
    point is at the end of a symbol, expands it. Else indents the
    current line."
  (interactive)
  (if (minibufferp)
      (unless (minibuffer-complete)
        (dabbrev-expand nil))
    (if mark-active
        (indent-region (region-beginning)
                       (region-end))
        (indent-for-tab-command))))
(defvar pyret-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") 'newline-and-indent)
    (define-key map (kbd "|") 
      (function (lambda (&optional N) 
                  (interactive "^p")
                  (or N (setq N 1))
                  (self-insert-command N)
                  (pyret-smart-tab))))
    map)
  "Keymap for Pyret major mode")

(defconst pyret-ident-regex "[a-zA-Z_][a-zA-Z0-9$_\\-]*")
(defconst pyret-keywords-regex 
  (regexp-opt
   '("fun" "var" "cond" "when" "import" "provide"
     "data" "end" "do" "try" "except" "for" "from"
     "as" "with" "sharing")))
(defconst pyret-punctuation-regex
  (regexp-opt '(":" "::" "=>" "->" "<" ">" "," "^" "(" ")" "[" "]" "{" "}" "." "\\" ";" "|" "=")))
(defconst pyret-font-lock-keywords-1
  (list
   `(,(concat 
       "\\(^\\|[ \t]\\|" pyret-punctuation-regex "\\)\\("
       pyret-keywords-regex
       "\\)\\($\\|[ \t]\\|" pyret-punctuation-regex "\\)") 
     (1 font-lock-builtin-face) (2 font-lock-keyword-face) (3 font-lock-builtin-face))
   `(,pyret-punctuation-regex . font-lock-builtin-face)
   `(,(concat "\\<" (regexp-opt '("true" "false") t) "\\>") . font-lock-constant-face)
   )
  "Minimal highlighting expressions for Pyret mode")

(defconst pyret-font-lock-keywords-2
  (append
   pyret-font-lock-keywords-1
   (list
    ;; "| else" is a builtin
    '("\\([|]\\)[ \t]+\\(else\\)" (1 font-lock-builtin-face) (2 font-lock-keyword-face))
    ;; "data IDENT"
    `(,(concat "\\(\\<data\\>\\)[ \t]+\\(" pyret-ident-regex "\\)") 
      (1 font-lock-keyword-face) (2 font-lock-type-face))
    ;; "| IDENT(whatever) =>" is a function name
    `(,(concat "\\([|]\\)[ \t]+\\(" pyret-ident-regex "\\)(.*?)[ \t]*=>")
      (1 font-lock-builtin-face) (2 font-lock-function-name-face))
    ;; "| IDENT =>" is a variable name
    `(,(concat "\\([|]\\)[ \t]+\\(" pyret-ident-regex "\\)[ \t]*=>")
      (1 font-lock-builtin-face) (2 font-lock-variable-name-face))
    ;; "| IDENT (", "| IDENT with", "| IDENT" are all considered type names
    `(,(concat "\\([|]\\)[ \t]+\\(" pyret-ident-regex "\\)[ \t]*\\(?:(\\|with\\|$\\)")
      (1 font-lock-builtin-face) (2 font-lock-type-face))
    `(,(concat "\\(" pyret-ident-regex "\\)[ \t]*::[ \t]*\\(" pyret-ident-regex "\\)") 
      (1 font-lock-variable-name-face) (2 font-lock-type-face))
    `(,(concat "\\(->\\)[ \t]*\\(" pyret-ident-regex "\\)")
      (1 font-lock-builtin-face) (2 font-lock-type-face))
    `(,(regexp-opt '("<" ">")) . font-lock-builtin-face)
    `(,(concat "\\(" pyret-ident-regex "\\)[ \t]*\\((\\|:\\)")  (1 font-lock-function-name-face))
    `(,pyret-ident-regex . font-lock-variable-name-face)
    ))
  "Additional highlighting for Pyret mode")

(defconst pyret-font-lock-keywords pyret-font-lock-keywords-2
  "Default highlighting expressions for Pyret mode")


(defconst pyret-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?_ "w" st)
    (modify-syntax-entry ?$ "w" st)
    (modify-syntax-entry ?# "< b" st)
    (modify-syntax-entry ?\n "> b" st)
    (modify-syntax-entry ?: "." st)
    (modify-syntax-entry ?^ "." st)
    (modify-syntax-entry ?= "." st)
    (modify-syntax-entry ?- "." st)
    (modify-syntax-entry ?, "." st)
    (modify-syntax-entry ?' "\"" st)
    (modify-syntax-entry ?{ "(}" st)
    (modify-syntax-entry ?} "){" st)
    (modify-syntax-entry ?. "." st)
    (modify-syntax-entry ?\\ "." st)
    (modify-syntax-entry ?\; "." st)
    (modify-syntax-entry ?| "." st)
    st)
  "Syntax table for pyret-mode")



;; Eleven (!) kinds of indentation:
;; bodies of functions
;; bodies of cases (these indent twice, but lines beginning with a pipe indent once)
;; bodies of data declarations (these also indent twice excepting the lines beginning with a pipe)
;; bodies of sharing declarations
;; bodies of try blocks
;; bodies of except blocks
;; additional lines inside unclosed parentheses
;; bodies of objects (and list literals)
;; unterminated variable declarations
;; field definitions
;; lines beginning with a period

(defvar pyret-nestings (vector))
(defvar pyret-nestings-dirty t)

(defsubst pyret-is-word (c)
  (and c
       (or 
        (and (>= c ?0) (<= c ?9)) ;; digit
        (and (>= c ?a) (<= c ?z)) ;; lowercase
        (and (>= c ?A) (<= c ?Z)) ;; uppercase
        (= c ?_)
        (= c ?$)
        (= c ?\\)
        (= c ?-))))

(defsubst pyret-keyword (s) 
  (if (pyret-is-word (preceding-char)) nil
    (let ((i 0)
          (slen (length s)))
      (cond
       ((< (point-max) (+ (point) slen))              nil)
       ((pyret-is-word (char-after (+ (point) slen))) nil)
       (t
        (catch 'break
          (while (< i slen)
            (if (= (aref s i) (char-after (+ (point) i)))
                (incf i)
              (throw 'break nil)))
          t))))))
      
(defsubst pyret-FUN () (pyret-keyword "fun"))
(defsubst pyret-VAR () (pyret-keyword "var"))
(defsubst pyret-CASES () (pyret-keyword "cond"))
(defsubst pyret-WHEN () (pyret-keyword "when"))
(defsubst pyret-IMPORT () (pyret-keyword "import"))
(defsubst pyret-PROVIDE () (pyret-keyword "provide"))
(defsubst pyret-DATA () (pyret-keyword "data"))
(defsubst pyret-END () (pyret-keyword "end"))
(defsubst pyret-DO () (pyret-keyword "do"))
(defsubst pyret-FOR () (pyret-keyword "for"))
(defsubst pyret-FROM () (pyret-keyword "from"))
(defsubst pyret-TRY () (pyret-keyword "try"))
(defsubst pyret-EXCEPT () (pyret-keyword "except"))
(defsubst pyret-AS () (pyret-keyword "as"))
(defsubst pyret-SHARING () (pyret-keyword "sharing"))
(defsubst pyret-WITH () (pyret-keyword "with"))
(defsubst pyret-PIPE () (= (char-after) ?|))
(defsubst pyret-COLON () (= (char-after) ?:))
(defsubst pyret-COMMA () (= (char-after) ?,))
(defsubst pyret-LBRACK () (= (char-after) ?[))
(defsubst pyret-RBRACK () (= (char-after) ?]))
(defsubst pyret-LBRACE () (= (char-after) ?{))
(defsubst pyret-RBRACE () (= (char-after) ?}))
(defsubst pyret-LANGLE () (= (char-after) ?<))
(defsubst pyret-RANGLE () (= (char-after) ?>))
(defsubst pyret-LPAREN () (= (char-after) ?())
(defsubst pyret-RPAREN () (= (char-after) ?)))
(defsubst pyret-EQUALS () (looking-at "=[^>]"))
(defsubst pyret-COMMENT () (looking-at "[ \t]*#.*$"))

(defun pyret-has-top (stack top)
  (if top
      (and (equal (car-safe stack) (car top))
           (pyret-has-top (cdr stack) (cdr top)))
    t))

(defstruct
  (pyret-indent
   (:constructor pyret-make-indent (fun cases data shared try except parens object vars fields initial-period))
   :named)
   fun cases data shared try except parens object vars fields initial-period)

(defun pyret-map-indent (f total delta)
  (let* ((len (length total))
         (ret (make-vector len nil))
         (i 1))
    (aset ret 0 (aref total 0))
    (while (< i len)
      (aset ret i (funcall f (aref total i) (aref delta i)))
      (incf i))
    ret))
(defmacro pyret-add-indent (total delta)  `(pyret-map-indent '+ ,total ,delta))
(defmacro pyret-add-indent! (total delta) `(setf ,total (pyret-add-indent ,total ,delta)))
(defmacro pyret-sub-indent (total delta) `(pyret-map-indent '- ,total ,delta))
(defmacro pyret-sub-indent! (total delta) `(setf ,total (pyret-sub-indent ,total ,delta)))
(defmacro pyret-mul-indent (total delta) `(pyret-map-indent '* ,total ,delta))
(defun pyret-sum-indents (total) 
  (let ((i 1)
        (sum 0)
        (len (length total)))
    (while (< i len)
      (incf sum (aref total i))
      (incf i))
    sum))
(defun pyret-make-zero-indent () (pyret-make-indent 0 0 0 0 0 0 0 0 0 0 0))
(defun pyret-zero-indent! (ind)
  (let ((i 1)
        (len (length ind)))
    (while (< i len)
      (aset ind i 0)
      (incf i))))
(defun pyret-copy-indent! (dest src)
  (let ((i 1)
        (len (length dest)))
    (while (< i len)
      (aset dest i (aref src i))
      (incf i))))

(defun pyret-print-indent (ind)
  (format
   "Fun %d, Cases %d, Data %d, Shared %d, Try %d, Except %d, Parens %d, Object %d, Vars %d, Fields %d, Period %d"
   (pyret-indent-fun ind)
   (pyret-indent-cases ind)
   (pyret-indent-data ind)
   (pyret-indent-shared ind)
   (pyret-indent-try ind)
   (pyret-indent-except ind)
   (pyret-indent-parens ind)
   (pyret-indent-object ind)
   (pyret-indent-vars ind)
   (pyret-indent-fields ind)
   (pyret-indent-initial-period ind)))

(defun pyret-compute-nestings ()
  (let ((nlen (if pyret-nestings (length pyret-nestings) 0))
        (doclen (count-lines (point-min) (point-max))))
    (cond 
     ((>= (+ doclen 1) nlen)
      (setq pyret-nestings (vconcat pyret-nestings (make-vector (+ 1 (- doclen nlen)) (pyret-make-zero-indent)))))
     (t nil)))
  ;; open-* is the running count as of the *beginning of the line*
  ;; cur-opened-* is the count of how many have been opened on this line
  ;; cur-closed-* is the count of how many have been closed on this line
  ;; defered-opened-* is the count of how many have been opened on this line, but should not be indented
  ;; defered-closed-* is the count of how many have been closed on this line, but should not be outdented
  (let ((n 0)
        (open       (pyret-make-zero-indent))
        (cur-opened (pyret-make-zero-indent))
        (cur-closed (pyret-make-zero-indent))
        (defered-opened (pyret-make-zero-indent))
        (defered-closed (pyret-make-zero-indent))
        (opens nil))
    (save-excursion
      (goto-char (point-min))
      (pyret-copy-indent! (aref pyret-nestings n) open)
      (while (not (eobp))
        (pyret-zero-indent! cur-opened) (pyret-zero-indent! cur-closed)
        (pyret-zero-indent! defered-opened) (pyret-zero-indent! defered-closed)
        ;;(message "At start of line %d, open is %s" (+ n 1) open)
        (while (not (eolp))
          (cond
           ((pyret-COMMENT)
            (end-of-line))
           ((and (looking-at "[^ \t]") (pyret-has-top opens '(needsomething)))
            (pop opens) ;; don't advance, because we may need to process that text
            (when (and (pyret-has-top opens '(var))
                     (> (pyret-indent-vars defered-opened) 0)) 
              (decf (pyret-indent-vars defered-opened))
              (pop opens))) ;; don't indent if we've started a RHS already
           ((looking-at "^[ \t]*[.^]")
            (incf (pyret-indent-initial-period cur-opened))
            (incf (pyret-indent-initial-period defered-closed))
            (goto-char (match-end 0)))
           ((pyret-COLON)
            (cond
             ((or (pyret-has-top opens '(wantcolon))
                  (pyret-has-top opens '(wantcolonorequal)))
              (pop opens))
             ((or (pyret-has-top opens '(object))
                  (pyret-has-top opens '(shared)))
                  ;;(pyret-has-top opens '(data)))
              ;;(message "Line %d, saw colon in context %s, pushing 'field" (+ 1 n) (car-safe opens))
              (incf (pyret-indent-fields defered-opened))
              (push 'field opens)
              (push 'needsomething opens)))
            (forward-char))
           ((pyret-COMMA)
            (when (pyret-has-top opens '(field))
              (pop opens)
              (cond ;; if a field was just opened (or will be opened), ignore it
               ((> (pyret-indent-fields cur-opened) 0) 
                ;;(message "In comma, cur-opened-fields > 0, decrementing")
                (decf (pyret-indent-fields cur-opened)))
               ((> (pyret-indent-fields defered-opened) 0)
                ;;(message "In comma, defered-opened-fields > 0, decrementing")
                (decf (pyret-indent-fields defered-opened)))
               (t 
                ;;(message "In comma, incrementing defered-closed-fields")
                (incf (pyret-indent-fields defered-closed))))) ;; otherwise decrement the running count
            (forward-char))
           ((pyret-EQUALS)
            (cond
             ((pyret-has-top opens '(wantcolonorequal))
              (pop opens))
             (t 
              (while (pyret-has-top opens '(var))
                (pop opens)
                ;;(message "Line %d, Seen equals, and opens is %s, incrementing cur-closed-vars" (1+ n) opens)
                (incf (pyret-indent-vars cur-closed)))
              ;;(message "Line %d, Seen equals, and opens is %s, incrementing defered-opened-vars" (1+ n) opens)
              (incf (pyret-indent-vars defered-opened))
              (push 'var opens)
              (push 'needsomething opens)))
            (forward-char))
           ((pyret-VAR)
            ;;(message "Line %d, Seen var, current text is '%s', and opens is %s, incrementing defered-opened-vars" (1+ n) (buffer-substring (point) (min (point-max) (+ 10 (point)))) opens)
            (incf (pyret-indent-vars defered-opened))
            (push 'var opens)
            (push 'needsomething opens)
            (push 'wantcolonorequal opens)
            (forward-char 3))
           ((pyret-FUN)
            (incf (pyret-indent-fun defered-opened))
            (push 'fun opens)
            (push 'wantcolon opens)
            (push 'wantcloseparen opens)
            (push 'wantopenparen opens)
            (forward-char 3))
           ((pyret-WHEN) ;when indents just like funs
            (incf (pyret-indent-fun defered-opened))
            (push 'when opens)
            (push 'wantcolon opens)
            (forward-char 4))
           ((pyret-FOR) ;for indents just like funs
            (incf (pyret-indent-fun defered-opened))
            (push 'for opens)
            (push 'wantcolon opens)
            (forward-char 3))
           ((looking-at "[ \t]+") (goto-char (match-end 0)))
           ((pyret-CASES)
            (incf (pyret-indent-cases defered-opened))
            (push 'cases opens)
            (push 'wantcolon opens)
            (forward-char 4))
           ((pyret-DATA)
            (incf (pyret-indent-data defered-opened))
            (push 'data opens)
            (push 'wantcolon opens)
            (push 'needsomething opens)
            (forward-char 4))
           ((pyret-PIPE)
            (cond 
             ((or (pyret-has-top opens '(object data))
                  (pyret-has-top opens '(field object data)))
              (incf (pyret-indent-object cur-closed))
              (cond
               ((pyret-has-top opens '(field))
                (pop opens)
                (cond ;; if a field was just opened (or will be opened), ignore it
                 ((> (pyret-indent-fields cur-opened) 0) 
                  ;;(message "In pipe, cur-opened-fields > 0, decrementing")
                  (decf (pyret-indent-fields cur-opened)))
                 ((> (pyret-indent-fields defered-opened) 0)
                  ;;(message "In pipe, defered-opened-fields > 0, decrementing")
                  (decf (pyret-indent-fields defered-opened)))
                 (t 
                  ;;(message "In pipe, incrementing cur-closed-fields")
                  (incf (pyret-indent-fields cur-closed)))))) ;; otherwise decrement the running count
              (if (pyret-has-top opens '(object))
                  (pop opens)))
             ((pyret-has-top opens '(data))
              (push 'needsomething opens)
              ))
            (forward-char))
           ((pyret-WITH)
            (cond
             ((pyret-has-top opens '(wantopenparen wantcloseparen data))
              (pop opens) (pop opens)
              (incf (pyret-indent-object defered-opened))
              (push 'object opens))
             ((pyret-has-top opens '(data))
              (incf (pyret-indent-object defered-opened))
              (push 'object opens)))
            (forward-char 4))
           ((pyret-PROVIDE)
            (push 'provide opens)
            (forward-char 7))
           ((pyret-SHARING)
            (incf (pyret-indent-data cur-closed))
            (incf (pyret-indent-shared defered-opened))
            (cond 
             ((pyret-has-top opens '(object data))
              (pop opens) (pop opens)
              (incf (pyret-indent-object cur-closed))
              (push 'shared opens))
             ((pyret-has-top opens '(data))
              (pop opens)
              (push 'shared opens)))
            (forward-char 7))
           ((pyret-TRY)
            (incf (pyret-indent-try defered-opened))
            (push 'try opens)
            (push 'wantcolon opens)
            (forward-char 3))
           ((pyret-EXCEPT)
            (incf (pyret-indent-try cur-closed))
            (incf (pyret-indent-except defered-opened))
            (when (pyret-has-top opens '(try))
              (pop opens)
              (push 'except opens)
              (push 'wantcolon opens)
              (push 'wantcloseparen opens)
              (push 'wantopenparen opens))
            (forward-char 6))
           ;; ((LANGLE)
           ;;  (incf open-parens) (incf cur-opened-parens)
           ;;  (push 'angle opens)
           ;;  (forward-char))
           ;; ((RANGLE)
           ;;  (decf open-parens) (incf cur-closed-parens)
           ;;  (if (pyret-has-top opens '(angle))
           ;;      (pop opens))
           ;;  (forward-char))
           ((pyret-LBRACK)
            (incf (pyret-indent-object defered-opened))
            (push 'array opens)
            (forward-char))
           ((pyret-RBRACK)
            (save-excursion
              (beginning-of-line)
              (if (looking-at "^[ \t]*\\]")
                  (incf (pyret-indent-object cur-closed))
                (incf (pyret-indent-object defered-closed))))
            (if (pyret-has-top opens '(array))
                (pop opens))
            (while (pyret-has-top opens '(var))
              (pop opens)
              ;;(message "Line %d, Seen rbrack, and opens is %s, incrementing defered-closed-vars" (1+ n) opens)
              (incf (pyret-indent-vars defered-closed)))
            (forward-char))
           ((pyret-LBRACE)
            (incf (pyret-indent-object defered-opened))
            (push 'object opens)
            (forward-char))
           ((pyret-RBRACE)
            (save-excursion
              (beginning-of-line)
              (if (looking-at "^[ \t]*\\}")
                  (incf (pyret-indent-object cur-closed))
                (incf (pyret-indent-object defered-closed))))
            (when (pyret-has-top opens '(field))
              (pop opens)
              (cond ;; if a field was just opened (or will be opened), ignore it
               ((> (pyret-indent-fields cur-opened) 0) 
                ;;(message "In rbrace, cur-opened-fields > 0, decrementing")
                (decf (pyret-indent-fields cur-opened)))
               ((> (pyret-indent-fields defered-opened) 0)
                ;;(message "In rbrace, defered-opened-fields > 0, decrementing")
                (decf (pyret-indent-fields defered-opened)))
               (t 
                ;;(message "In rbrace, incrementing cur-closed-fields")
                (incf (pyret-indent-fields cur-closed))))) ;; otherwise decrement the running count
            (if (pyret-has-top opens '(object))
                (pop opens))
            (while (pyret-has-top opens '(var))
              (pop opens)
              ;;(message "Line %d, Seen rbrace, and opens is %s, incrementing defered-closed-vars" (1+ n) opens)
              (incf (pyret-indent-vars defered-closed)))
            (forward-char))
           ((pyret-LPAREN)
            (incf (pyret-indent-parens defered-opened))
            (cond
             ((pyret-has-top opens '(wantopenparen))
              (pop opens))
             ((or (pyret-has-top opens '(object))
                  (pyret-has-top opens '(shared))) ; method in an object or sharing section
              (push 'fun opens)
              (push 'wantcolon opens)
              (push 'wantcloseparen opens)
              (incf (pyret-indent-fun defered-opened)))
             (t
              (push 'wantcloseparen opens)))
            (forward-char))
           ((pyret-RPAREN)
            (incf (pyret-indent-parens defered-closed))
            (if (pyret-has-top opens '(wantcloseparen))
                (pop opens))
            (while (pyret-has-top opens '(var))
              (pop opens)
              ;;(message "Line %d, Seen rparen, and opens is %s, incrementing defered-closed-vars" (1+ n) opens)
              (incf (pyret-indent-vars defered-closed)))
            (forward-char))
           ((pyret-END)
            (when (pyret-has-top opens '(object data))
              (incf (pyret-indent-object cur-closed))
              (pop opens))
            (let ((h (car-safe opens))
                  (still-unclosed t))
              (while (and still-unclosed opens)
                (cond
                 ;; Things that are not counted
                 ;; provide, wantcolon, wantcolonorequal, needsomething, wantopenparen
                 ;; Things that are counted but not closable by end:
                 ((or (equal h 'object) (equal h 'array))
                  (cond 
                   ((> (pyret-indent-object cur-opened) 0) (decf (pyret-indent-object cur-opened)))
                   ((> (pyret-indent-object defered-opened) 0) (decf (pyret-indent-object defered-opened)))
                   (t (incf (pyret-indent-object cur-closed)))))
                 ((equal h 'wantcloseparen)
                  (cond
                   ((> (pyret-indent-parens cur-opened) 0) (decf (pyret-indent-parens cur-opened)))
                   ((> (pyret-indent-parens defered-opened) 0) (decf (pyret-indent-parens defered-opened)))
                   (t (incf (pyret-indent-parens cur-closed)))))
                 ((equal h 'field)
                  (cond
                   ((> (pyret-indent-fields cur-opened) 0) (decf (pyret-indent-fields cur-opened)))
                   ((> (pyret-indent-fields defered-opened) 0) (decf (pyret-indent-fields defered-opened)))
                   (t (incf (pyret-indent-fields cur-closed)))))
                 ((equal h 'var)
                  (cond
                   ((> (pyret-indent-vars cur-opened) 0) (decf (pyret-indent-vars cur-opened)))
                   ((> (pyret-indent-vars defered-opened) 0) (decf (pyret-indent-vars defered-opened)))
                   (t (incf (pyret-indent-vars cur-closed)))))
                 ;; Things that are counted and closeable by end
                 ((or (equal h 'fun) (equal h 'when) (equal h 'for))
                  (cond
                   ((> (pyret-indent-fun cur-opened) 0) (decf (pyret-indent-fun cur-opened)))
                   ((> (pyret-indent-fun defered-opened) 0) (decf (pyret-indent-fun defered-opened)))
                   (t (incf (pyret-indent-fun cur-closed))))
                  (setq still-unclosed nil))
                 ((equal h 'cases)
                  (cond
                   ((> (pyret-indent-cases cur-opened) 0) (decf (pyret-indent-cases cur-opened)))
                   ((> (pyret-indent-cases defered-opened) 0) (decf (pyret-indent-cases defered-opened)))
                   (t (incf (pyret-indent-cases cur-closed))))
                  (setq still-unclosed nil))
                 ((equal h 'data)
                  (cond
                   ((> (pyret-indent-data cur-opened) 0) (decf (pyret-indent-data cur-opened)))
                   ((> (pyret-indent-data defered-opened) 0) (decf (pyret-indent-data defered-opened)))
                   (t (incf (pyret-indent-data cur-closed))))
                  (setq still-unclosed nil))
                 ((equal h 'shared)
                  (cond
                   ((> (pyret-indent-shared cur-opened) 0) (decf (pyret-indent-shared cur-opened)))
                   ((> (pyret-indent-shared defered-opened) 0) (decf (pyret-indent-shared defered-opened)))
                   (t (incf (pyret-indent-shared cur-closed))))
                  (setq still-unclosed nil))
                 ((equal h 'try)
                  (cond
                   ((> (pyret-indent-try cur-opened) 0) (decf (pyret-indent-try cur-opened)))
                   ((> (pyret-indent-try defered-opened) 0) (decf (pyret-indent-try defered-opened)))
                   (t (incf (pyret-indent-try cur-closed))))
                  (setq still-unclosed nil))
                 ((equal h 'except)
                  (cond
                   ((> (pyret-indent-except cur-opened) 0) (decf (pyret-indent-except cur-opened)))
                   ((> (pyret-indent-except defered-opened) 0) (decf (pyret-indent-except defered-opened)))
                   (t (incf (pyret-indent-except cur-closed))))
                  (setq still-unclosed nil))
                 )
                (pop opens)
                (setq h (car-safe opens))))
            (forward-char 3))
           (t (if (not (eobp)) (forward-char)))))
        ;;(message "At end   of line %d, open is %s" (+ n 1) open)
        (aset pyret-nestings n (pyret-add-indent open (pyret-sub-indent cur-opened cur-closed)))
        (let ((h (car-safe opens)))
          (while (equal h 'var)
            (pop opens)
            (incf (pyret-indent-vars cur-closed))
            (setq h (car-safe opens))))
        ;; (message "Line %d" (+ 1 n))
        ;; (message "Prev open     : %s" (pyret-print-indent open))
        (pyret-add-indent! open (pyret-sub-indent (pyret-add-indent cur-opened defered-opened) 
                                                  (pyret-add-indent cur-closed defered-closed)))
        ;; (message "Cur-opened    : %s" (pyret-print-indent cur-opened))
        ;; (message "Defered-opened: %s" (pyret-print-indent defered-opened))
        ;; (message "Cur-closed    : %s" (pyret-print-indent cur-closed))
        ;; (message "Defered-closed: %s" (pyret-print-indent defered-closed))
        ;; (message "New open      : %s" (pyret-print-indent open))
        (incf n)
        (pyret-copy-indent! (aref pyret-nestings n) open)
        (if (not (eobp)) (forward-char)))))
  (setq pyret-nestings-dirty nil))

(defun print-nestings ()
  "Displays the nestings information in the Messages buffer"
  (interactive)
  (let ((i 0))
    (while (and (< i (length pyret-nestings))
                (< i (line-number-at-pos (point-max))))
      (let* ((indents (aref pyret-nestings i)))
        (message "Line %4d: %s" (incf i) (pyret-print-indent indents))
        ))))

(defconst pyret-indent-widths (pyret-make-indent 1 2 2 1 1 1 1 1 1 1 1))
(defun pyret-indent-line ()
  "Indent current line as Pyret code"
  (interactive)
  (cond
   (pyret-nestings-dirty
    (pyret-compute-nestings)))
  (let* ((indents (aref pyret-nestings (min (- (line-number-at-pos) 1) (length pyret-nestings))))
         (total-indent (pyret-sum-indents (pyret-mul-indent indents pyret-indent-widths))))
    (save-excursion
      (beginning-of-line)
      (if (looking-at "^[ \t]*[|]")
          (if (> total-indent 0)
              (indent-line-to (* tab-width (- total-indent 1)))
            (indent-line-to 0))
        (indent-line-to (max 0 (* tab-width total-indent))))
      (setq pyret-nestings-dirty nil))
    (if (< (current-column) (current-indentation))
        (forward-char (- (current-indentation) (current-column))))
    ))


(defun pyret-comment-dwim (arg)
  "Comment or uncomment current line or region in a smart way.
For detail, see `comment-dwim'."
  (interactive "*P")
  (require 'newcomment)
  (let ((comment-start "#") (comment-end ""))
    (comment-dwim arg)))

(defun pyret-mode ()
  "Major mode for editing Pyret files"
  (interactive)
  (kill-all-local-variables)
  (set-syntax-table pyret-mode-syntax-table)
  (use-local-map pyret-mode-map)
  (set (make-local-variable 'font-lock-defaults) '(pyret-font-lock-keywords))
  (set (make-local-variable 'comment-start) "#")
  (set (make-local-variable 'comment-end) "")
  (set (make-local-variable 'indent-line-function) 'pyret-indent-line)  
  (set (make-local-variable 'tab-width) 2)
  (set (make-local-variable 'indent-tabs-mode) nil)
  (setq major-mode 'pyret-mode)
  (setq mode-name "Pyret")
  (set (make-local-variable 'pyret-nestings) nil)
  (set (make-local-variable 'pyret-nestings-dirty) t)
  (add-hook 'before-change-functions
               (function (lambda (beg end) 
                           (setq pyret-nestings-dirty t)))
               nil t)
  (run-hooks 'pyret-mode-hook))



(provide 'pyret)

