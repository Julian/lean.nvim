---@mod tui.tabs Clickable tab strip with switchable bodies
---
---@brief [[
--- A horizontal strip of Unicode-box-drawn tab labels. Clicking a label
--- swaps the body shown beneath the strip.
---@brief ]]

local Element = require('lean.tui').Element

vim.api.nvim_set_hl(0, 'tui.tabs.active', { default = true, bold = true })

---@class tui.tabs.Tab
---@field label string the tab's label text
---@field body Element|fun():Element body shown when this tab is active

---@class TabsOpts
---@field tabs tui.tabs.Tab[] the tabs (must be non-empty)
---@field active? integer initial active tab index (default: 1)
---@field on_change? fun(i: integer) called when the active tab changes

---Create a tabs Element.
---@param opts TabsOpts
---@return Element
return function(opts)
  local tabs = opts.tabs
  local active = opts.active or 1
  local on_change = opts.on_change or function() end

  ---@type Element
  local container = Element:new {}

  local function resolve_body(body)
    if type(body) == 'function' then
      return body()
    end
    return body
  end

  -- Drop trailing whitespace from a row of Elements so rendered lines
  -- have no significant trailing spaces (keeps `dedent` tests honest).
  local function rstrip(row)
    for i = #row, 1, -1 do
      row[i].text = row[i].text:gsub('%s+$', '')
      if row[i].text ~= '' then
        return
      end
      table.remove(row, i)
    end
  end

  local function layout()
    local n = #tabs
    local top, middle, bottom = {}, {}, {}

    for i, tab in ipairs(tabs) do
      local w = vim.fn.strdisplaywidth(tab.label)

      -- Each tab occupies w+4 columns whether active or inactive, so the
      -- label's column never changes when switching tabs. This keeps the
      -- cursor anchored to the same label across re-renders.
      if i == active then
        local left = (i == 1) and '╰' or '┴'
        local right = (i == n) and '╯' or '┴'
        table.insert(top, Element.text('╭' .. string.rep('─', w + 2) .. '╮'))
        table.insert(middle, Element.text '│ ')
        table.insert(
          middle,
          Element:new {
            text = tab.label,
            hlgroups = { 'tui.tabs.active' },
          }
        )
        table.insert(middle, Element.text ' │')
        table.insert(bottom, Element.text(left .. string.rep('─', w + 2) .. right))
      else
        local idx = i
        table.insert(top, Element.text(string.rep(' ', w + 4)))
        table.insert(middle, Element.text '  ')
        table.insert(
          middle,
          Element:new {
            text = tab.label,
            hlgroups = { 'widgetLink' },
            highlightable = true,
            events = {
              click = function(ctx)
                active = idx
                on_change(idx)
                container:set_children { layout() }
                ctx.rerender()
              end,
            },
          }
        )
        table.insert(middle, Element.text '  ')
        table.insert(bottom, Element.text(string.rep('─', w + 4)))
      end
    end

    -- Top is purely whitespace past the active tab's box, so trimming has
    -- no visual cost. The middle row is NOT trimmed because doing so would
    -- pull the inactive label's trailing pad in while the bottom baseline
    -- below it stays full width — visible misalignment.
    rstrip(top)

    -- Mark the strip as a block so the renderer resets `pending_block_break`
    -- when entering it. Without this, if the preceding sibling was a block
    -- element, the inactive top's leading whitespace gets dropped as
    -- "decorative" — pulling the active tab's box to column 0.
    return Element:concat({
      Element:new { children = top },
      Element:new { children = middle },
      Element:new { children = bottom },
      resolve_body(tabs[active].body),
    }, '\n', { is_block = true })
  end

  container:set_children { layout() }
  return container
end
