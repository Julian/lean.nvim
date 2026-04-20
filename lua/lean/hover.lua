---@mod lean.hover Hover
---
---@brief [[
--- Interactive hovers for Lean, rendered using the same TUI system
--- as the infoview.
---
--- Subexpressions within the hover popup are clickable: press `K` or
--- `<CR>` on a type to see its own type, press `gd` to jump to its
--- definition, etc.
---@brief ]]

local Buffer = require 'std.nvim.buffer'
local async = require 'std.async'

local Element = require('lean.tui').Element
local InteractiveCode = require 'lean.widget.interactive_code'
local infoview = require 'lean.infoview'
local lsp = require 'lean.lsp'
local rpc = require 'lean.rpc'

---Extract the signature and documentation from a Lean hover result.
---
---Lean's hover markdown has the form:
---
---    ```lean
---    Name (args : Types) : ReturnType
---    ```
---    ***
---    Documentation text here...
---    ***
---    *import Module*
---
---We show the type interactively via RPC, so we extract the expression
---name/signature (everything before the final ` : ` in the code fence)
---and the documentation (everything after the first `***` separator).
---@param result table the LSP hover result
---@return string? signature the expression signature (without the type)
---@return string? doc the documentation and import info
local function extract_hover(result)
  local value = type(result.contents) == 'string' and result.contents or result.contents.value
  if not value then
    return
  end

  -- Extract the expression name from inside the code fence.
  -- The fence contains lines like "Nat.add : Nat → Nat → Nat" or
  -- "foo (n : Nat) : Nat".  The greedy (.+) finds the last " : ",
  -- which separates the expression from its type.
  local fence = value:match '^```lean\n(.-)```'
  local signature = fence and vim.trim(fence):match '(.+) : '

  -- Extract documentation after the first *** separator.
  local doc = value:match '%*%*%*\n(.+)'
  if doc then
    doc = vim.trim(doc:gsub('\n%*%*%*\n', '\n---\n'))
  end

  return signature, doc
end

-- There is no interactive-hover RPC method; vscode-lean4 uses the
-- standard (non-interactive) `textDocument/hover` for editor hovers.
-- We go further by using `getInteractiveTermGoal` for the initial
-- content, then subexpression tooltips use `infoToInteractive` via
-- InteractiveCode (same as the VS Code infoview's `TypePopupContents`):
-- https://github.com/leanprover/vscode-lean4/blob/dd686d7/lean4-infoview/src/infoview/interactiveCode.tsx#L112
return function()
  local params = vim.lsp.util.make_position_params(0, 'utf-16')

  async.run(function()
    local sess = rpc.open(params)
    local term_goal, err = sess:getInteractiveTermGoal()

    if err or not term_goal then
      vim.schedule(function()
        vim.lsp.buf.hover()
      end)
      return
    end

    -- Also fetch the standard hover for the signature and documentation.
    local signature, doc
    local client = lsp.client_for()
    if client then
      local _, hover_result = async.wrap(function(handler)
        client:request('textDocument/hover', params, handler)
      end, 1)()
      if hover_result then
        signature, doc = extract_hover(hover_result)
      end
    end

    local children = {}
    if signature then
      table.insert(children, Element:new { text = signature .. ' : ' })
    end
    table.insert(children, InteractiveCode(term_goal.type, sess))
    if doc then
      table.insert(children, Element:new { text = '\n\n' .. doc })
    end

    local element = Element:new { children = children }
    local str = element:to_string()
    if str:match '^%s*$' then
      return
    end

    vim.schedule(function()
      local bufnr = vim.lsp.util.open_floating_preview(
        vim.split(str, '\n'),
        'markdown',
        { focus_id = 'lean_hover' }
      )

      local renderer = element:renderer {
        buffer = Buffer:from_bufnr(bufnr),
        keymaps = infoview.mappings,
      }
      renderer:render()
    end)
  end)
end
