local infoview = require('lean.infoview')
local clean_buffer_ft = require('tests.helpers').clean_buffer_ft

describe('infoview', function()
  require('tests.helpers').setup { infoview = { enable = true } }

  local src_win = vim.api.nvim_get_current_win()

  it('automatically opens', clean_buffer_ft('lean', '',
    function(_)
      assert.is_true(infoview.is_open())
    end))

  local infoview_info = infoview.open()

  it('starts with the window position at the top',
    function(_)
      local cursor = vim.api.nvim_win_get_cursor(infoview_info.window)
      assert.is.same(1, cursor[1])
    end)

  it('cursor starts in source window',
    function(_)
      assert.is.same(src_win, vim.api.nvim_get_current_win())
    end)

  infoview.close()
end)
