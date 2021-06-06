local infoview = require('lean.infoview')

local clean_buffer = require('tests.helpers').clean_buffer

describe('infoview', function()
  it('starts with the window position at the top', clean_buffer('',
    function(context)
      infoview.update()
      local succeeded_info, _ = vim.wait(5000, infoview.open)
      assert.message("Infoview was never ready.").True(succeeded_info)
      local infoview_info = infoview.open()

      local cursor = vim.api.nvim_win_get_cursor(infoview_info.window)
      assert.is.same(1, cursor[1])
      infoview.close()
    end))
end)
