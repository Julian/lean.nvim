(open
  namespace: (identifier) @namespace)
(namespace
  name: (identifier) @namespace)
(section
  name: (identifier) @namespace)

(arrow) @type
; (product) @type
;
;; Declarations

[
  "abbrev"
  "def"
  "theorem"
  "constant"
  "instance"
  "axiom"
  "example"
  ; "inductive"
  ; "structure"
  ; "class"
  ;
  ; "deriving"

  "section"
  "namespace"
] @keyword

; (attributes
;   (identifier) @function)

; (abbrev
;   name: (identifier) @type)
(def
  name: (identifier) @function)
(theorem
  name: (identifier) @function)
(constant
  name: (identifier) @type)
(instance
  name: (identifier) @function)
(instance
  type: (identifier) @type)
(axiom
  name: (identifier) @function)
; (structure
;   name: (identifier) @type)
; (structure
;   extends: (identifier) @type)
;
; (whereDecl
;   type: (identifier) @type)
;
(implicitBinder
    type: (identifier) @type)
(explicitBinder
    type: (identifier) @type)
;
; (proj
;   name: (identifier) @field)
;
; (binders
;   type: (identifier) @type)
;
["if" "then" "else"] @conditional
;
; ["for" "in" "do"] @repeat

(import
  module: (identifier) @module)

; Tokens

[
;   "!"
;   "$"
;   "%"
;   "&&"
;   "*"
;   "*>"
;   "+"
;   "++"
;   "-"
;   "/"
;   "::"
;   ":="
;   "<"
;   "<$>"
;   "<*"
;   "<*>"
;   "<="
;   "<|"
;   "<|>"
;   "="
;   "=="
;   "=>"
;   ">"
;   ">"
;   ">="
;   ">>"
;   ">>="
;   "@"
;   "^"
;   "|>"
;   "|>."
;   "||"
;   "←"
  "→"
;   "↔"
;   "∘"
;   "∧"
;   "∨"
;   "≠"
;   "≤"
;   "≥"
] @operator
;
; [
;   "@&"
; ] @operator

[
  ; "attribute"
  ; "end"
  "export"
  ; "extends"
  ; "fun"
  ; "let"
  ; "have"
  ; "match"
  "open"
  ; "return"
  ; "universe"
  "variable"
  ; "where"
  ; "with"
  ; "λ"
  (interactive)
  (prelude)
  (sorry)
] @keyword

[
 "import"
] @keyword.import

; [
;   "prefix"
;   "infix"
;   "infixl"
;   "infixr"
;   "postfix"
;   "notation"
;   "macro"
;   "macroRules"
;   "syntax"
;   "elab"
;   "builtin_initialize"
; ] @keyword

[
  "noncomputable"
  "partial"
  "private"
  "protected"
  "unsafe"
] @keyword.modifier
;
[
  "by"
;   "apply"
  ; "exact"
;   "rewrite"
  ; "rfl"
;   "rw"
;   "simp"
;   (trivial)
] @keyword

; [
;   "catch"
;   "finally"
;   "try"
; ] @exception

((apply
  lhs: (identifier) @exception)
 (#match? @exception "throw"))

; [
;   "unless"
;   "mut"
; ] @keyword
;
[(true) (false)] @boolean

(number) @number
; (float) @number.float

(comment) @comment
(char) @character
(string) @string
(interpolatedString) @string
(quotedChar) @string.escape

; Reset highlighing in string interpolation
(interpolation) @none

(interpolation
  "{" @punctuation.special
  "}" @punctuation.special)

[
  "(" ")"
  "[" "]"
  "{" "}"
 ;  "⟨" "⟩"
 ] @punctuation.bracket
;
[
  ; "|"
  ","
  "."
  ":"
  ";"
] @punctuation.delimiter
;
(sorry) @error

;; Error
(ERROR) @error
