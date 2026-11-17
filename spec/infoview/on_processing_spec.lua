local Window = require 'std.nvim.window'
local helpers = require 'spec.helpers'
local infoview = require 'lean.infoview'
local progress = require 'lean.progress'
local stderr = require 'lean.stderr'

local CONTENTS = [[
  --
  example : 2 = 2 := by
    skip
    rfl
]]

local GOAL = [[
  Goals accomplished 🎉

  ⊢ 2 = 2
]]

---Make Lean reprocess from the top of the file, including the cursor position.
---@param first_line? string
local function reprocess(first_line)
  vim.api.nvim_buf_set_lines(0, 0, 1, false, { first_line or '#eval IO.sleep 3000' })
  local params = vim.lsp.util.make_position_params(0, 'utf-16')
  assert.is_true(vim.wait(10000, function()
    return progress.at(params) == progress.Kind.processing
  end))
end

describe('on_processing', function()
  local original_config = vim.g.lean_config
  local original_deprecate = vim.deprecate

  after_each(function()
    vim.g.lean_config = original_config
    vim.deprecate = original_deprecate
    infoview.clear_pins()

    local stderr_bufnr = vim.fn.bufnr 'lean://stderr'
    if stderr_bufnr ~= -1 then
      vim.api.nvim_buf_delete(stderr_bufnr, { force = true })
    end
  end)

  ---@param infoview_config lean.infoview.Config
  local function configure(infoview_config)
    vim.g.lean_config =
      vim.tbl_deep_extend('force', original_config, { infoview = infoview_config })
  end

  it(
    'keeps showing the last goal while processing and refreshes once done',
    helpers.clean_buffer(CONTENTS, function()
      helpers.move_cursor { to = { 3, 2 } }
      assert.infoview_contents.are(GOAL)

      local window = infoview.get_current_infoview().window
      assert.are.same({ 3, #'⊢ ' }, window:cursor())

      -- Change both the sleep and the theorem so the refreshed goal differs.
      vim.api.nvim_buf_set_lines(0, 0, 2, false, {
        '#eval IO.sleep 2000',
        'example : 3 = 3 := by',
      })
      local params = vim.lsp.util.make_position_params(0, 'utf-16')
      assert.is_true(vim.wait(10000, function()
        return progress.at(params) == progress.Kind.processing
      end))

      assert.is_true(vim.wait(5000, function()
        return window.o.winhighlight == 'NormalNC:leanInfoProcessing'
      end))
      assert.infoview_contents_nowait.are(GOAL)

      -- Scrolling/moving in the infoview is not yanked back to `⊢` by edits while stale.
      window:set_cursor { 1, 0 }
      local refreshed = false
      vim.api.nvim_create_autocmd('User', {
        pattern = 'LeanPinRefreshed',
        once = true,
        callback = function()
          refreshed = true
        end,
      })
      vim.api.nvim_buf_set_lines(0, 2, 3, false, { '  skip --' })
      assert.is_true(vim.wait(5000, function()
        return refreshed
      end))
      assert.are.same({ 1, 0 }, window:cursor())
      assert.infoview_contents_nowait.are(GOAL)

      assert.infoview_contents.are [[
        Goals accomplished 🎉

        ⊢ 3 = 3
      ]]
      assert.are.equal('', window.o.winhighlight)
      assert.are.same({ 3, #'⊢ ' }, window:cursor())
    end)
  )

  it(
    'falls back to the processing message when the previous settled state was empty',
    helpers.clean_buffer('--\ndef x := 1', function()
      helpers.move_cursor { to = { 2, 0 } }
      assert.infoview_contents.are ''

      reprocess()
      helpers.wait:for_infoview_contents '^Processing file%.%.%.$'
      assert.are.equal('', infoview.get_current_infoview().window.o.winhighlight)
    end)
  )

  it(
    'does not carry a stale goal across files',
    helpers.clean_buffer(CONTENTS, function()
      helpers.move_cursor { to = { 3, 2 } }
      assert.infoview_contents.are(GOAL)

      helpers.clean_buffer('#eval IO.sleep 3000', function()
        helpers.wait:for_infoview_contents '^Processing file%.%.%.$'
        assert.are.equal('', infoview.get_current_infoview().window.o.winhighlight)
      end)()
    end)
  )

  it(
    'shows what a custom hook returns',
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
    'treats an empty string return as nothing above top-of-file diagnostics',
    helpers.clean_buffer(
      [[
        --
        #check Nat
        --
        example : 2 = 2 := by rfl
      ]],
      function()
        configure {
          on_processing = function()
            return ''
          end,
        }
        helpers.move_cursor { to = { 4, 22 } }
        assert.infoview_contents.are(GOAL)

        vim.api.nvim_buf_set_lines(0, 2, 3, false, { '#eval IO.sleep 3000' })
        helpers.wait:for_infoview_contents '^▼ 2:1%-2:7: information:\nNat : Type$'
        assert.are.equal('', infoview.get_current_infoview().window.o.winhighlight)
      end
    )
  )

  it('upconverts deprecated show_processing and emits a deprecation warning', function()
    local deprecated
    vim.deprecate = function(name, alternative, version)
      deprecated = { name = name, alternative = alternative, version = version }
    end
    configure { show_processing = false }

    helpers.clean_buffer('--\ndef x := 1\nexample : 2 = 2 := by\n  skip\n  rfl', function()
      assert.is_truthy(deprecated)
      assert.is_truthy(deprecated.name:find 'show_processing')

      -- Even after settling on an empty state (`Element.EMPTY`), processing does not tint.
      helpers.move_cursor { to = { 2, 0 } }
      assert.infoview_contents.are ''

      reprocess '#eval IO.sleep 2000'
      local window = infoview.get_current_infoview().window
      assert.infoview_contents_nowait.are ''
      assert.are.equal('', window.o.winhighlight)

      -- Wait for processing to settle, then verify from a settled goal as well.
      helpers.move_cursor { to = { 4, 2 } }
      assert.infoview_contents.are(GOAL)

      reprocess '#eval IO.sleep 3001'
      helpers.wait:for_infoview_contents '^$'
      assert.are.equal('', window.o.winhighlight)

      -- And `show_processing = true` upconverts to showing "Processing file..." instead of stale goals.
      configure { show_processing = true }
      vim.api.nvim_buf_set_lines(0, 0, 1, false, { '#eval IO.sleep 3002' })
      helpers.wait:for_infoview_contents '^Processing file%.%.%.$'
      assert.are.equal('', window.o.winhighlight)
    end)()
  end)

  it(
    'manages winhighlight per pin without leaking to split windows',
    helpers.clean_buffer(CONTENTS, function()
      helpers.move_cursor { to = { 3, 2 } }
      assert.infoview_contents.are(GOAL)

      reprocess '#eval IO.sleep 2500'
      local iv = infoview.get_current_infoview()
      assert.is_true(vim.wait(5000, function()
        return iv.window.o.winhighlight == 'NormalNC:leanInfoProcessing'
      end))

      -- Splitting off debug and stderr windows must not inherit `leanInfoProcessing`.
      infoview.open_debug()
      local debug_win = iv.pin:__debug_window()
      assert.is_truthy(debug_win)
      assert.are.equal('', debug_win.o.winhighlight)
      debug_win:force_close()

      stderr.show 'stderr line\n'
      local stderr_win
      assert.is_true(vim.wait(5000, function()
        local bufnr = vim.fn.bufnr 'lean://stderr'
        local winid = bufnr ~= -1 and vim.fn.bufwinid(bufnr) or -1
        if winid ~= -1 then
          stderr_win = Window:from_id(winid)
          return true
        end
        return false
      end))
      assert.are.equal('', stderr_win.o.winhighlight)
      stderr_win:force_close()

      -- Adding a pin while stale tracks and later clears `winhighlight` on both pin windows.
      infoview.add_pin()
      local pinned = iv.pins[1]
      assert.are.equal('NormalNC:leanInfoProcessing', pinned.window.o.winhighlight)

      assert.infoview_contents.are(GOAL)
      assert.infoview_contents.are { GOAL, pin = 1 }
      assert.are.equal('', iv.window.o.winhighlight)
      assert.are.equal('', pinned.window.o.winhighlight)
    end)
  )
end)
