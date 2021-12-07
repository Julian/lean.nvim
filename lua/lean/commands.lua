local components = require'lean.infoview.components'
local infoview = require'lean.infoview'
local leanlsp = require'lean.lsp'
local a = require'plenary.async'
local html = require'lean.html'
local rpc = require'lean.rpc'
local lean = require'lean'

local commands = {}

local plain_goal = a.wrap(leanlsp.plain_goal, 3)
local plain_term_goal = a.wrap(leanlsp.plain_term_goal, 3)

---@param div Div
local function show_popup(div)
  local str = div:to_string()
  if str:match('^%s*$') then
    -- do not show the popup if it's the empty string
    return
  end

  local bufnr, winnr = vim.lsp.util.open_floating_preview(
    vim.split(str, '\n'), 'leaninfo',
    { focus_id = 'lean_goal' })

  local bufdiv = html.BufDiv:new(bufnr, div, infoview.mappings)
  bufdiv.last_win = winnr
  bufdiv:buf_render()
end

---@param divs Div[]?
---@param err any?
local function show_popup_or_error(divs, err)
  if divs then
    show_popup(html.concat(divs, '\n\n'))
  elseif err then
    show_popup(html.Div:new(vim.inspect(err)))
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
      err, goal = plain_goal(params, bufnr)
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
      err, term_goal = plain_term_goal(params, bufnr)
      term_goal = term_goal and components.term_goal(term_goal)
    end

    show_popup_or_error(term_goal, err)
  end)()
end

function commands.enable()
  vim.cmd[[
    command LeanPlainGoal :lua require'lean.commands'.show_goal(false)
    command LeanPlainTermGoal :lua require'lean.commands'.show_term_goal(false)
    command LeanGoal :lua require'lean.commands'.show_goal()
    command LeanTermGoal :lua require'lean.commands'.show_term_goal()
  ]]
end

return commands
