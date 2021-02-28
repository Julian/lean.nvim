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

["if" "then" "else"] @conditional

; Tokens

[
  "-"
  ":="
  "*"
  "="
  ">"
  "=>"
  "←"
  "→"
  "$"
] @operator

[
  "catch"
  "def"
  "do"
  "else"
  "finally"
  "fun"
  "let"
  "return"
  "structure"
  "try"
  "where"
] @keyword

[(true) (false)] @boolean

(number) @number

(comment) @comment
(string) @string
; Reset highlighing in string interpolation
(interpolation) @none
;; Error
(ERROR) @error
