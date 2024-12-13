local M = {}

-- Borrowed from the (not merged) https://github.com/leanprover/vscode-lean4/pull/329/
local INDENT_AFTER = vim.regex(([[\<\(%s\)$]]):format(table.concat({
  'by',
  'do',
  'try',
  'finally',
  'then',
  'else',
  'where',
  'from',
  'extends',
  'deriving',
  '=>',
  ':=',
}, [[\|]])))

---Check whether the given string is a goal focus dot.
---@param str string
---@param position? integer
---@return boolean
local function focuses_at(str, position)
  position = position or 1
  return str:sub(position, position + 1) == '·'
end

---Is the given position a Lean sorry?
---@param linenr number
---@param position integer
---@return boolean
local function is_sorry(linenr, position)
  local items = vim.inspect_pos(0, linenr, position)
  local via_tokens = items.semantic_tokens[1]
  return (via_tokens and via_tokens[1].opts.hl_group == '@lsp.type.leanSorryLike.lean')
    or (items.syntax[1] and items.syntax[1].hl_group == 'leanSorry')
end

---Is the given line within a Lean enclosed bracket?
---@param linenr number
---@return boolean
local function is_enclosed(linenr)
  local syntax = vim.inspect_pos(0, linenr, 0).syntax[1]
  return syntax and syntax.hl_group == 'leanEncl'
end

---Is the given line within a Lean comment (normal or block)?
---@param linenr number
---@return boolean
local function is_comment(linenr)
  local syntax = vim.inspect_pos(0, linenr, 0).syntax[1]
  return syntax and syntax.hl_group_link == 'Comment'
end

---Is the given line the docstring or attribute before a new declaration?
---@param linenr number
---@return boolean
local function is_declaration_args(linenr)
  local syntax = vim.inspect_pos(0, linenr, 0).syntax[1]
  local hl_group = syntax and syntax.hl_group
  return hl_group == 'leanBlockComment' or hl_group == 'leanAttributeArgs'
end

---A crude `:h indentexpr` for Lean.
---@param linenr integer? the line number whose indent we are calculating
---@return integer
function M.indentexpr(linenr)
  linenr = linenr or vim.v.lnum

  if linenr == 1 then
    return 0 -- Don't indent the first line, and now we can subtract from linenr.
  end

  local last, current = unpack(vim.api.nvim_buf_get_lines(0, linenr - 2, linenr, true))
  local shiftwidth = vim.bo.shiftwidth

  local _, current_indent = current:find '^%s*'
  if current_indent > 0 and current_indent < #current and current_indent % shiftwidth == 0 then
    return current_indent ---@type integer
  end

  if not is_comment(linenr - 2) then
    if last:find ':%s*$' then
      return shiftwidth * 2
    elseif last:find ':=%s*$' then
      return shiftwidth
    elseif is_sorry(linenr - 2, #last - 1) then
      return 0
    end
  end

  -- Lua patterns are... seemingly broken with unicode and/or multibyte
  -- characters. Specifically `('  foo'):find '^(%s+)([z]?)(.*)'` works fine to
  -- match an optional `z`, but ('  foo'):find '^(%s+)([·]?)(.*)' does not.
  local _, last_indent = last:find '^%s+'

  if last_indent and focuses_at(last, last_indent + 1) then
    return last_indent + #'·'
  elseif last_indent and is_enclosed(linenr - 1) then
    local _, bracket = last:find '%['
    return bracket or last_indent + shiftwidth
  elseif last_indent and not is_declaration_args(linenr - 2) then
    local dedent_one = last_indent - shiftwidth

    -- We could go backwards to check but that would involve looking back
    -- repetaedly over lines backwards, so we cheat and just check whether the
    -- previous line looks like it has a binder on it.
    local is_end_of_binders = dedent_one > 0 and last:find '^%s*[({[]'
    return is_end_of_binders and dedent_one or last_indent
  elseif INDENT_AFTER:match_str(last) and not INDENT_AFTER:match_str(current) then
    return (last_indent or 0) + shiftwidth
  end

  return current_indent ---@type integer
end

return M
