local components = require'lean.infoview.components'
local infoview = require'lean.infoview'
local leanlsp = require'lean.lsp'
local a = require'plenary.async'
local html = require'lean.html'
local rpc = require'lean.rpc'

local commands = {}

local plain_goal = a.wrap(leanlsp.plain_goal, 3)
local plain_term_goal = a.wrap(leanlsp.plain_term_goal, 3)

---@param div Div
local function show_popup(div)
  local bufnr, winnr = vim.lsp.util.open_floating_preview(
    vim.split(div:to_string(), '\n'), 'leaninfo',
    { close_events = {} })

  local bufdiv = html.BufDiv:new(bufnr, div, infoview.mappings)
  bufdiv.last_win = winnr
  bufdiv:buf_render()
end

function commands.show_goal(use_widgets)
  if use_widgets == nil then use_widgets = true end

  local params = vim.lsp.util.make_position_params()
  local bufnr = vim.api.nvim_get_current_buf()

  a.void(function()
    local goal, err
    if use_widgets then
      local sess = rpc.open(bufnr, params)
      goal, err = sess:getInteractiveGoals(params)
      goal = goal and components.interactive_goals(goal, sess)
    end

    if not goal then
      err, goal = plain_goal(params, bufnr)
      goal = goal and components.goal(goal)
    end

    if goal or err then show_popup(goal or html.Div:new(vim.inspect(err))) end
  end)()
end

function commands.show_term_goal(use_widgets)
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

    if term_goal or err then show_popup(term_goal or html.Div:new(vim.inspect(err))) end
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
