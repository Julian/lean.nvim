local clean_buffer = require('tests.helpers').clean_buffer

describe('infoview', function()
  require('tests.helpers').setup { infoview = { enable = true } }
  it('starts with the window position at the top', clean_buffer('',
    function(context)
      local cursor = vim.api.nvim_win_get_cursor(context.infoview.window)
      assert.is.same(1, cursor[1])
    end))
end)
