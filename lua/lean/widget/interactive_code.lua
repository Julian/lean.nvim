local Element = require('lean.tui').Element
local TaggedText = require 'lean.widget.tagged_text'
local log = require 'lean.log'

local interactive_code = {}

---@alias DiffTag 'wasChanged' | 'willChange' | 'wasDeleted' | 'willDelete' | 'wasInserted' | 'willInsert'

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

---Information about a subexpression within delaborated code.
---@class SubexprInfo
---@field info InfoWithCtx
---@field subexprPos integer The position of this subexpression within the top-level expression.
---@field diffStatus? DiffTag

---@param subexpr_info SubexprInfo
local function render_subexpr_info(subexpr_info, tag, sess)
  local element = Element:new {}

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

  ---@param ctx ElementEventContext
  local do_reset = function(ctx)
    info_open = false
    element:remove_tooltip()
    ctx.rehover()
  end

  ---@param info_popup InfoPopup
  local mk_tooltip = function(info_popup)
    local tooltip_element = Element.noop()

    if info_popup.exprExplicit ~= nil then
      tooltip_element:add_child(interactive_code.CodeWithInfos(info_popup.exprExplicit, sess))
      if info_popup.type ~= nil then
        tooltip_element:add_child(Element:new { text = ' : ' })
      end
    end

    if info_popup.type ~= nil then
      tooltip_element:add_child(interactive_code.CodeWithInfos(info_popup.type, sess))
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

  ---@param ctx ElementEventContext
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

  ---@param ctx ElementEventContext
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

    vim.lsp.util.show_document(links[1], 'utf-16', { focus = true })
    if #links > 1 then
      vim.fn.setqflist({}, ' ', {
        title = 'LSP locations',
        items = vim.lsp.util.locations_to_items(links, 'utf-16'),
      })
      vim.cmd 'botright copen'
    end
  end
  local go_to_def = function(ctx) ---@param ctx ElementEventContext
    go_to(ctx, 'definition')
  end
  local go_to_decl = function(ctx) ---@param ctx ElementEventContext
    go_to(ctx, 'declaration')
  end
  local go_to_type = function(ctx) ---@param ctx ElementEventContext
    go_to(ctx, 'type')
  end

  element.events = {
    click = click,
    clear = function(ctx) ---@param ctx ElementEventContext
      if info_open then
        do_reset(ctx)
      end
    end,
    go_to_def = go_to_def,
    go_to_decl = go_to_decl,
    go_to_type = go_to_type,
  }
  element.highlightable = true

  element:add_child(interactive_code.CodeWithInfos(tag, sess))

  return element
end

---@class TaggedText.SubExprInfo: TaggedText
---@field append? TaggedText.SubExprInfo[]
---@field tag? {[1]: SubexprInfo, [2]: TaggedText.SubExprInfo }

---@alias CodeWithInfos TaggedText.SubExprInfo

-- FIXME: make inductive take parameters and really merge with TaggedTextMsgEmbed
interactive_code.CodeWithInfos = TaggedText('SubexprInfo', render_subexpr_info)

return interactive_code
