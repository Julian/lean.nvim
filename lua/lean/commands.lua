local a = require 'plenary.async'

local Element = require('lean.tui').Element
local components = require 'lean.infoview.components'
local infoview = require 'lean.infoview'
local progress = require 'lean.progress'

local commands = {}

---@param element Element
local function show_popup(element)
  local str = element:to_string()
  if str:match '^%s*$' then
    -- do not show the popup if it's the empty string
    return
  end

  local bufnr, winnr = vim.lsp.util.open_floating_preview(
    vim.split(str, '\n'),
    'leaninfo',
    { focus_id = 'lean_goal', border = 'rounded' }
  )

  local renderer = element:renderer { buf = bufnr, keymaps = infoview.mappings }
  renderer.last_win = winnr
  renderer:render()
end

---@param elements Element[]?
---@param err LspError?
local function show_popup_or_error(elements, err)
  if elements then
    show_popup(Element:concat(elements, '\n\n'))
  elseif err then
    show_popup(Element:new { text = vim.inspect(err) })
  end
end

function commands.show_goal(use_widgets)
  local bufnr = vim.api.nvim_get_current_buf()
  local params = vim.lsp.util.make_position_params()

  a.void(function()
    local goal, err = components.goal_at(bufnr, params, nil, use_widgets)
    show_popup_or_error(goal, err)
  end)()
end

function commands.show_term_goal(use_widgets)
  local bufnr = vim.api.nvim_get_current_buf()
  local params = vim.lsp.util.make_position_params()

  a.void(function()
    local goal, err = components.term_goal_at(bufnr, params, nil, use_widgets)
    show_popup_or_error(goal, err)
  end)()
end

function commands.show_line_diagnostics()
  local params = vim.lsp.util.make_position_params()
  local bufnr = vim.api.nvim_get_current_buf()

  a.void(function()
    local diagnostics, err
    if progress.is_processing_at(params) then
      err = 'Processing...'
    else
      diagnostics, err = components.diagnostics_at(bufnr, params, nil, false)
    end
    show_popup_or_error(diagnostics, err)
  end)()
end

function commands.enable()
  vim.cmd [[
    command! LeanPlainGoal :lua require'lean.commands'.show_goal(false)
    command! LeanPlainTermGoal :lua require'lean.commands'.show_term_goal(false)
    command! LeanGoal :lua require'lean.commands'.show_goal()
    command! LeanTermGoal :lua require'lean.commands'.show_term_goal()
    command! LeanLineDiagnostics :lua require'lean.commands'.show_line_diagnostics()
  ]]
end

return commands
