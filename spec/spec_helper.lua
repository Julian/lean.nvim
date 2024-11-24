local assert = require 'luassert.assert'
local say = require 'say'

--- Assert a Lua object is empty.
--- In particular, the empty string, empty table and nil are all empty.
local function is_empty(_, arguments)
  local got = arguments[1]
  if not got then
    return true
  elseif type(got) == 'string' then
    return got == ''
  else
    return vim.tbl_isempty(got)
  end
end

say:set('assertion.empty.positive', '%q is non-empty')
say:set('assertion.empty.negative', '%q is empty')
assert:register(
  'assertion',
  'empty',
  is_empty,
  'assertion.empty.positive',
  'assertion.empty.negative'
)
