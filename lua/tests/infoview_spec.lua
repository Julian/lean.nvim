local clean_buffer = require('tests.helpers').clean_buffer

describe('infoview', function()
  it('starts with the window position at the top', clean_buffer('',
    function(context)
      local position = vim.api.nvim_win_get_position(context.infoview.winnr)
      assert.is.same(0, position[1])
    end))
end)
