local M = {}

-- Borrowed from the (not merged) https://github.com/leanprover/vscode-lean4/pull/329/
local INDENT_AFTER = vim.regex(([[\(%s\)$]]):format(table.concat({
  '\\<by',
  '\\<do',
  '\\<try',
  '\\<finally',
  '\\<then',
  '\\<else',
  '\\<where',
  '\\<from',
  '\\<extends',
  '\\<deriving',
  '\\<:=',
  '=>',
  ' =',
}, [[\|]])))
local NEVER_INDENT = vim.regex(([[^\s*\(%s\)]]):format(table.concat({
  'attribute ',
  'compile_inductive% ',
  'def ',
  'instance ',
  'partial_fixpoint',
  'structure ',
  'where',
  '@\\[',
}, [[\|]])))

---Check whether the given string is a goal focus dot.
---@param str string
---@param position? integer
---@return boolean
local function focuses_at(str, position)
  -- Lua patterns are... seemingly broken with unicode and/or multibyte
  -- characters. Specifically `('  foo'):find '^(%s+)([z]?)(.*)'` works fine to
  -- match an optional `z`, but ('  foo'):find '^(%s+)([·]?)(.*)' does not.
  position = position or 1
  return str:sub(position, position + 1) == '·'
end

---Find where a sorry starts if one exists at the given position.
---@param linenr number
---@param position integer
---@return integer?
local function sorry_at(linenr, position)
  local items = vim.inspect_pos(0, linenr, position)
  local token = items.semantic_tokens[1]
  if token and token.opts.hl_group == '@lsp.type.leanSorryLike.lean' then
    return token.col
  elseif items.syntax[1] and items.syntax[1].hl_group == 'leanSorry' then
    return items.col + 1 - #'sorry'
  end
end

---Is the given line within a Lean enclosed bracket?
---@param linenr number
---@param position integer
---@return boolean
local function is_enclosed(linenr, position)
  local syntax = vim.inspect_pos(0, linenr, position).syntax[1]
  local hlgroup = syntax and syntax.hl_group
  return hlgroup == 'leanEncl' or hlgroup == 'leanAnonymousLiteral'
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
  elseif is_comment(linenr - 1) then
    return vim.fn.indent(linenr)
  end

  local last, current = unpack(vim.api.nvim_buf_get_lines(0, linenr - 2, linenr, true))
  local shiftwidth = vim.bo.shiftwidth

  local _, current_indent = current:find '^%s*'
  if
    current == '}'
    or (current_indent > 0 and current_indent < #current and current_indent % shiftwidth == 0)
  then
    return current_indent ---@type integer
  elseif NEVER_INDENT:match_str(current) then
    return 0
  end

  if last:find ':%s*$' then
    return shiftwidth * 2
  elseif last:find ':=%s*$' or last:find '{%s*$' then
    return shiftwidth
  end

  local sorry = sorry_at(linenr - 2, #last - 1)
  if sorry then
    local before = last:sub(1, sorry)
    if not before:find ':=%s*' and not before:find 'from%s*' then
      return math.max(0, sorry - shiftwidth - 1)
    end
  end

  local _, last_indent = last:find '^%s*'

  if is_enclosed(linenr - 1, 0) then
    if is_enclosed(linenr - 2, 0) then
      return last_indent
    end
    return last_indent + shiftwidth
  end

  if focuses_at(last, last_indent + 1) then
    last_indent = last_indent + #'·'
  end

  if INDENT_AFTER:match_str(last) then
    return last_indent + shiftwidth
  end

  if not is_declaration_args(linenr - 2) then
    local dedent_one = last_indent - shiftwidth

    -- We could go backwards to check but that would involve looking back
    -- repetaedly over lines backwards, so we cheat and just check whether the
    -- previous line looks like it has a binder on it.
    local is_end_of_binders = dedent_one > 0 and last:find '^%s*[({[]'
    return is_end_of_binders and dedent_one or last_indent == 0 and current_indent or last_indent
  end

  return current_indent ---@type integer
end

return M
