local infoview = require('lean.infoview')
local clean_buffer = require('tests.helpers').clean_buffer

describe('infoview', function()
  require('tests.helpers').setup { infoview = { enable = true } }

  local infoview_info = infoview.open()
  clean_buffer('starts with the window position at the top', '',
    function(_)
      local cursor = vim.api.nvim_win_get_cursor(infoview_info.window)
      assert.is.same(1, cursor[1])
    end)
  infoview.close()
end)
