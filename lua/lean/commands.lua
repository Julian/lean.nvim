local a = require('plenary.async')

local components = require('lean.infoview.components')
local Element = require('lean.widgets').Element
local infoview = require('lean.infoview')
local lean = require('lean')
local leanlsp = require('lean.lsp')
local progress = require('lean.progress')
local rpc = require('lean.rpc')

local commands = {}

---@param element Element
local function show_popup(element)
  local str = element:to_string()
  if str:match('^%s*$') then
    -- do not show the popup if it's the empty string
    return
  end

  local bufnr, winnr = vim.lsp.util.open_floating_preview(
    vim.split(str, '\n'),
    'leaninfo',
    { focus_id = 'lean_goal', border = 'rounded' }
  )

  local renderer = element:renderer{ buf = bufnr, keymaps = infoview.mappings }
  renderer.last_win = winnr
  renderer:render()
end

---@param elements Element[]?
---@param err any?
local function show_popup_or_error(elements, err)
  if elements then
    show_popup(Element:concat(elements, '\n\n'))
  elseif err then
    show_popup(Element:new{ text = vim.inspect(err) })
  end
end

function commands.show_goal(use_widgets)
  if use_widgets == nil then use_widgets = true end

  local params = vim.lsp.util.make_position_params()
  local bufnr = vim.api.nvim_get_current_buf()
  local is_lean3 = lean.is_lean3_buffer()

  a.void(function()
    local goal, err
    if not is_lean3 and use_widgets then
      local sess = rpc.open(bufnr, params)
      goal, err = sess:getInteractiveGoals(params)
      goal = goal and components.interactive_goals(goal, sess)
    end

    if not goal then
      err, goal = leanlsp.plain_goal(params, bufnr)
      goal = goal and components.goal(goal)
    end

    show_popup_or_error(goal, err)
  end)()
end

function commands.show_term_goal(use_widgets)
  if lean.is_lean3_buffer() then
    -- Lean 3 does not support term goals.
    return
  end

  if use_widgets == nil then use_widgets = true end

  local params = vim.lsp.util.make_position_params()
  local bufnr = vim.api.nvim_get_current_buf()

  a.void(function()
    local term_goal, err
    if use_widgets then
      local sess = rpc.open(bufnr, params)
      term_goal, err = sess:getInteractiveTermGoal(params)
      term_goal = term_goal and components.interactive_term_goal(term_goal, sess)
    end

    if not term_goal then
      err, term_goal = leanlsp.plain_term_goal(params, bufnr)
      term_goal = term_goal and components.term_goal(term_goal)
    end

    show_popup_or_error(term_goal, err)
  end)()
end

function commands.show_line_diagnostics()
  local is_lean3 = lean.is_lean3_buffer()
  local params = vim.lsp.util.make_position_params()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = params.position.line

  a.void(function()
    local diags, err

    if not is_lean3 and not progress.is_processing_at(params) then
      local sess = rpc.open(bufnr, params)
      diags, err = sess:getInteractiveDiagnostics{ start = line, ['end'] = line + 1 }
      diags = not err and components.interactive_diagnostics(diags, line, sess)
    end

    if not diags then
      diags = components.diagnostics(bufnr, line)
    end

    show_popup_or_error(diags, err)
  end)()
end

function commands.enable()
  vim.cmd[[
    command LeanPlainGoal :lua require'lean.commands'.show_goal(false)
    command LeanPlainTermGoal :lua require'lean.commands'.show_term_goal(false)
    command LeanGoal :lua require'lean.commands'.show_goal()
    command LeanTermGoal :lua require'lean.commands'.show_term_goal()
    command LeanLineDiagnostics :lua require'lean.commands'.show_line_diagnostics()
  ]]
end

return commands
