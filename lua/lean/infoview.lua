local components = require'lean.infoview.components'
local lean3 = require'lean.lean3'
local leanlsp = require'lean.lsp'
local is_lean_buffer = require'lean'.is_lean_buffer
local util = require'lean._util'
local set_augroup = util.set_augroup
local a = require'plenary.async'
local html = require'lean.html'
local rpc = require'lean.rpc'

local infoview = {
  -- mapping from infoview IDs to infoviews
  ---@type table<number, Infoview>
  _by_id = {},
  -- mapping from tabpage handles to infoviews
  ---@type table<any, Infoview>
  _by_tabpage = {},
  -- mapping from info IDs to infos
  ---@type table<number, Info>
  _info_by_id = {},
  -- mapping from pin IDs to pins
  ---@type table<number, Pin>
  _pin_by_id = {},
}
local options = { _DEFAULTS = { autoopen = true, width = 50, autopause = false, show_processing = true,
  show_loading = true, use_widget = true, lean3 = {show_filter = true},
  mappings = {
      ["K"] = [[click]],
      ["I"] = [[mouse_enter]],
      ["i"] = [[mouse_leave]],
      ["u"] = [[undo]],
      ["U"] = [[clear_undo]],
      ["C"] = [[clear_all]]
    } } }

local _NOTHING_TO_SHOW = { "No info found." }

--- An individual pin.
---@class Pin
---@field id number
---@field parent_infos table<number, boolean>
---@field use_widget boolean
---@field data_div Div
---@field div Div
---@field ticker table
local Pin = {next_id = 1}

--- An individual info.
---@class Info
---@field id number
---@field bufnr number
---@field pin Pin
---@field div Div
local Info = {}

--- A "view" on an info (i.e. window).
---@class Infoview
---@field id number
---@field bufnr number
---@field width number
---@field info Info
local Infoview = {}

--- Get the infoview corresponding to the current window.
---@return Infoview
function infoview.get_current_infoview()
  return infoview._by_tabpage[vim.api.nvim_win_get_tabpage(0)]
end

--- Create a new infoview.
---@param width number: the width of the new infoview
---@param open boolean: whether to open the infoview after initializing
---@return Infoview
function Infoview:new(width, open)
  local new_infoview = {id = #infoview._by_id + 1, width = width, info = Info:new()}
  table.insert(infoview._by_id, new_infoview)
  self.__index = self
  setmetatable(new_infoview, self)

  if not open then new_infoview:close() else new_infoview:open() end

  return new_infoview
end

--- Open this infoview if it isn't already open
function Infoview:open()
  local window_before_split = vim.api.nvim_get_current_win()

  vim.cmd("botright " .. self.width .. "vsplit")
  vim.cmd(string.format("buffer %d", self.info.bufnr))
  local window = vim.api.nvim_get_current_win()

  -- Make sure we notice even if someone manually :q's the infoview window.
  set_augroup("LeanInfoviewClose", string.format([[
    autocmd WinClosed <buffer> lua require'lean.infoview'.__was_closed(%d)
  ]], self.id), 0)

  vim.api.nvim_set_current_win(window_before_split)

  self.window = window
  self.is_open = true

  self:focus_on_current_buffer()
end

--- Close this infoview.
function Infoview:close()
  if not self.is_open then
    -- in case it is nil
    self.is_open = false
    return
  end

  set_augroup("LeanInfoviewClose", "", self.bufnr)
  vim.api.nvim_win_close(self.window, true)
  self.window = nil
  self.is_open = false

  self:focus_on_current_buffer()
end

--- Toggle this infoview being open.
function Infoview:toggle()
  if self.is_open then self:close() else self:open() end
end

--- Set the currently active Lean buffer to update the info.
function Infoview:focus_on_current_buffer()
  if not is_lean_buffer() then return end
  if self.is_open then
    set_augroup("LeanInfoviewUpdate", [[
      autocmd CursorMoved <buffer> lua require'lean.infoview'.__update()
      autocmd CursorMovedI <buffer> lua require'lean.infoview'.__update()
    ]], 0)
  else
    set_augroup("LeanInfoviewUpdate", "", 0)
  end
end

---@return Info
function Info:new()
  local new_info = {
    id = #infoview._info_by_id + 1,
    bufnr = vim.api.nvim_create_buf(false, true),
    pin = Pin:new(options.autopause, options.use_widget),
    pins = {},
    div = html.Div:new({info = self}, "", "info")
  }
  table.insert(infoview._info_by_id, new_info)

  self.__index = self
  setmetatable(new_info, self)

  vim.api.nvim_buf_set_name(new_info.bufnr, "lean://info/" .. new_info.id)
  vim.api.nvim_buf_set_option(new_info.bufnr, 'filetype', 'leaninfo')
  new_info.div:buf_register(new_info.bufnr, options.mappings)

  new_info.pin:add_parent_info(new_info)

  new_info:render()

  return new_info
end

function Info:add_pin()
  table.insert(self.pins, self.pin)
  self.pin:show_extmark()
  self.pin = Pin:new(options.autopause, options.use_widget)
  self.pin:add_parent_info(self)
  self:render()
end

function Info:clear_pins()
  for _, pin in pairs(self.pins) do pin:remove_parent_info(self) end

  self.pins = {}
end

--- Set the current window as the last window used to update this Info.
function Info:set_last_window()
  self.last_window = vim.api.nvim_get_current_win()
end

--- Update this info's physical contents.
function Info:render()
  self.div.divs = {}
  local function render_pin(pin, current)
    local header
    local attributes = {}
    if current then table.insert(attributes, "CURRENT") end
    if pin.paused then table.insert(attributes, "PAUSED") end
    if pin.loading then table.insert(attributes, "LOADING") end
    local attributes_txt = ""
    for _, attribute in ipairs(attributes) do
      attributes_txt = attributes_txt .. " [" .. attribute .. "]"
    end
    header = "-- PIN " .. tostring(pin.id) .. attributes_txt

    if not current and pin.position_params then
      local bufnr = vim.fn.bufnr(vim.uri_to_fname(pin.position_params.textDocument.uri))
      local filename
      if bufnr ~= -1 then
        filename = vim.fn.bufname(bufnr)
      else
        filename = pin.position_params.textDocument.uri
      end
      header = header .. (": file %s at line %d, character %d"):format(filename,
        pin.position_params.position.line + 1, pin.position_params.position.character + 1)
    end
    header = header and header .. "\n"

    local pin_div = html.Div:new({}, header, "pin_wrapper")
    if pin.div then pin_div:add_div(pin.div) end
    if #pin.undo_list > 0 then
      pin_div:add_div(html.Div:new({}, "\n/- undo list size: " .. tostring(#pin.undo_list) .. " -/"))
    end

    self.div:add_div(pin_div)
    self.div:add_div(html.Div:new({}, "\n--", "close_pin"))
  end

  render_pin(self.pin, true)

  for _, pin in pairs(self.pins) do
    self.div:add_div(html.Div:new({}, "\n\n", "pin_spacing"))
    render_pin(pin, false)
  end

  self:_render()
  collectgarbage()
end

function Info:_render()
  self.div:buf_render(self.bufnr)
end

--- Retrieve the contents of the info as a table.
function Info:get_lines(start_line, end_line)
  start_line = start_line or 0
  end_line = end_line or -1
  return vim.api.nvim_buf_get_lines(self.bufnr, start_line, end_line, true)
end

--- Retrieve the current combined contents of the info as a string.
function Info:get_contents()
  return table.concat(self:get_lines(), "\n")
end

--- Is the info not showing anything?
function Info:is_empty()
  return vim.deep_equal(self:get_lines(), _NOTHING_TO_SHOW)
end

---@return Pin
function Pin:new(paused, use_widget)
  local new_pin = {id = self.next_id, parent_infos = {}, paused = paused,
    ticker = util.Ticker:new(),
    data_div = html.Div:new({pin = self}, "", "pin-data", nil),
    div = html.Div:new({pin = self}, "", "pin", nil, true), use_widget = use_widget, undo_list = {}}
  self.next_id = self.next_id + 1
  infoview._pin_by_id[new_pin.id] = new_pin

  self.__index = self
  setmetatable(new_pin, self)

  new_pin.div.tags.event = {}

  new_pin.div.call_event = function(path, event, fn, args)
    local tick = new_pin.ticker:lock()
    if not tick then return end

    new_pin:set_loading(true)

    local success, ignore = fn(tick, unpack(args))

    if not tick:check() then return end

    if not success then print('failed "' .. event .. '" event (see :messages)') end
    if not ignore then
      -- store path relative to data_div
      local this_path = {unpack(path)}
      table.remove(this_path)
      table.insert(new_pin.undo_list, {path = this_path, event = event})
    end

    new_pin:set_loading(false)

    new_pin.ticker:release()

    return true
  end


  -- replays the events in this pin's undo list
  new_pin.div.tags.event.replay = function(tick)
    local new_undo_list = {}

    local success = new_pin.div.tags.event.clear_all(tick)
    if not success then
      print("replay aborted on failed clear")
      goto finish
    end
    if not tick:check() then return end

    for _, undo_item in pairs(new_pin.undo_list) do
      local _, this_div = new_pin.data_div:div_from_path(undo_item.path)
      if not this_div then
        print("replay aborted on invalid event path", vim.inspect(new_pin.data_div.divs[1].name))
        success = false
        goto finish
      end

      table.insert(new_undo_list, undo_item)

      if not this_div.tags.event[undo_item.event](tick) then
        print("replay aborted on error")
        success = false
        goto finish
      end
      if not tick:check() then return end
    end

    ::finish::
    if not tick:check() then return end

    new_pin.undo_list = new_undo_list

    return success, true
  end

  new_pin.div.tags.event.undo = function(tick)
    if not (#new_pin.undo_list > 0) then return true, true end

    local undo_item = table.remove(new_pin.undo_list)

    local success = new_pin.div.tags.event.replay(tick)
    if not tick:check() then return end

    if success then
      print('Undo on "' .. undo_item.event .. '" action.')
    else
      print('Failed to undo "' .. undo_item.event .. '" action.')
    end

    return success, true
  end

  new_pin.div.tags.event.clear_undo = function(_)
    new_pin.undo_list = {}
    return true, true
  end

  new_pin.div.tags.event.clear_all = function(tick)
    while true do
      local found_div = new_pin.data_div:find(function(div)
          return div.tags.event and div.tags.event.clear
        end)
      if found_div then
        local result = found_div.tags.event.clear(tick)
        if not tick:check() then return true end
        if not result then return false end
      else
        break
      end
    end
    return true
  end

  return new_pin
end

--- Set whether this pin uses a widget or a plain goal/term goal.
function Pin:set_widget(use_widget)
  self.use_widget = use_widget
  self:update()
end

---@param info Info
function Pin:add_parent_info(info)
  self.parent_infos[info.id] = true
end

local extmark_ns = vim.api.nvim_create_namespace("LeanNvimPinExtmarks")

function Pin:_teardown()
  if self.extmark then vim.api.nvim_buf_del_extmark(self.extmark_buf, extmark_ns, self.extmark) end
  infoview._pin_by_id[self.id] = nil
end

function Pin:remove_parent_info(info)
  self.parent_infos[info.id] = nil
  if vim.tbl_isempty(self.parent_infos) then self:_teardown() end
end

local pin_hl_group = "LeanNvimPin"
vim.highlight.create(pin_hl_group, {
  cterm = 'underline',
  ctermbg = '3',
  gui   = 'underline',
}, true)

--- Update this pin's current position.
function Pin:set_position_params(params, delay, lean3_opts)
  local old_params = self.position_params
  self.position_params = params

  lean3_opts = vim.tbl_extend("keep", lean3_opts or {}, {changed = not vim.deep_equal(params, old_params)})

  self:update_extmark()
  self:update(false, delay, nil, lean3_opts)
end

--- Update pin extmark based on position, used when resetting pin position.
function Pin:update_extmark()
  local params = self.position_params
  if not params then return end

  local buf = vim.fn.bufnr(vim.uri_to_fname(params.textDocument.uri))

  if buf ~= -1 then
    local line = params.position.line
    local buf_line = vim.api.nvim_buf_get_lines(buf, line, line + 1, false)[1]
    local col = buf_line and vim.str_byteindex(buf_line, params.position.character) or 0
    local end_col = buf_line and ((col < #buf_line) and
      vim.str_byteindex(buf_line, params.position.character + 1) or col) or 0

    self.extmark = vim.api.nvim_buf_set_extmark(buf, extmark_ns,
      line, col,
      {
        id = self.extmark;
        end_col = end_col;
        hl_group = self.extmark_hl_group;
        virt_text = self.extmark_virt_text;
        virt_text_pos = "right_align";
      })
    self.extmark_buf = buf
  end
end

--- Update pin position based on extmark, used when changing text.
function Pin:update_position(delay, lean3_opts)
  local extmark = self.extmark
  if not extmark then return end

  local buf = self.extmark_buf
  if buf == -1 then return end

  local extmark_pos = vim.api.nvim_buf_get_extmark_by_id(buf, extmark_ns, extmark, {})

  local pos = self.position_params.position
  local new_pos = vim.deepcopy(pos)

  new_pos.line = extmark_pos[1]
  local buf_line = vim.api.nvim_buf_get_lines(buf, new_pos.line, new_pos.line + 1, false)[1]
  new_pos.character = buf_line and vim.str_utfindex(buf_line, extmark_pos[2]) or new_pos.character

  local new_params = vim.deepcopy(self.position_params)
  new_params.position = new_pos
  self:set_position_params(new_params, delay, lean3_opts)
end

function Pin:toggle_pause() if not self.paused then self:pause() else self:unpause() end end

function Pin:show_extmark()
  self.extmark_hl_group = pin_hl_group
  self.extmark_virt_text = {{"<-- PIN " .. tostring(self.id), "Comment"}};
  self:update_extmark()
end

function Pin:hide_extmark()
  self.extmark_hl_group = nil
  self.extmark_virt_text = nil
  self:update_extmark()
end

function Pin:unpause()
  if not self.paused then return end
  self.paused = false
  self:update()
end

function Pin:pause()
  if self.paused then return end
  self.paused = true

  -- allow RPC refs to be released
  for _, subdiv in ipairs(self.div.divs) do
    subdiv:filter(function(div) div.tags = {} end)
  end

  self:render_parents()
end

function Pin:clear_undo_list()
  self.undo_list = {}
end

-- Triggered when manually moving a pin.
function Pin:move(params)
  if not vim.deep_equal(params, self.position_params) then
    self:clear_undo_list()
  end
  self:set_position_params(params)
end

function Pin:render_parents()
  for parent_id, _ in pairs(self.parent_infos) do
    infoview._info_by_id[parent_id]:render()
  end
end

function Pin:set_loading(loading)
  if loading and not self.loading then
    self.div.divs = {}
    self.div:insert_new_div(self.data_div)

    self.loading = true

    self.data_div:filter(function(div)
      div.event_disable = true
      div.highlightable = false
      div.temp_hlgroup = "LeanInfoLoading"
    end)
  elseif not loading then
    self.div.divs = {}
    self.div:insert_new_div(self.data_div)

    self.loading = false

    self.data_div:filter(function(div)
      div.event_disable = false
      if div.temp_hlgroup == "LeanInfoLoading" then
        div.temp_hlgroup = nil
      end
    end)
  end

  self:render_parents()
end

Pin.update = a.void(function(self, force, delay, _, lean3_opts)
  if not force and self.paused then return end

  local tick = self.ticker:lock()
  if not tick then return end

  self:set_loading(true)

  self:_update(force, delay, tick, lean3_opts)
  if not tick:check() then return end

  self:set_loading(false)

  self.ticker:release()
end)

function Pin:_update(force, delay, tick, lean3_opts)
  if self.position_params and (force or not self.paused) then
    return self:__update(tick, delay, lean3_opts)
  end
end

local plain_goal = a.wrap(leanlsp.plain_goal, 3)
local plain_term_goal = a.wrap(leanlsp.plain_term_goal, 3)

local wait_timer = a.wrap(function(timeout, handler) vim.defer_fn(handler, timeout) end, 2)
--- async function to update this pin's contents given the current position.
function Pin:__update(tick, delay, lean3_opts)
  delay = delay or 100

  self.data_div = html.Div:new({pin = self}, "", "pin-data", nil)

  if delay > 0 then
    wait_timer(delay)
  end

  local params = self.position_params

  local buf = vim.fn.bufnr(vim.uri_to_fname(params.textDocument.uri))
  if buf == -1 then
    self.data_div:insert_div({}, "No corresponding buffer found.", "no-buffer-msg")
    return false
  end

  --- TODO if changes are currently being debounced for this buffer, add debounce timer delay
  do
    local line = params.position.line

    if not self.use_widget then self:clear_undo_list() end

    if vim.api.nvim_buf_get_option(buf, "ft") == "lean3" then
      lean3_opts = lean3_opts or {}
      lean3.update_infoview(self, buf, params, self.use_widget, lean3_opts, options.lean3)
      return true
    end

    if require"lean.progress".is_processing_at(params) then
      if options.show_processing then
        self.data_div:insert_div({}, "Processing file...", "processing-msg")
      end
      return true
    end

    self.sess = rpc.open(buf, params)
    if not tick:check() then return true end

    local _, goal = plain_goal(params, buf)
    if not tick:check() then return true end

    local goal_div = components.goal(goal)

    local term_goal, term_goal_err
    local term_goal_div

    if self.use_widget then
      term_goal, term_goal_err = self.sess:getInteractiveTermGoal(params)
      if not tick:check() then return true end
      if term_goal_err then
        term_goal = nil
      else
        term_goal_div = components.interactive_term_goal(term_goal, self.sess)
      end
    end

    if not term_goal then
      self:clear_undo_list()
      local _, _plain_term_goal = plain_term_goal(params, buf)
      if not tick:check() then return true end
      term_goal = _plain_term_goal
      term_goal_div = components.term_goal(term_goal)
    end

    local goal_div_empty, term_goal_div_empty = #goal_div:render() == 0, #term_goal_div:render() == 0

    self.data_div:insert_new_div(goal_div)
    if not goal_div_empty and not term_goal_div_empty then
      self.data_div:add_div(html.Div:new({}, "\n\n", "plain_goal-term_goal-separator"))
    end
    self.data_div:insert_new_div(term_goal_div)

    if goal_div_empty and term_goal_div_empty then
      self.data_div:insert_new_div(html.Div:new({}, "No tactic/term data found.", "no-tactic-term"))
    end


    self.data_div:insert_new_div(components.diagnostics(buf, line))

    if not tick:check() then return true end
    self.div.tags.event.replay(tick)
  end

  return true
end

--- Close all open infoviews (across all tabs).
function infoview.close_all()
  for _, each in pairs(infoview._by_id) do
    each:close()
  end
end

--- An infoview was closed, either directly via `Infoview.close` or manually.
--- Will be triggered via a `WinClosed` autocmd.
---@param id number
function infoview.__was_closed(id)
  infoview._by_id[id]:close()
end

--- Update the info contents appropriately for Lean 4 or 3.
--- Normally will be called on each CursorHold for a buffer containing Lean.
--- TODO perhaps this should be schedule_wrap'ed?
function infoview.__update()
  infoview.get_current_infoview().info:set_last_window()
  infoview.get_current_infoview().info.pin:move(vim.lsp.util.make_position_params())
end

--- Update pins corresponding to the given URI.
function infoview.__update_event(uri)
  if infoview.enabled then
    for _, pin in pairs(infoview._pin_by_id) do
      if pin.position_params and pin.position_params.textDocument.uri == uri then
        pin:update()
      end
    end
  end
end

--- on_lines callback to update pins position according to the given textDocument/didChange parameters.
function infoview.__update_pin_positions(_, bufnr, _, _, _, _, _, _, _)
  for _, pin in pairs(infoview._pin_by_id) do
    if pin.position_params and pin.position_params.textDocument.uri == vim.uri_from_bufnr(bufnr) then
      vim.schedule_wrap(function() pin:update_position(500) end)()
    end
  end
end

--- Enable and open the infoview across all Lean buffers.
function infoview.enable(opts)
  options = vim.tbl_extend("force", options._DEFAULTS, opts)
  infoview.enabled = true
  set_augroup("LeanInfoviewInit", [[
    autocmd FileType lean3 lua require'lean.infoview'.make_buffer_focusable(vim.fn.expand('<afile>'))
    autocmd FileType lean lua require'lean.infoview'.make_buffer_focusable(vim.fn.expand('<afile>'))
  ]])
end

--- Configure the infoview to update when this buffer is active.
function infoview.make_buffer_focusable(name)
  local bufnr = vim.fn.bufnr(name)
  if bufnr == -1 then return end
  if bufnr == vim.api.nvim_get_current_buf() then
    -- because FileType can happen after BufEnter
    infoview.__bufenter()
    infoview.get_current_infoview():focus_on_current_buffer()
  end

  -- WinEnter is necessary for the edge case where you have
  -- a file open in a tab with an infoview and move to a
  -- new window in a new tab with that same file but no infoview
  set_augroup("LeanInfoviewSetFocus", string.format([[
    autocmd BufEnter <buffer=%d> lua require'lean.infoview'.__bufenter()
    autocmd BufEnter,WinEnter <buffer=%d> lua if require'lean.infoview'.get_current_infoview()]] ..
    [[ then require'lean.infoview'.get_current_infoview():focus_on_current_buffer() end
  ]], bufnr, bufnr), 0)
end

--- Set whether a new infoview is automatically opened when entering Lean buffers.
function infoview.set_autoopen(autoopen)
  options.autoopen = autoopen
end

--- Set whether a new pin is automatically paused.
function infoview.set_autopause(autopause)
  options.autopause = autopause
end

local attached_buffers = {}

--- Callback when entering a Lean buffer.
function infoview.__bufenter()
  infoview.__maybe_autoopen()
  local bufnr = vim.api.nvim_get_current_buf()
  if not attached_buffers[bufnr] then
    vim.api.nvim_buf_attach(bufnr, false, {on_lines = infoview.__update_pin_positions;})
    attached_buffers[bufnr] = true
  end
  infoview.__update()
end

--- Open an infoview for the current buffer if it isn't already open.
function infoview.__maybe_autoopen()
  local tabpage = vim.api.nvim_win_get_tabpage(0)
  if not infoview._by_tabpage[tabpage] then
    infoview._by_tabpage[tabpage] = Infoview:new(options.width, options.autoopen)
  end
end

return infoview
