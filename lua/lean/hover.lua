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
local lsp = require 'lean.lsp'
local rpc = require 'lean.rpc'

---Apply Lean keyword highlighting to lines 1..`last_line` of the hover buffer.
---
---`open_floating_preview` starts markdown treesitter on the popup; we stop it
---first because (a) without a Lean TS parser, TS paints fenced/raw content
---with `@markup.raw.block` which would override our keyword colours, and
---(b) TS's italic rules would still fire on the type signature (e.g.
---`u_1, u_2`) regardless of any `:syntax`-engine region we add.  With TS off
---we rely entirely on `:syntax` for both the markdown doc area and the Lean
---code area, scoping Lean syntax to the signature/type lines via a region
---whose `contains=` excludes markdown rules from matching inside.
---
---@param buffer Buffer
---@param last_line integer the 1-indexed last line of the Lean code region
local function apply_lean_syntax(buffer, last_line)
  buffer:call(function()
    pcall(vim.treesitter.stop, buffer.bufnr)

    -- `:syntax include` skips the file when `b:current_syntax` is set and sets
    -- it to the included language on success; bracket the include so markdown
    -- remains the buffer's effective syntax for the surrounding doc lines.
    vim.b.current_syntax = nil
    local ok = pcall(vim.cmd.syntax, { 'include', '@LeanHoverCode', 'syntax/lean.vim' })
    vim.b.current_syntax = 'markdown'
    if not ok then
      return
    end
    vim.cmd.syntax {
      'region',
      'leanHoverCode',
      [[start=/\%^/]],
      ([[end=/\%%%dl$/]]):format(last_line),
      'keepend',
      'contains=@LeanHoverCode',
    }
  end)
end

---Find the byte index of the top-level `:` in a Lean signature, i.e. the
---colon that separates the binder list from the result type.  Bracket-aware
---so colons inside binders such as `(x : T)` or `{x : T}` are skipped.
---@param signature string
---@return integer? index 1-based byte index of the `:` character, or nil if none
local function top_level_colon(signature)
  local depth = 0
  for i = 1, #signature do
    local c = signature:sub(i, i)
    if c == '(' or c == '{' or c == '[' then
      depth = depth + 1
    elseif c == ')' or c == '}' or c == ']' then
      depth = depth - 1
    elseif c == ':' and depth == 0 and signature:sub(i + 1, i + 1) ~= '=' then
      return i
    end
  end
end

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
---name/signature (everything before the top-level `:` in the code fence)
---and the documentation (everything after the first `***` separator).
---@param result table the LSP hover result
---@return string? signature the expression signature (without the type)
---@return string? doc the documentation and import info
local function extract_hover(result)
  local value = type(result.contents) == 'string' and result.contents or result.contents.value
  if not value then
    return
  end

  -- Extract the expression name from inside the code fence.  The fence
  -- contains lines like `Nat.add : Nat → Nat → Nat` or `foo (n : Nat) : Nat`,
  -- and for multi-line signatures the top-level `:` can be at end of a line
  -- with no trailing space.  We walk the fence tracking bracket depth so
  -- colons inside binders never split the signature.
  local fence = value:match '^```lean\n(.-)```'
  local signature
  if fence then
    local trimmed = vim.trim(fence)
    local colon = top_level_colon(trimmed)
    if colon then
      signature = vim.trim(trimmed:sub(1, colon - 1))
    end
  end

  -- Extract documentation after the first *** separator.  Lean uses `***`
  -- as a thematic break; we convert to `---` for nicer rendering, but pad
  -- with a blank line on each side so markdown doesn't read `paragraph\n---`
  -- as a Setext H2 heading (which is what `---` means immediately after a
  -- text line).  We normalize surrounding newlines so we never produce more
  -- than one blank line on either side of the separator.
  local doc = value:match '%*%*%*\n(.+)'
  if doc then
    doc = vim.trim(doc:gsub('\n+%*%*%*\n+', '\n\n---\n\n'))
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

    -- Group the signature and interactive type together so we can re-apply
    -- Lean syntax to exactly the lines they occupy after rendering.
    local lean_code = Element:new { name = 'lean_code' }
    if signature then
      lean_code:add_child(Element:new { text = signature .. ' : ' })
    end
    lean_code:add_child(InteractiveCode(term_goal.type, sess))

    local children = { lean_code }
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
      local buffer = Buffer:from_bufnr(bufnr)

      local renderer = element:renderer {
        buffer = buffer,
        keymaps = require 'lean.config'().infoview.mappings,
      }
      renderer:render()

      local code_pos = renderer.positions[lean_code]
      if code_pos then
        apply_lean_syntax(buffer, code_pos.end_pos[1] + 1)
      end
    end)
  end)
end
