(open
  namespace: (identifier) @namespace)
(namespace
  name: (identifier) @namespace)
(section
  name: (identifier) @namespace)

; Variables
(identifier) @variable

;; Identifier naming conventions
((identifier) @type
 (#match? @type "^[A-Z]"))

(function_type) @type
(product_type) @type
(inductive_type
  name: (identifier) @type)

(structure_definition
  name: (identifier) @type)
(structure_definition
  extends: (identifier) @type)

(class
  name: (identifier) @type)
(class
  extends: (identifier) @type)

(instance
  class: (identifier) @type)
(instance_field
  return_type: (identifier) @type)

;; Definitions

(def
  name: (identifier) @function)

(def
  attributes: (identifier) @function)

(apply
  name: (identifier) @function)

(field_of
  name: (identifier) @field)

(parameters
  type: (identifier) @type)

(inductive_constructor) @constructor

["if" "then" "else"] @conditional

["for" "in" "do"] @repeat

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
  "<"
  "<="
  "<|"
  "<|>"
  "="
  "=="
  "=>"
  ">"
  ">"
  ">="
  "@"
  "^"
  "|>"
  "|>."
  "||"
  "←"
  "∘"
  "→"
  "↔"
  "∧"
  "∨"
  "≠"
  "≤"
  "≥"
] @operator

[
  "attribute"
  "by"
  "end"
  "export"
  "extends"
  "fun"
  "let"
  "match"
  "namespace"
  "open"
  "return"
  "section"
  "structure"
  "universe"
  "universes"
  "variable"
  "where"
  "with"
  "λ"
  (hash_command)
  (prelude)
  (sorry)
] @keyword

[
  "class"
  "constant"
  "def"
  "example"
  "inductive"
  "instance"
  "theorem"
] @keyword

[
  "noncomputable"
  "partial"
  "private"
  "protected"
  "unsafe"
] @keyword

[
  "exact"
  "rewrite"
  "simp"
] @keyword

[
  "catch"
  "finally"
  "try"
] @exception

[
  "throw"
  "unless"
  "mut"
] @keyword

[(true) (false)] @boolean

(number) @number
(float) @float

(comment) @comment
(char) @character
(string) @string
(interpolated_string) @string
(escape_sequence) @string.escape

; Reset highlighing in string interpolation
(interpolation) @none

(interpolation
  "{" @punctuation.special
  "}" @punctuation.special)

["(" ")" "[" "]" "{" "}" "⟨" "⟩"] @punctuation.bracket

["|" "," "." ":" ";"] @punctuation.delimiter

(sorry) @error

;; Error
(ERROR) @error
