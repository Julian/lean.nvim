; Variables
(identifier) @variable

(function_type) @type
(product_type) @type

;; Identifier naming conventions
((identifier) @type
 (#match? @type "^[A-Z]"))

;; Definitions

(def
  name: (identifier) @function)

(def
  attributes: (identifier) @function)

(apply
  name: (identifier) @function)

(field_of
  name: (identifier) @method)

(parameters
  name: (identifier) @parameter)

(inductive_constructor) @constructor

["if" "then" "else"] @conditional

["for"] @repeat

(import) @include

; Tokens

[
  "!"
  "$"
  "%"
  "&&"
  "*"
  "+"
  "++"
  "-"
  "/"
  "::"
  ":="
  "<|>"
  "="
  "=="
  "=>"
  ">"
  "@"
  "^"
  "||"
  "←"
  "→"
  "↔"
  "∧"
  "∨"
  "≠"
] @operator

[
  "catch"
  "class"
  "constant"
  "def"
  "do"
  "else"
  "end"
  "export"
  "finally"
  "for"
  "fun"
  "in"
  "inductive"
  "instance"
  "let"
  "mut"
  "match"
  "namespace"
  "open"
  "return"
  "section"
  "structure"
  "theorem"
  "try"
  "universe"
  "variable"
  "where"
  "with"
  "λ"
  (prelude)
  (hash_command)
] @keyword

[(true) (false)] @boolean

(number) @number
(float) @float

(comment) @comment
(char) @number
(string) @string
(interpolated_string) @string

; Reset highlighing in string interpolation
(interpolation) @none

["(" ")" "[" "]" "{" "}" "⟨" "⟩"] @punctuation.bracket

(interpolation
  "{" @punctuation.special
  "}" @punctuation.special)

["," "." ":"] @punctuation.delimiter


;; Error
(ERROR) @error
