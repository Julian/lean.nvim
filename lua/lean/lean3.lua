local Element = require('lean.widgets').Element
local components = require('lean.infoview.components')
local lsp = require('lean.lsp')
local util = require('lean._util')
local subprocess_check_output = util.subprocess_check_output

local lean3 = {}


--- Return the current Lean 3 search path.
---
--- Includes both the Lean 3 core libraries as well as project-specific
--- directories (i.e. equivalent to what is reported by `lean --path`).
function lean3.__current_search_paths()
  local root = util.list_workspace_folders()[1]
  local result = subprocess_check_output{command = "lean", args = {"--path"}, cwd = root }
  return vim.fn.json_decode(table.concat(result, '')).path
end

local function is_widget_element(result)
  return type(result) == 'table' and result.t;
end

local class_to_hlgroup = {
  ["expr-boundary highlight"] = "leanInfoExternalHighlight";
  ["bg-blue br3 ma1 ph2 white"] = "leanInfoField";
  ["bg-gray br3 ma1 ph2 white"] = "leanInfoFieldAlt";
  ["goal-goals"] = "leanInfoGoals";
  ["goal-hyp b pr2"] = "leanInfoGoalHyp";
  ["goal-vdash b"] = "leanInfoGoalVDash";
}

-- mapping from lean3 events to standard widget element events
local to_event = {
  ["onMouseEnter"] = "cursor_enter";
  ["onMouseLeave"] = "cursor_leave";
  ["onClick"] = "click";
  ["onChange"] = "change";
}

local function parse_children(children, options)
  local prev_element
  local this_element = Element:new{ name = "children" }
  for _, child in pairs(children) do
    local last_hard_stop = false
    if prev_element then
      local prev_element_string = prev_element:to_string()
      if #prev_element_string > 0 then
        local last_byte_idx = 0
        if #prev_element_string > 0 then
          last_byte_idx = vim.str_byteindex(prev_element_string, vim.fn.strchars(prev_element_string) - 1) + 1
        end

        local last_char = prev_element_string:sub(last_byte_idx, #prev_element_string)
        if last_char ~= " "
          and last_char ~= "\n"
          and last_char ~= "("
          and last_char ~= "["
          and last_char ~= "{"
          and last_char ~= "@"
          and last_char ~= "↑"
          and last_char ~= "⇑"
          and last_char ~= "↥"
          and last_char ~= "¬"
          then
          last_hard_stop = true
        end
      end
    end

    local new_element = lean3.parse_widget(child, options)
    local new_element_string = new_element:to_string()
    if #new_element_string == 0 then goto continue end

    local this_hard_start = false
    if #new_element_string > 0 then
      local first_char = new_element_string:sub(1, 1)
      if first_char ~= " "
        and first_char ~= "\n"
        and first_char ~= ")"
        and first_char ~= "]"
        and first_char ~= "}"
        and first_char ~= ","
        and first_char ~= "."
        then
        this_hard_start = true
      end
    end

    if last_hard_stop and this_hard_start then
      this_element:add_child(Element:new{ text = " ", name = "separator" })
    end

    this_element:add_child(new_element)

    prev_element = new_element

    ::continue::
  end
  return this_element
end

local function parse_select(children, select_element, current_value, options)
  local no_filter_element, no_filter_val, current_text
  local this_element = Element:new{ name = "select-children" }
  for child_i, child in pairs(children) do
    local new_element = lean3.parse_widget(child, options)
    new_element.events.click = function(ctx)
      return select_element.events.change(ctx, child.a.value)
    end
    new_element.highlightable = true
    this_element:add_child(new_element)
    if child_i ~= #children then
      this_element:add_child(Element:new{ text = "\n", name = 'select-separator' })
    end

    if child.c[1] == "no filter" then
      no_filter_element = new_element
      no_filter_val = child.a.value
    end

    if child.a.value == current_value then
      current_text = child.c[1]
    end
  end
  return this_element, no_filter_element, no_filter_val, current_text
end

function lean3.parse_widget(result, options)
  if type(result) == "string" then
    result = result:gsub('^%s*(.-)%s$', '%1')
    return Element:new{ text = result, name = 'widget-element-string' }
  elseif is_widget_element(result) then
    local tag = result.t
    local children = result.c
    local attributes = result.a
    local class_name = attributes and attributes.className
    local tooltip = result.tt
    local events = {}
    local hlgroup

    hlgroup = class_to_hlgroup[class_name]
    if tag == "button" then hlgroup = hlgroup or "leanInfoButton" end

    local element = Element:new {
      name = 'element',
      hlgroup = hlgroup,
      events = events,
    }

    if class_name == "goal-goals" then
      element:add_child(Element:new{ text = '▶ ', name = 'goal-prefix' })
    end

    -- close tooltip button
    if tag == "button" and result.c and result.c[1] == "x" or result.c[1] == "×" then
      element.events.clear = function()
        element.events["click"]()
      end
    end

    if result.e then
      for event, handler in pairs(result.e) do
        local element_event = to_event[event]
        if not options.mouse_events then
          if element_event == "cursor_enter" then
            element_event = "mouse_enter"
          end
          if element_event == "cursor_leave" then
            element_event = "mouse_leave"
          end
        end
        local clickable_event = element_event == "click" or element_event == "change"
        if clickable_event then element.highlightable = true end
        events[element_event] = function(ctx, value)
          local args = type(value) == 'string' and { type = 'string', value = value }
            or { type = 'unit' }
          options.send_widget_event{
            kind = event,
            handler = handler,
            args = args,
          }
          if element_event == "cursor_leave" then
            ctx.self:buf_event("cursor_enter")
          end
        end
      end
    end

    if tag == "hr" then
      element:add_child(
        Element:new{
          text = "|",
          name = "rule",
          hlgroup = "leanInfoFieldSep",
        }
      )
    end

    if options.show_filter and tag == "select" then
      local select_children_element, no_filter_element, no_filter_val, current_text =
        parse_select(children, element, attributes.value, options)
      if no_filter_val and no_filter_val ~= attributes.value then
        element.events.clear = function()
          no_filter_element.events.click()
          return true
        end
      end
      local select_menu_element = Element:new{
        text = current_text .. "\n",
        name = "current-select"
      }
      element:add_child(select_menu_element)
      select_menu_element:add_tooltip(select_children_element)
    elseif tag == 'ul' then
      for i, child in ipairs(children) do
        if i > 2 and child.a and child.a.className == 'lh-copy mt2' then
          element:add_child(Element:new{ text = '\n\n', name = 'goal-separator' })
        elseif i > 1 then
          element:add_child(Element:new{ text = '\n', name = 'list-separator' })
        end
        element:add_child(lean3.parse_widget(child, options))
      end
    else
      element:add_child(parse_children(children, options))
    end

    if tooltip then
      element:add_tooltip(lean3.parse_widget(tooltip, options))
    end

    local debug_tags = false
    if debug_tags then
      element = Element:new{
        name = "debug-tags",
        children = {
          Element:new{ text = "<" .. tag ..
              " attributes(" .. vim.inspect(attributes) .. ")" ..
              " events(" .. vim.inspect(result.e) .. ")" ..
            ">" },
          element,
          Element:new{ text = "</" .. tag .. ">" },
        },
      }
    end

    return element
  else
    return parse_children(result.c, options)
  end
end

function lean3.update_infoview(
  pin,
  data_element,
  bufnr,
  params,
  use_widgets,
  opts,
  options,
  show_processing,
  show_no_info_message
)
  local client = lsp.get_lean3_server(bufnr)
  if not client then return end

  local parent_element = Element:new{ name = "lean-3-widget" }

  params = vim.deepcopy(params)
  local state_element --- @type Element?

  if require"lean.progress".is_processing_at(params) then
    if show_processing then
      data_element:add_child(Element:new{ text = "Processing file...", name = "processing-msg" })
    end
    goto finish
  end

  if use_widgets then
    local err, result
    if not (opts and opts.widget_event) then
      err, result = util.client_a_request(client, "$/lean/discoverWidget", params)
    else
      err, result = util.client_a_request(client, "$/lean/widgetEvent", opts.widget_event)
      if result and result.record then result = result.record end
    end

    if not err and result and result.widget and result.widget.html then
      if result.effects then
        for _, effect in pairs(result.effects) do
          if effect.kind == "reveal_position" then
            local this_infoview = require"lean.infoview".get_current_infoview()
            local this_info = this_infoview and this_infoview.info
            local this_window = this_info and this_info.last_window
            -- effect.file_name == nil means current file
            local this_buf = effect.file_name and
              vim.uri_to_bufnr(vim.uri_from_fname(effect.file_name)) or
              (this_info and vim.uri_to_bufnr(params.textDocument.uri))
            if this_window and vim.api.nvim_win_is_valid(this_window) then
              if this_buf then
                vim.api.nvim_win_set_buf(this_window, this_buf)
              end
              vim.api.nvim_set_current_win(this_window)
              vim.api.nvim_win_set_cursor(this_window, {effect.line, effect.column})
            end
          end
        end
      end

      local widget = result.widget
      state_element = lean3.parse_widget(result.widget.html, {
        mouse_events = options.mouse_events,
        show_filter = options.show_filter,
        send_widget_event = function(ev)
          ev.textDocument = pin.__position_params.textDocument
          ev.widget = widget
          pin:async_update(false, { widget_event = ev })
        end,
      })
    end
  end

  if not state_element then
    local _, result = util.client_a_request(client, "$/lean/plainGoal", params)
    if result and type(result) == "table" then
      state_element = Element:concat(components.goal(result), '\n\n')
    end
  end

  if state_element and not state_element:is_empty() then
    parent_element:add_child(state_element)
  elseif show_no_info_message then
    parent_element:add_child(Element:new{ text = "No info.", name = "no-tactic-term" })
  end

  -- update all other pins for the same URI so they aren't left with a stale "session"
  if opts and opts.widget_event then
    for _, each in pairs(require'lean.infoview'._by_tabpage) do  -- FIXME: Private!
      local pins = { each.info.pin }
      vim.list_extend(pins, each.info.pins)
      for _, other_pin in ipairs(pins) do
        if other_pin ~= pin and other_pin.__position_params and
          other_pin.__position_params.textDocument.uri == pin.__position_params.textDocument.uri then
          other_pin:update()
        end
      end
    end
  end

  ::finish::

  for _, diag in ipairs(components.diagnostics(bufnr, params.position.line)) do
    parent_element:add_child(Element:new{ text = '\n\n' })
    parent_element:add_child(diag)
  end

  data_element:add_child(parent_element)

  return true
end

function lean3.lsp_enable(opts)
  opts.handlers = vim.tbl_extend("keep", opts.handlers or {}, {
    ['$/lean/fileProgress'] = util.mk_handler(lsp.handlers.file_progress_handler);
    ['textDocument/publishDiagnostics'] = function(...)
      util.mk_handler(lsp.handlers.diagnostics_handler)(...)
      vim.lsp.handlers['textDocument/publishDiagnostics'](...)
    end;
  })
  opts.offset_encoding = "utf-32"
  require'lspconfig'.lean3ls.setup(opts)
end

return lean3
