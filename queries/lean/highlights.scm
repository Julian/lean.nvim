; Variables
(identifier) @variable

;; Identifier naming conventions
((identifier) @type
 (#match? @type "^[A-Z]"))

;; Definitions

(def
  name: (identifier) @function)

(apply
  name: (identifier) @function)

(element_of
  type: (identifier) @type
  field: (identifier) @method)

(inductive_constructor) @constructor

["if" "then" "else"] @conditional

; Tokens

[
  "$"
  "*"
  "+"
  "++"
  "-"
  "::"
  ":="
  "<|>"
  "="
  "=>"
  ">"
  "←"
  "→"
  "≠"
] @operator

[
  "catch"
  "def"
  "do"
  "else"
  "finally"
  "fun"
  "instance"
  "let"
  "match"
  "return"
  "structure"
  "try"
  "where"
  "with"
] @keyword

[(true) (false)] @boolean

(number) @number

(comment) @comment
(char) @number
(string) @string
(interpolated_string) @string

; Reset highlighing in string interpolation
(interpolation) @none

["(" ")" "[" "]" "⟨" "⟩"] @punctuation.bracket

(interpolation
  "{" @punctuation.special
  "}" @punctuation.special)

["," "." ":"] @punctuation.delimiter


;; Error
(ERROR) @error
