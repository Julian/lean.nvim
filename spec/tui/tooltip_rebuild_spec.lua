require 'spec.helpers'

local Buffer = require 'std.nvim.buffer'
local Element = require('lean.tui').Element

--- A controllable suspension point, standing in for an async RPC round-trip
--- inside an event handler (as `infoToInteractive` does for a real click).
local function make_gate()
  local suspended
  return function() -- called inside the handler's coroutine to suspend it
    suspended = coroutine.running()
    coroutine.yield()
  end, function() -- called by the test to resume the handler
    assert(suspended, 'the handler never suspended')
    local ok, err = coroutine.resume(suspended)
    assert(ok, err)
  end
end

--- A `Type`-like clickable leaf carrying a server identity `id`, under a named
--- root, plus the path to the leaf.
local function tree(id)
  local leaf = Element:new { text = 'Type', highlightable = true }
  leaf.tooltip_id = id
  local root = Element:new { name = 'root', children = { leaf } }
  return root, leaf, { { name = 'root' }, { idx = 1 } }
end

describe('interactive tooltips', function()
  -- A click opens its tooltip asynchronously, so its resolution can race with a
  -- pin refresh that swaps in a fresh element tree. The open tooltip is keyed by
  -- the subexpression's server identity, so a rebuild that re-sends the same
  -- goal (same identity) can't strand it.
  it('survive a re-render that re-sends the same goal mid-click', function()
    local wait_for_rpc, finish_rpc = make_gate()
    local tooltip_text = 'the tooltip contents'

    local old_tree = tree 'same-subexpr'
    old_tree.__children[1].events = {
      click = function(ctx)
        wait_for_rpc()
        ctx.set_tooltip(Element.noop(tooltip_text))
        ctx.rehover()
      end,
    }

    -- The same goal re-sent: a distinct element, but the same server identity.
    local new_tree, _, path = tree 'same-subexpr'
    new_tree.__children[1].events = { click = function() end }

    local buffer = Buffer.create { listed = false, scratch = true }
    local renderer = old_tree:renderer { buffer = buffer }
    renderer:render()
    renderer.path = path

    renderer:event 'click'
    assert.is_nil(renderer.tooltip)

    renderer.element = new_tree
    renderer:render()

    finish_rpc()

    assert.is_not_nil(renderer.tooltip)
    assert.contents.are { tooltip_text, buffer = renderer.tooltip.buffer }

    buffer:force_delete()
  end)

  -- When the goal actually changes, a *different* subexpression can land at the
  -- same buffer position. Keying by server identity (not position) means the old
  -- tooltip is dropped rather than shown against the new, unrelated content.
  it('are dropped, not shown stale, when the identity at a position changes', function()
    local root, _, path = tree 'old-subexpr'
    root.__children[1].events = {
      click = function(ctx)
        ctx.set_tooltip(Element.noop 'old contents')
        ctx.rehover()
      end,
    }

    local buffer = Buffer.create { listed = false, scratch = true }
    local renderer = root:renderer { buffer = buffer }
    renderer:render()
    renderer.path = path

    renderer:event 'click'
    assert.is_not_nil(renderer.tooltip)

    -- The goal changes: a new subexpression sits at the same position.
    local changed = tree 'new-subexpr'
    changed.__children[1].events = { click = function() end }
    renderer.element = changed
    renderer:render()

    assert.is_nil(renderer.tooltip)
    -- The stranded entry is also pruned from the store, not just left unshown.
    assert.is_true(vim.tbl_isempty(renderer.tooltips))

    buffer:force_delete()
  end)

  it('close on clear_all', function()
    local root, _, path = tree 'subexpr'
    root.__children[1].events = {
      click = function(ctx)
        ctx.set_tooltip(Element.noop 'contents')
        ctx.rehover()
      end,
      clear_all = function(ctx)
        ctx.clear_all_tooltips()
      end,
    }

    local buffer = Buffer.create { listed = false, scratch = true }
    local renderer = root:renderer { buffer = buffer }
    renderer:render()
    renderer.path = path

    renderer:event 'click'
    assert.is_not_nil(renderer.tooltip)

    renderer:event 'clear_all'
    assert.is_nil(renderer.tooltip)

    buffer:force_delete()
  end)
end)
