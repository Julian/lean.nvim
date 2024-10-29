---@brief [[
--- Infoview components which can be assembled to show various information
--- about the current Lean module or state.
---@brief ]]

---@tag lean.infoview.components

local Element = require('lean.tui').Element
local config = require 'lean.config'
local log = require 'lean.log'
local rpc = require 'lean.rpc'
local util = require 'lean._util'
local widgets = require 'lean.widgets'

local components = {
  NO_INFO = Element:new { text = 'No info.', name = 'no-info' },
  PROCESSING = Element:new { text = 'Processing file...', name = 'processing' },
}

---A user-facing explanation of a changing piece of the goal state.
---
---Corresponds to equivalent VSCode explanations.
---@type table<DiffTag, string>
local DIFF_TAG_TO_EXPLANATION = {
  wasChanged = 'This subexpression has been modified.',
  willChange = 'This subexpression will be modified.',
  wasInserted = 'This subexpression has been inserted.',
  willInsert = 'This subexpression will be inserted.',
  wasDeleted = 'This subexpression has been removed.',
  willDelete = 'This subexpression will be deleted.',
}

---Format a heading.
local function H(contents)
  return ('▶ %s'):format(contents)
end

---Convert an LSP range to a human-readable, (1,1)-indexed string.
---
---The (1, 1) indexing is to match the interface used interactively for
---`gg` and `|`.
local function range_to_string(range)
  return ('%d:%d-%d:%d'):format(
    range['start'].line + 1,
    range['start'].character + 1,
    range['end'].line + 1,
    range['end'].character + 1
  )
end

local function goal_header(goals)
  return #goals == 0 and H 'goals accomplished 🎉'
    or #goals == 1 and ''
    or H(('%d goals\n'):format(#goals))
end

---The current (tactic) goal state.
---@param goal PlainGoal a Lean `plainGoal` LSP response
---@return Element[] goals the current plain goals
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

---The current (term) goal state.
---@param term_goal table a Lean `plainTermGoal` LSP response
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

  if t.text then
    element:add_child(Element:new { text = t.text, name = 'text' })
  elseif t.append then
    for _, s in ipairs(t.append) do
      element:add_child(code_with_infos(s, sess))
    end
  elseif t.tag then
    local subexpr_info = unpack(t.tag)
    local info_with_ctx = subexpr_info.info

    local info_open = false

    if subexpr_info.diffStatus then
      if element.hlgroup then
        log:warning {
          message = 'quashing a highlight group',
          hlgroup = element.hlgroup,
          diffStatus = subexpr_info.diffStatus,
        }
      end
      element.hlgroup = 'leanInfoDiff' .. subexpr_info.diffStatus
    end

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
          tooltip_element:add_child(Element:new { text = ' : ' })
        end
      end

      if info_popup.type ~= nil then
        tooltip_element:add_child(code_with_infos(info_popup.type, sess))
      end

      if info_popup.doc ~= nil then
        tooltip_element:add_child(Element:new { text = '\n\n' })
        tooltip_element:add_child(Element:new { text = info_popup.doc }) -- TODO: markdown
      end

      if subexpr_info.diffStatus then
        tooltip_element:add_child(Element:new { text = '\n\n' })
        tooltip_element:add_child(Element:new {
          hlgroup = 'Comment',
          text = DIFF_TAG_TO_EXPLANATION[subexpr_info.diffStatus],
        })
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
      go_to_def = go_to_def,
      go_to_decl = go_to_decl,
      go_to_type = go_to_type,
    }
    element.highlightable = true

    element:add_child(code_with_infos(t.tag[2], sess))
  end

  return element
end

---A hypothesis name which is accessible according to Lean's naming conventions.
---@param name string
local function is_accessible(name)
  return name:sub(-#'✝') ~= '✝'
end

---Filter the hypotheses according to view options, then convert them to elements.
---@param hyps InteractiveHypothesisBundle[]
---@param opts InfoviewViewOptions
---@param sess Subsession
---@return Element?
local function to_hypotheses_element(hyps, opts, sess)
  ---@param hyp InteractiveHypothesisBundle
  local children = vim.iter(hyps):map(function(hyp)
    if (not opts.show_instances and hyp.isInstance) or (not opts.show_types and hyp.isType) then
      return
    end

    local names = vim.iter(hyp.names)
    if not opts.show_hidden_assumptions then
      names = names:filter(is_accessible)
    end
    if not names:peek() then
      return
    end

    local element = Element:new {
      name = 'hyp',
      children = {
        Element:new {
          text = names:join ' ',
          hlgroup = hyp.isInserted and 'leanInfoHypNameInserted'
            or hyp.isRemoved and 'leanInfoHypNameRemoved'
            or nil,
        },
        Element:new { text = ' : ' },
        code_with_infos(hyp.type, sess),
      },
    }

    if opts.show_let_values and hyp.val then
      element:add_child(Element:new {
        text = ' := ',
        name = 'hyp_val',
        children = { code_with_infos(hyp.val, sess) },
      })
    end

    return element
  end)

  if not children:peek() then
    return
  end
  if opts.reverse then
    children = children:rev()
  end

  return Element:concat(children:totable(), '\n')
end

---@param goal InteractiveGoal | InteractiveTermGoal
---@param sess Subsession
local function interactive_goal(goal, sess)
  local view_options = config().infoview.view_options or {}

  local children = {
    goal.userName and Element:new { text = ('case %s\n'):format(goal.userName) } or nil,
  }

  local goal_element = Element:new {
    text = goal.goalPrefix or '⊢ ',
    name = 'goal',
    children = { code_with_infos(goal.type, sess) },
  }
  local separator = Element:new { text = '\n' }
  local hyps = to_hypotheses_element(goal.hyps, view_options, sess)

  if view_options.reverse then
    table.insert(children, goal_element)
    if hyps then
      table.insert(children, separator)
      table.insert(children, hyps)
    end
  else
    if hyps then
      table.insert(children, hyps)
      table.insert(children, separator)
    end
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

---The current (term) goal state.
---@param goal InteractiveTermGoal
---@param sess Subsession
---@return Element[]
function components.interactive_term_goal(goal, sess)
  if not goal then
    return {}
  end

  local term_state_element = Element:new {
    text = H(string.format('expected type (%s)\n', range_to_string(goal.range))),
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

---Diagnostic information for the current line from the Lean server.
---@param uri string
---@param line number
---@return Element[]
function components.diagnostics(uri, line)
  local markers = config().infoview.severity_markers

  ---@param diagnostic vim.Diagnostic
  return vim.tbl_map(function(diagnostic)
    return Element:new {
      name = 'diagnostic',
      text = H(string.format(
        '%s: %s%s',
        range_to_string {
          start = { line = diagnostic.lnum, character = diagnostic.col },
          ['end'] = { line = diagnostic.end_lnum, character = diagnostic.end_col },
        },
        markers[diagnostic.severity],
        -- So. #check foo gives back a diagnostic with *no* trailing newline
        -- but #eval foo gives back one *with* a trailing newline.
        -- VSCode displays both of them the same, so let's do that as well by
        -- essentially stripping off one trailing newline if present in a
        -- diagnostic message.
        diagnostic.message:gsub('\n$', '')
      )),
    }
  end, util.lean_lsp_diagnostics({ lnum = line }, vim.uri_to_bufnr(uri)))
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

---@param t TaggedText.MsgEmbed
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
    elseif embed.widget ~= nil then
      local widget = widgets.render(embed.widget.wi)
      if not widget then
        local message = 'Unable to render:\n%s\nFalling back to its `alt` widget.'
        vim.notify_once(message:format(vim.inspect(embed.widget.wi)), vim.log.levels.DEBUG)
        widget = tagged_text_msg_embed(embed.widget.alt, sess)
      end
      element:add_child(widget)
    else
      element:add_child(Element:new {
        text = 'unknown tag:\n' .. vim.inspect(embed) .. '\n' .. vim.inspect(t.tag[2]) .. '\n',
      })
    end
  end

  return element
end

---Diagnostic information for the current line from the Lean server.
---@param line number
---@param diags InteractiveDiagnostic[]
---@param sess Subsession
---@return Element[]
function components.interactive_diagnostics(diags, line, sess)
  local markers = config().infoview.severity_markers

  return vim
    .iter(diags)
    ---@param diagnostic InteractiveDiagnostic
    :map(function(diagnostic)
      if diagnostic.range.start.line ~= line then
        return
      end

      return Element:new {
        text = H(
          ('%s: %s'):format(range_to_string(diagnostic.range), markers[diagnostic.severity])
        ),
        name = 'diagnostic',
        children = { tagged_text_msg_embed(diagnostic.message, sess) },
      }
    end)
    :totable()
end

---@param params lsp.TextDocumentPositionParams
---@param sess? Subsession
---@param use_widgets? boolean
---@return Element[]? goal
---@return LspError? error
function components.goal_at(params, sess, use_widgets)
  local goal, err
  if use_widgets ~= false then
    if sess == nil then
      sess = rpc.open(params)
    end

    goal = sess:getInteractiveGoals(params)
    goal = goal and components.interactive_goals(goal, sess)
  end

  if not goal then
    local uri = params.textDocument.uri
    err, goal = require('lean.lsp').plain_goal(params, vim.uri_to_bufnr(uri))
    goal = goal and components.plain_goal(goal)
  end

  return goal, err
end

---@param params lsp.TextDocumentPositionParams
---@param sess? Subsession
---@param use_widgets? boolean
---@return Element[]?
---@return LspError?
function components.term_goal_at(params, sess, use_widgets)
  local term_goal, err
  if use_widgets ~= false then
    if sess == nil then
      sess = rpc.open(params)
    end

    term_goal = sess:getInteractiveTermGoal(params)
    term_goal = term_goal and components.interactive_term_goal(term_goal, sess)
  end

  if not term_goal then
    local uri = params.textDocument.uri
    err, term_goal = require('lean.lsp').plain_term_goal(params, vim.uri_to_bufnr(uri))
    term_goal = term_goal and components.term_goal(term_goal)
  end

  return term_goal, err
end

---@param params lsp.TextDocumentPositionParams
---@param sess? Subsession
---@param use_widgets? boolean
---@return Element[]?
---@return LspError?
function components.diagnostics_at(params, sess, use_widgets)
  local uri = params.textDocument.uri
  local line = params.position.line

  if use_widgets == false then
    return components.diagnostics(uri, line)
  end

  if sess == nil then
    sess = rpc.open(params)
  end

  local diagnostics, err = sess:getInteractiveDiagnostics {
    start = line,
    ['end'] = line + 1,
  }
  if err then
    -- GENERALIZEME: This is the same kind of code as below for widgets, where
    --               we seem to need some higher-level retry logic.
    --               The difference here clearly is that we want to at some
    --               point fallback to non-interactive diagnostics if we see
    --               repeated failure I think, though maybe that should happen
    --               at the caller.
    sess = rpc.open(params)
    diagnostics, err = sess:getInteractiveDiagnostics {
      start = line,
      ['end'] = line + 1,
    }
    if err then
      return components.diagnostics(uri, line), err
    end
  end

  return components.interactive_diagnostics(diagnostics, line, sess), err
end

---@param params lsp.TextDocumentPositionParams
---@param sess? Subsession
---@param use_widgets? boolean
---@return Element[]? widgets
---@return LspError? error
function components.user_widgets_at(params, sess, use_widgets)
  if not use_widgets then
    return {}
  elseif sess == nil then
    sess = rpc.open(params)
  end
  local response, err = sess:getWidgets(params.position)
  -- luacheck: max_comment_line_length 200
  -- GENERALIZEME: This retry logic helps us pass a test, but belongs higher up
  --               in a way which parallels this VSCode retrying logic:
  --               https://github.com/leanprover/vscode-lean4/blob/33e54067d5fefcdf7f28e4993324fd486a53421c/lean4-infoview/src/infoview/info.tsx#L465-L470
  --               and/or generically retries RPC calls
  if not response then
    sess = rpc.open(params)
    response, err = sess:getWidgets(params.position)
  end
  return widgets.render_response(response), err
end

return components
