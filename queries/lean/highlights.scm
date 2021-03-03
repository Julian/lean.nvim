; Variables
(identifier) @variable

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
  "||"
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
  "for"
  "fun"
  "in"
  "inductive"
  "instance"
  "let"
  "match"
  "namespace"
  "return"
  "section"
  "structure"
  "try"
  "where"
  "with"
  "λ"
  (hash_command)
  (mutable_specifier)
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

["(" ")" "[" "]" "⟨" "⟩"] @punctuation.bracket

(interpolation
  "{" @punctuation.special
  "}" @punctuation.special)

["," "." ":"] @punctuation.delimiter


;; Error
(ERROR) @error
