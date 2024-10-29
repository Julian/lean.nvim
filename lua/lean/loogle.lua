---@mod lean.loogle Loogle

---@brief [[
--- Support for interacting with the Loogle search engine.
---@brief ]]

local curl = require 'plenary.curl'

local loogle = {}

---@class LoogleResult
---@field name string
---@field type string
---@field module string
---@field doc string

---Search Loogle for the given type.
---@param type string The type pattern to look for.
---@return LoogleResult[]|nil results Loogle hits in the JSON API format
---@return string|nil err An error message from Loogle, in which case no results are returned
function loogle.search(type)
  local res = curl.get {
    url = 'https://loogle.lean-lang.org/json',
    query = { q = type },
    headers = { ['User-Agent'] = 'lean+nvim' },
    accept = 'application/json',
  }

  if res.status ~= 200 then
    error('Loogle returned status code: ' .. res.status)
  end

  local body = vim.fn.json_decode(res.body)
  if body.error then
    return nil, body.error
  end

  return body.hits
end

---Create a minimal Lean file out of the given result.
---@param result LoogleResult the result to template out
---@return string[] lines a list-like table containing a Lean file template
function loogle.template(result)
  local lines = {
    'import ' .. result.module,
    '',
  }
  local with_name = result.name .. ' : ' .. result.type
  vim.list_extend(lines, vim.split(with_name:gsub('\n%s*', '\n  '), '\n'))
  return lines
end

return loogle
