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

;; Declarations

[
  "abbrev"
  "constant"
  "def"
  "theorem"
  "instance"
  "axiom"
  "example"
  "inductive"
  "class"
] @keyword

(abbrev
  name: (identifier) @type)
(abbrev
  attributes: (identifier) @function)
(constant
  name: (identifier) @type)
(constant
  attributes: (identifier) @function)
(def
  name: (identifier) @function)
(def
  attributes: (identifier) @function)
(theorem
  name: (identifier) @function)
(theorem
  attributes: (identifier) @function)
(instance
  name: (identifier) @function)
(instance
  type: (identifier) @type)
(instance
  attributes: (identifier) @function)
(axiom
  name: (identifier) @function)
(class
  name: (identifier) @type)
(class
  extends: (identifier) @type)
(structure_definition
  name: (identifier) @type)
(structure_definition
  extends: (identifier) @type)

(where_decl
  type: (identifier) @type)

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
  "*>"
  "+"
  "++"
  "-"
  "/"
  "::"
  ":="
  "<"
  "<$>"
  "<*"
  "<*>"
  "<="
  "<|"
  "<|>"
  "="
  "=="
  "=>"
  ">"
  ">"
  ">="
  ">>"
  ">>="
  "@"
  "^"
  "|>"
  "|>."
  "||"
  "←"
  "→"
  "↔"
  "∘"
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
  "macro_rules"
  "notation"
  "syntax"
] @keyword

[
  "noncomputable"
  "partial"
  "private"
  "protected"
  "unsafe"
] @keyword

[
  "apply"
  "exact"
  "rewrite"
  "rw"
  "simp"
  (trivial)
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
