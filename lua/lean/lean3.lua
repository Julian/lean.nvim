local find_project_root = require('lspconfig.util').root_pattern('leanpkg.toml')
local dirname = require('lspconfig.util').path.dirname

local components = require('lean.infoview.components')
local subprocess_check_output = require('lean._util').subprocess_check_output

local a = require('plenary.async')

local html = require('lean.html')

local lean3 = {}

-- Ideally this obviously would use a TOML parser but yeah choosing to
-- do nasty things and not add the dependency for now.
local _PROJECT_MARKER = '.*lean_version.*\".*:3.*'
local _STANDARD_LIBRARY_PATHS = '.*/[^/]*lean[%-]+3.+/lib/'

--- Detect whether the current buffer is a Lean 3 file using regex matching.
function lean3.__detect_regex(filename)
  local bufnr = vim.fn.bufnr(filename)
  if bufnr == -1 then return end

  local path = vim.uri_to_fname(vim.uri_from_bufnr(bufnr))
  if path:match(_STANDARD_LIBRARY_PATHS) then return true end

  local project_root = find_project_root(path)
  if project_root then
    local result = vim.fn.readfile(project_root .. '/leanpkg.toml')
    for _, line in ipairs(result) do
      if line:match(_PROJECT_MARKER) then return true end
    end
  end

  return false
end

--- Detect whether the current buffer is a Lean 3 file using elan.
function lean3.__detect_elan(filename)
  local bufnr = vim.fn.bufnr(filename)
  if bufnr == -1 then return end

  local path = vim.uri_to_fname(vim.uri_from_bufnr(bufnr))
  local version_string = (require"lean._util".subprocess_check_output
    { command = "lean", args = {"--version"}, cwd = dirname(path) })[1]
  local _, _, version_num = version_string:find("version (%d+)%.%d+%.%d+")
  if version_num == "3" then return true end

  return false
end

--- Return the current Lean 3 search path.
---
--- Includes both the Lean 3 core libraries as well as project-specific
--- directories (i.e. equivalent to what is reported by `lean --path`).
function lean3.__current_search_paths()
  local root = vim.lsp.buf.list_workspace_folders()[1]
  local result = subprocess_check_output{command = "lean", args = {"--path"}, cwd = root }
  return vim.fn.json_decode(table.concat(result, '')).path
end

local function is_widget_element(result)
  return type(result) == 'table' and result.t;
end

local class_to_hlgroup = {
  ["expr-boundary highlight"] = "leanInfoExternalHighlight";
  ["bg-blue br3 ma1 ph2 white"] = "leanInfoField"
}

local undo_map = {
  ["mouse_enter"] = "mouse_leave";
  ["mouse_leave"] = "mouse_enter";
  ["click"] = "click";
}

-- mapping from lean3 events to standard div events
local to_event = {
  ["onMouseEnter"] = "mouse_enter";
  ["onMouseLeave"] = "mouse_leave";
  ["onClick"] = "click";
}

local buf_request = a.wrap(vim.lsp.buf_request, 4)
function lean3.update_infoview(pin, bufnr, params, use_widget, opts)
  local parent_div = html.Div:new({}, "")
  local widget, widget_div

  local function parse_widget(result)
    local div = html.Div:new({}, "")
    local function parse_children(children)
      local prev_div
      for _, child in pairs(children) do
        local last_hard_stop = false
        if prev_div then
          local prev_div_string = prev_div:render()
          if #prev_div_string > 0 then
            local last_char = prev_div_string:sub(#prev_div_string, #prev_div_string)
            if last_char ~= " " and last_char ~= "\n" and last_char ~= "(" then
              last_hard_stop = true
            end
          end
        end

        local new_div = parse_widget(child)
        local new_div_string = new_div:render()
        if #new_div_string == 0 then goto continue end

        local this_hard_start = false
        if #new_div_string > 0 then
          local first_char = new_div_string:sub(1, 1)
          if first_char ~= " " and first_char ~= "\n" and first_char ~= ")" and first_char ~= "," then
            this_hard_start = true
          end
        end

        if last_hard_stop and this_hard_start then
          div:insert_div({}, " ", "separator")
        end

        div:insert_new_div(new_div)

        prev_div = new_div

        ::continue::
      end
    end

    if type(result) == "string" then
      result = result:gsub('^%s*(.-)%s$', '%1')

      div:insert_div({}, result, "html-string")

      return div
    elseif is_widget_element(result) then
      local tag = result.t
      local children = result.c
      local tooltip = result.tt
      local events = {}
      local hlgroup

      if tag == "li" then
        div:insert_div({}, "\n", "list-separator")
      end

      if tag == "label" or tag == "select" or tag == "option" then return div, false end
      hlgroup = class_to_hlgroup[result.a and result.a.className]
      if tag == "button" then hlgroup = hlgroup or "leanInfoButton" end

      --div:insert_div({element = result}, "<" .. tag .. ">", "element")
      --div:insert_div({element = result}, "<" .. tag .. " " .. vim.inspect(result.a) .. ">", "element")
      local element_div = div:start_div({element = result, event = events}, "", "element", hlgroup)

      if result.e then
        for event, handler in pairs(result.e) do
          local div_event = to_event[event]
          events[div_event] = function(undo)
            a.void(function()
              local pos = not undo and widget_div:pos_from_div(element_div)

              pin:_update(false, 0, {widget_event = {
                widget = widget,
                kind = event,
                handler = handler,
                args = { type = 'unit' },
                textDocument = pin.position_params.textDocument
              }})

              if undo or not pos then return end
              table.insert(pin.undo_list, {
                pos = pos;
                event = div_event
              })
            end)()
          end
        end
      end

      if tag == "hr" then
        div:insert_div({}, "|", "rule", "leanInfoFieldSep")
      end

      parse_children(children)

      if tooltip then
        div:insert_div({element = result}, "→", "tooltip-separator", "leanInfoTooltipSep")
        div:insert_div({element = result}, "[", "tooltip-start", "leanInfoTooltipSep")
        div:start_div({element = result}, "", "tooltip", "leanInfoTooltip")
        div:insert_new_div(parse_widget(tooltip))
        div:end_div()
        div:insert_div({element = result}, "]", "tooltip-close", "leanInfoTooltipSep")
      end
      div:end_div()
      --div:insert_div({element = result}, "</" .. tag .. ">", "element")
      return div
    else
      parse_children(result.c)
      return div
    end
  end

  params = vim.deepcopy(params)
  if use_widget then
    local err, result
    if not (opts and opts.widget_event) then
      local _err, _, _result = buf_request(bufnr, "$/lean/discoverWidget", params)
      if opts and opts.changed then
        pin.undo_list = {}
      end
      err, result = _err, _result
    else
      local _err, _, _result = buf_request(bufnr, "$/lean/widgetEvent", opts.widget_event)
      err, result = _err, _result
      if result and result.record then result = result.record end
    end

    if not err and result and result.widget and result.widget.html then
      widget = result.widget
      widget_div = parent_div:start_div({widget = widget, event = {
        ["undo"] = function()
          local last_undo = pin.undo_list[#(pin.undo_list)]
          if not last_undo then
            print("Nothing left to undo for pin " .. tostring(pin.id))
            return
          end
          local pos = last_undo.pos
          local event = last_undo.event

          parent_div:event(pos, undo_map[event], true)
          table.remove(pin.undo_list)
        end
      }}, "Tactic/Term State", "widget")
      parent_div:insert_new_div(parse_widget(result.widget.html))
      parent_div:end_div()
    end
  else
    local _, _, result = buf_request(bufnr, "$/lean/plainGoal", params)
    if result and type(result) == "table" then
      parent_div:insert_new_div(components.goal(result))
    end
  end
  parent_div:insert_new_div(components.diagnostics(bufnr, params.position.line))

  return parent_div
end

function lean3.lsp_enable(opts)
  opts.handlers = vim.tbl_extend("keep", opts.handlers or {}, {
    ['textDocument/publishDiagnostics'] = require"lean.lsp".handlers.diagnostics_handler;
  })
  require'lspconfig'.lean3ls.setup(opts)
end

return lean3
