local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'
local progress = require 'lean.progress'

local CONTENTS = [[
  #eval IO.sleep 3000
  example : 2 = 2 := by
    skip
    rfl
]]

local GOAL = [[
  Goals accomplished 🎉

  ⊢ 2 = 2
]]

---Make Lean reprocess everything, including the cursor position.
local function reprocess()
  vim.api.nvim_buf_set_lines(0, 0, 1, false, { '#eval IO.sleep 3001' })
  local params = vim.lsp.util.make_position_params(0, 'utf-16')
  assert.is_true(vim.wait(10000, function()
    return progress.at(params) == progress.Kind.processing
  end))
end

describe('on_processing', function()
  local original = vim.g.lean_config
  after_each(function()
    vim.g.lean_config = original
  end)

  ---@param infoview_config lean.infoview.Config
  local function configure(infoview_config)
    vim.g.lean_config = vim.tbl_deep_extend('force', original, { infoview = infoview_config })
  end

  it(
    'keeps showing the last goal for the file by default',
    helpers.clean_buffer(CONTENTS, function()
      helpers.move_cursor { to = { 3, 2 } }
      assert.infoview_contents.are(GOAL)

      reprocess()
      local window = infoview.get_current_infoview().window
      assert.is_true(vim.wait(5000, function()
        return window.o.winhighlight == 'NormalNC:leanInfoProcessing'
      end))
      assert.infoview_contents_nowait.are(GOAL)

      assert.infoview_contents.are(GOAL)
      assert.are.equal('', window.o.winhighlight)
    end)
  )

  it(
    'shows what it returns',
    helpers.clean_buffer(CONTENTS, function()
      configure {
        on_processing = function()
          return 'Busy!'
        end,
      }
      helpers.move_cursor { to = { 3, 2 } }
      assert.infoview_contents.are(GOAL)

      reprocess()
      helpers.wait:for_infoview_contents '^Busy!$'
      assert.are.equal('', infoview.get_current_infoview().window.o.winhighlight)
    end)
  )

  it(
    'shows nothing for the deprecated show_processing = false',
    helpers.clean_buffer(CONTENTS, function()
      configure { show_processing = false }
      helpers.move_cursor { to = { 3, 2 } }
      assert.infoview_contents.are(GOAL)

      reprocess()
      helpers.wait:for_infoview_contents '^$'
    end)
  )
end)
