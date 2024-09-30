---@brief [[
--- Infoview components which can be assembled to show various information
--- about the current Lean module or state.
---@brief ]]

---@tag lean.infoview.components

local Element = require('lean.tui').Element
local config = require 'lean.config'
local util = require 'lean._util'
local widgets = require 'lean.widgets'

local components = {
  NO_INFO = Element:new { text = 'No info.', name = 'no-info' },
  PROCESSING = Element:new { text = 'Processing file...', name = 'processing' },
}

--- Format a heading.
local function H(contents)
  return ('▶ %s'):format(contents)
end

--- Convert an LSP range to a human-readable, (1,1)-indexed string.
---
--- The (1, 1) indexing is to match the interface used interactively for
--- `gg` and `|`.
local function range_to_string(range)
  return ('%d:%d-%d:%d'):format(
    range['start'].line + 1,
    range['start'].character + 1,
    range['end'].line + 1,
    range['end'].character + 1
  )
end

local function goal_header(goals)
  return #goals == 0 and H 'goals accomplished 🎉\n'
    or #goals == 1 and ''
    or H(('%d goals\n'):format(#goals))
end

--- The current (tactic) goal state.
---@param goal table: a Lean `plainGoal` LSP response
---@return Element[]
function components.plain_goal(goal)
  if type(goal) ~= 'table' or not goal.goals then
    return {}
  end

  local children = vim.iter(goal.goals):fold(nil, function(acc, k)
    if acc then
      table.insert(
        acc,
        Element:new {
          text = '\n\n' .. k,
          name = 'plain-goal',
        }
      )
    else
      acc = { Element:new { text = k, name = 'plain-goal' } }
    end
    return acc
  end)

  return {
    Element:new {
      name = 'plain-goals',
      children = {
        Element:new {
          name = 'plain-goals-list',
          text = goal_header(goal.goals),
          children = children,
        },
      },
    },
  }
end

--- The current (term) goal state.
---@param term_goal table: a Lean `plainTermGoal` LSP response
---@return Element[]
function components.term_goal(term_goal)
  if type(term_goal) ~= 'table' or not term_goal.goal then
    return {}
  end

  return {
    Element:new {
      text = H(
        ('expected type (%s)'):format(range_to_string(term_goal.range)) .. '\n' .. term_goal.goal
      ),
      name = 'term-goal',
    },
  }
end

---@param t CodeWithInfos
---@param sess Subsession
local function code_with_infos(t, sess)
  local element = Element:new { name = 'code-with-infos' }

  if t.text ~= nil then
    element:add_child(Element:new { text = t.text, name = 'text' })
  elseif t.append ~= nil then
    for _, s in ipairs(t.append) do
      element:add_child(code_with_infos(s, sess))
    end
  elseif t.tag ~= nil then
    local info_with_ctx = t.tag[1].info

    local info_open = false

    local do_reset = function(ctx)
      info_open = false
      element:remove_tooltip()
      ctx.rehover()
    end

    ---@param info_popup InfoPopup
    local mk_tooltip = function(info_popup)
      local tooltip_element = Element.noop()

      if info_popup.exprExplicit ~= nil then
        tooltip_element:add_child(code_with_infos(info_popup.exprExplicit, sess))
        if info_popup.type ~= nil then
          tooltip_element:add_child(Element:new { text = ' :\n' })
        end
      end

      if info_popup.type ~= nil then
        tooltip_element:add_child(code_with_infos(info_popup.type, sess))
      end

      if info_popup.doc ~= nil then
        tooltip_element:add_child(Element:new { text = '\n\n' })
        tooltip_element:add_child(Element:new { text = info_popup.doc }) -- TODO: markdown
      end

      return tooltip_element
    end

    local do_open_all = function(ctx)
      local info_popup, err = sess:infoToInteractive(info_with_ctx)

      local tooltip
      if err then
        tooltip = Element.noop(vim.inspect(err))
      else
        tooltip = mk_tooltip(info_popup)
        info_open = true
      end

      element:add_tooltip(tooltip)
      ctx.rehover()
    end

    local click = function(ctx)
      if info_open then
        return do_reset(ctx)
      else
        return do_open_all(ctx)
      end
    end

    ---@param kind GoToKind
    local go_to = function(_, kind)
      local links, err = sess:getGoToLocation(kind, info_with_ctx)
      if err or #links == 0 then
        return
      end

      -- Switch to window of current Lean file
      local this_infoview = require('lean.infoview').get_current_infoview()
      local this_info = this_infoview and this_infoview.info
      local this_window = this_info and this_info.last_window
      if this_window then
        vim.api.nvim_set_current_win(this_window)
      end

      vim.lsp.util.jump_to_location(links[1], 'utf-16')
      if #links > 1 then
        vim.fn.setqflist({}, ' ', {
          title = 'LSP locations',
          items = vim.lsp.util.locations_to_items(links, 'utf-16'),
        })
        vim.cmd 'botright copen'
      end
    end
    local go_to_def = function(ctx)
      go_to(ctx, 'definition')
    end
    local go_to_decl = function(ctx)
      go_to(ctx, 'declaration')
    end
    local go_to_type = function(ctx)
      go_to(ctx, 'type')
    end

    element.events = {
      click = click,
      clear = function(ctx)
        if info_open then
          do_reset(ctx)
        end
      end,
      go_to = go_to,
      go_to_def = go_to_def,
      go_to_decl = go_to_decl,
      go_to_type = go_to_type,
    }
    element.highlightable = true

    element:add_child(code_with_infos(t.tag[2], sess))
  end

  return element
end

--- A hypothesis name which is accessible according to Lean's naming conventions.
---@param name string
local function is_accessible(name)
  return name:sub(-#'✝') ~= '✝'
end

--- Filter the given goal hypotheses according to configured view options.
--- @param hyps InteractiveHypothesisBundle[]
--- @param opts InfoviewViewOptions
--- @return InteractiveHypothesisBundle[]
local function get_filtered_hypotheses(hyps, opts)
  ---@param hyp InteractiveHypothesisBundle
  return vim.iter(hyps):fold({}, function(acc, hyp)
    if (not opts.show_instances and hyp.isInstance) or (not opts.show_types and hyp.isType) then
      return acc
    end

    local names = opts.show_hidden_assumptions and hyp.names
      or vim.iter(hyp.names):filter(is_accessible):totable()
    ---@type InteractiveHypothesisBundle
    local h_new = vim.tbl_extend('force', hyp, {
      names = names,
      val = opts.show_let_values and hyp.val or nil,
    })

    if #names ~= 0 then
      table.insert(acc, h_new)
    end
    return acc
  end)
end

---@param goal InteractiveGoal | InteractiveTermGoal
---@param sess Subsession
local function interactive_goal(goal, sess)
  local view_options = config().infoview.view_options or {}

  local goal_element = Element:new {
    text = goal.goalPrefix or '⊢ ',
    name = 'goal',
    children = { code_with_infos(goal.type, sess) },
  }

  local children = {
    goal.userName and Element:new { text = ('case %s\n'):format(goal.userName) } or nil,
  }

  local hyps = vim.iter(get_filtered_hypotheses(goal.hyps, view_options))
  if view_options.reverse then
    table.insert(children, goal_element)
    table.insert(children, Element:new { text = '\n' })
    hyps = hyps:rev()
  end

  ---@param hyp InteractiveHypothesisBundle
  hyps:each(function(hyp)
    local hyp_element = Element:new {
      text = table.concat(hyp.names, ' ') .. ' : ',
      name = 'hyp',
      children = { code_with_infos(hyp.type, sess) },
    }
    if view_options.show_let_values and hyp.val ~= nil then
      hyp_element:add_child(Element:new {
        text = ' := ',
        name = 'hyp_val',
        children = { code_with_infos(hyp.val, sess) },
      })
    end
    hyp_element:add_child(Element:new { text = '\n', name = 'hypothesis-separator' })
    table.insert(children, hyp_element)
  end)

  if view_options.reverse ~= true then
    table.insert(children, goal_element)
  end

  return Element:new { name = 'interactive-goal', children = children }
end

---@param goal InteractiveGoals?
---@param sess Subsession
---@return Element[]
function components.interactive_goals(goal, sess)
  if goal == nil then
    return {}
  end

  local children = vim
    .iter(goal.goals)
    :fold({ Element:new { text = goal_header(goal.goals) } }, function(acc, k)
      table.insert(acc, Element:new { text = #acc == 1 and '' or '\n\n' })
      table.insert(acc, interactive_goal(k, sess))
      return acc
    end)

  return { Element:new { name = 'interactive-goals', children = children } }
end

--- The current (term) goal state.
---@param goal InteractiveTermGoal
---@param sess Subsession
---@return Element[]
function components.interactive_term_goal(goal, sess)
  if not goal then
    return {}
  end

  local term_state_element = Element:new {
    text = H(string.format('expected type (%s)', range_to_string(goal.range))) .. '\n',
    name = 'term-state',
    children = { interactive_goal(goal, sess) },
  }
  return {
    Element:new {
      name = 'interactive-term-goal',
      children = { term_state_element },
    },
  }
end

--- Diagnostic information for the current line from the Lean server.
---@return Element[]
function components.diagnostics(bufnr, line)
  return vim.tbl_map(function(diagnostic)
    return Element:new {
      name = 'diagnostic',
      text = H(string.format(
        '%s: %s:\n%s',
        range_to_string {
          start = { line = diagnostic.lnum, character = diagnostic.col },
          ['end'] = { line = diagnostic.end_lnum, character = diagnostic.end_col },
        },
        util.DIAGNOSTIC_SEVERITY[diagnostic.severity],
        diagnostic.message
      )),
    }
  end, util.lean_lsp_diagnostics({ lnum = line }, bufnr))
end

local function abbreviate_common_prefix(a, b)
  local i = a:find '[.]'
  local j = b:find '[.]'
  if i and j and i == j and a:sub(1, i) == b:sub(1, i) then
    return abbreviate_common_prefix(a:sub(i + 1), b:sub(i + 1))
  elseif not i and j and b:sub(1, j - 1) == a then
    return b:sub(j + 1)
  elseif a == b then
    return ''
  else
    return b
  end
end

---@param t TaggedTextMsgEmbed
---@param sess Subsession
---@param parent_cls? string
local function tagged_text_msg_embed(t, sess, parent_cls)
  local element = Element:new { name = 'code-with-infos' }

  if t.text ~= nil then
    element.text = t.text
  elseif t.append ~= nil then
    for _, s in ipairs(t.append) do
      element:add_child(tagged_text_msg_embed(s, sess))
    end
  elseif t.tag ~= nil then
    local embed = t.tag[1]
    if embed.expr ~= nil then
      return code_with_infos(embed.expr, sess)
    elseif embed.goal ~= nil then
      return interactive_goal(embed.goal, sess)
    elseif embed.lazyTrace ~= nil then
      local indent = embed.lazyTrace[1]
      local category = embed.lazyTrace[2]
      local msg_data = embed.lazyTrace[3]

      local is_open = false
      local expanded, expanded_err

      local click
      local function render()
        local header =
          Element:new { text = string.format(is_open and '[%s] ▼' or '[%s] ▶', category) }
        header.highlightable = true
        header.events = { click = click }

        element:set_children { header }

        if is_open then
          if expanded then
            element:add_child(tagged_text_msg_embed(expanded, sess))
          elseif expanded_err then
            element:add_child(Element:new { text = vim.inspect(expanded_err) })
          end
        end
        return true
      end

      click = function(ctx)
        if is_open then
          is_open = false
        else
          is_open = true

          if not expanded then
            expanded, expanded_err = sess:msgToInteractive(msg_data, indent)
          end
        end
        render()
        ctx.rerender()
      end

      render()
    elseif embed.trace ~= nil then
      local indent = embed.trace.indent
      local cls = embed.trace.cls
      local msg = embed.trace.msg
      local collapsed = embed.trace.collapsed
      local children = embed.trace.children
      local children_err

      local abbr_cls = cls
      if parent_cls ~= nil then
        abbr_cls = abbreviate_common_prefix(parent_cls, cls)
      end

      local is_open = not collapsed

      local click
      local function render()
        local header = Element:new { text = string.format('%s[%s] ', (' '):rep(indent), abbr_cls) }
        header:add_child(tagged_text_msg_embed(msg, sess))
        if children.lazy or #children.strict > 0 then
          header.highlightable = true
          header.events = { click = click }
          header:add_child(Element:new { text = (is_open and ' ▼' or ' ▶') .. '\n' })
        else
          header:add_child(Element:new { text = '\n' })
        end

        element:set_children { header }

        if is_open then
          if children_err then
            element:add_child(Element:new { text = vim.inspect(children_err) })
          elseif children.strict ~= nil then
            for _, child in ipairs(children.strict) do
              element:add_child(tagged_text_msg_embed(child, sess, cls))
            end
          end
        end
        return true
      end

      click = function(ctx)
        if is_open then
          is_open = false
        else
          is_open = true

          if children.lazy ~= nil then
            local new_kids, err = sess:lazyTraceChildrenToInteractive(children.lazy)
            children_err = err
            children = { strict = new_kids }
          end
        end
        render()
        ctx.rerender()
      end

      render()
    else
      element:add_child(Element:new {
        text = 'unknown tag:\n' .. vim.inspect(embed) .. '\n' .. vim.inspect(t.tag[2]) .. '\n',
      })
    end
  end

  return element
end

--- Diagnostic information for the current line from the Lean server.
---@param line number
---@param diags InteractiveDiagnostic[]
---@param sess Subsession
---@return Element[]
function components.interactive_diagnostics(diags, line, sess)
  local elements = {}
  for _, diag in pairs(diags) do
    if diag.range.start.line == line then
      local element = Element:new {
        text = H(
          ('%s: %s:\n'):format(range_to_string(diag.range), util.DIAGNOSTIC_SEVERITY[diag.severity])
        ),
        name = 'diagnostic',
        children = { tagged_text_msg_embed(diag.message, sess) },
      }
      table.insert(elements, element)
    end
  end
  return elements
end

---@param bufnr integer
---@param params lsp.TextDocumentPositionParams
---@param sess? Subsession
---@param use_widgets? boolean
---@return Element[] goal
---@return LspError? error
function components.goal_at(bufnr, params, sess, use_widgets)
  local goal, err
  if use_widgets ~= false then
    if sess == nil then
      sess = require('lean.rpc').open(bufnr, params)
    end

    goal = sess:getInteractiveGoals(params)
    goal = goal and components.interactive_goals(goal, sess)
  end

  if not goal then
    err, goal = require('lean.lsp').plain_goal(params, bufnr)
    goal = goal and components.plain_goal(goal)
  end

  return goal, err
end

---@param bufnr integer
---@param params lsp.TextDocumentPositionParams
---@param sess? Subsession
---@param use_widgets? boolean
---@return Element[]
---@return LspError?
function components.term_goal_at(bufnr, params, sess, use_widgets)
  local term_goal, err
  if use_widgets ~= false then
    if sess == nil then
      sess = require('lean.rpc').open(bufnr, params)
    end

    term_goal = sess:getInteractiveTermGoal(params)
    term_goal = term_goal and components.interactive_term_goal(term_goal, sess)
  end

  if not term_goal then
    err, term_goal = require('lean.lsp').plain_term_goal(params, bufnr)
    term_goal = term_goal and components.term_goal(term_goal)
  end

  return term_goal, err
end

---@param bufnr integer
---@param params lsp.TextDocumentPositionParams
---@param sess? Subsession
---@param use_widgets? boolean
---@return Element[]
---@return LspError?
function components.diagnostics_at(bufnr, params, sess, use_widgets)
  local line = params.position.line

  if use_widgets == false then
    return components.diagnostics(bufnr, line)
  end

  if sess == nil then
    sess = require('lean.rpc').open(bufnr, params)
  end

  local diagnostics, err = sess:getInteractiveDiagnostics {
    start = line,
    ['end'] = line + 1,
  }
  if err then
    return components.diagnostics(bufnr, line), err
  end

  return components.interactive_diagnostics(diagnostics, line, sess), err
end

---@param bufnr integer
---@param params lsp.TextDocumentPositionParams
---@param sess? Subsession
---@param use_widgets? boolean
---@return Element[]? widgets
---@return LspError? error
function components.user_widgets_at(bufnr, params, sess, use_widgets)
  if not use_widgets then
    return {}
  elseif sess == nil then
    sess = require('lean.rpc').open(bufnr, params)
  end
  return widgets.render_response(sess:getWidgets(params.position))
end

return components
