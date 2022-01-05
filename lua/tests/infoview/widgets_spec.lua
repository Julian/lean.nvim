---@brief [[
---Tests for Lean widgets (rendered inside infoviews).
---@brief ]]

local infoview = require('lean.infoview')
local helpers = require('tests.helpers')

require('lean').setup{}

describe('infoview enable/disable_widgets', function()
  describe('lean 3', helpers.clean_buffer('lean3', 'example : 2 = 2 := by refl', function()
    -- These tests are flaky, possibly for the same reason that 'shows a term
    -- goal' is from contents_spec. Namely, sometimes the Lean process seems to
    -- do absolutely nothing and sit there never returning a response (even an
    -- initial one). Marking these pending until we figure out what's happening
    -- there, presumably some request getting sent before the server is ready.
    pending('can be disabled', function(_)
      helpers.wait_for_ready_lsp()
      infoview.disable_widgets()
      helpers.move_cursor{ to = {1, 22} }
      helpers.wait_for_infoview_contents('2 = 2')
      -- we're looking for `filter` to not be shown as our widget
      assert.infoview_contents.are[[
        ▶ 1 goal
        ⊢ 2 = 2
      ]]
    end)

    pending('can re-enable widgets', function(_)
      infoview.enable_widgets()
      helpers.move_cursor{ to = {1, 22} }
      helpers.wait_for_infoview_contents('filter')
      -- we're looking for `filter` as our widget
      -- FIXME: Extra newline only with widgets enabled
      assert.infoview_contents.are[[
        filter: no filter
        ▶ 1 goal

        ⊢ 2 = 2
      ]]
    end)
  end))
end)
