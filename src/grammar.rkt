#lang reader "../lib/autogrammar/lalr/lang/reader.rkt"

program: block ENDMARKER

block: stmt*

stmt: def-expr | fun-expr | expr

expr: obj-expr | list-expr | app-expr | id-expr | prim-expr | dot-expr | bracket-expr

id-expr: NAME

prim-expr: num-expr | string-expr
num-expr: NUMBER
string-expr: STRING
                    
def-expr: "def" NAME ":" expr

app-arg-elt: expr ","
app-args: "(" app-arg-elt* expr ")" | "(" ")"
app-expr: expr app-args

arg-elt: NAME ","
args: "(" arg-elt* NAME ")" | "(" ")"
fun-expr:
   "fun" NAME args ":" block "end"
   
field: NAME ":" expr | NAME args ":" stmt | NAME args ":" stmt "end"
list-field: field ","

# list-field is here because it works better with syntax-matching -
# there's a syntax sub-list for list-field that we can grab hold of
obj-expr: "{" list-field* field "}" | "{" "}"

list-elt: expr ","
list-expr: "[" list-elt* expr "]" | "[" "]"

dot-expr: expr "." NAME
bracket-expr: expr "." "(" expr ")"

